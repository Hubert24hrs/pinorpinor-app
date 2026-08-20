import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/utils/money.dart';
import 'package:pinorpinor_app/data/models/rates.dart';

/// Money is stored as integers in **minor units**, and the number of minor
/// digits varies by currency. Getting that wrong shows a member's rate at one
/// hundredth or one hundred times its real value on a public profile, which is
/// the kind of bug that ends in an argument with a client rather than a crash.
///
/// The zero-decimal currencies are the whole point of these tests. There is no
/// way to notice by looking at a Nigerian profile that the Japanese one is
/// wrong.
void main() {
  group('currency lookup', () {
    test('resolves by country code', () {
      expect(currencyForCountry('NG').code, 'NGN');
      expect(currencyForCountry('ng').code, 'NGN', reason: 'case-insensitive');
      expect(currencyForCountry('GB').symbol, '£');
    });

    test('falls back to USD for an unknown or missing country', () {
      expect(currencyForCountry(null).code, 'USD');
      expect(currencyForCountry('').code, 'USD');
      expect(currencyForCountry('ZZ').code, 'USD');
    });

    test('resolves by ISO 4217 code', () {
      expect(currencyByCode('NGN').symbol, '₦');
      expect(currencyByCode('ngn').symbol, '₦');
      expect(currencyByCode('NOPE').code, 'USD');
    });

    test('an explicit currency beats the one implied by the country', () {
      // A member in Nigeria may price in dollars, and does.
      expect(
        resolveCurrency(storedCurrency: 'USD', countryCode: 'NG').code,
        'USD',
      );
      expect(
        resolveCurrency(storedCurrency: null, countryCode: 'NG').code,
        'NGN',
      );
    });
  });

  group('two-decimal currencies', () {
    test('formats whole amounts without decimals', () {
      // 100,000.00 naira, stored as kobo.
      expect(formatMoney(10000000, currencyCode: 'NGN'), '₦100,000');
    });

    test('keeps decimals only when there is a fraction', () {
      expect(formatMoney(10050, currencyCode: 'NGN'), '₦100.50');
      expect(formatMoney(10005, currencyCode: 'NGN'), '₦100.05');
    });

    test('groups thousands', () {
      expect(formatMoney(123456789, currencyCode: 'NGN'), '₦1,234,567.89');
      expect(formatMoney(100000, currencyCode: 'NGN'), '₦1,000');
    });

    test('round-trips through minor units', () {
      expect(toMinorUnits(100000, currencyCode: 'NGN'), 10000000);
      expect(toMajorUnits(10000000, currencyCode: 'NGN'), 100000);
      expect(toMinorUnits(100.5, currencyCode: 'NGN'), 10050);
      expect(toMajorUnits(10050, currencyCode: 'NGN'), 100.5);
    });
  });

  group('zero-decimal currencies', () {
    // JPY, KRW, VND, RWF, XOF and XAF have no minor unit at all. Dividing by
    // 100 here is the bug this whole file exists to catch.
    test('the stored integer is the major amount', () {
      expect(formatMoney(5000, currencyCode: 'JPY'), '¥5,000');
      expect(formatMoney(5000, currencyCode: 'KRW'), '₩5,000');
      expect(formatMoney(150000, currencyCode: 'VND'), '₫150,000');
      expect(formatMoney(25000, currencyCode: 'RWF'), 'FRw25,000');
      expect(formatMoney(30000, currencyCode: 'XOF'), 'CFA30,000');
    });

    test('conversion is the identity, not a division', () {
      expect(toMinorUnits(5000, currencyCode: 'JPY'), 5000);
      expect(toMajorUnits(5000, currencyCode: 'JPY'), 5000);
    });

    test('a yen amount is not rendered as one hundredth', () {
      // The regression in plain terms.
      expect(formatMoney(5000, currencyCode: 'JPY'), isNot('¥50'));
    });
  });

  group('unset versus zero', () {
    test('null formats as null, so callers can omit the row', () {
      expect(formatMoney(null, currencyCode: 'NGN'), isNull);
      expect(toMajorUnits(null, currencyCode: 'NGN'), isNull);
    });

    test('zero is a real published rate and formats as one', () {
      // "Free" and "not published" are different claims. Conflating them would
      // make a published rate impossible to withdraw.
      expect(formatMoney(0, currencyCode: 'NGN'), '₦0');
    });
  });

  group('MemberRates', () {
    MemberRates parse(Map<String, dynamic> profile) =>
        MemberRates.fromProfileJson(profile);

    test('reads the raw column names off a datingProfile', () {
      final rates = parse(<String, dynamic>{
        'currency': 'NGN',
        'rateShortIncall': 5000000,
        'rateNightOutcall': 20000000,
      });

      expect(rates.currency, 'NGN');
      expect(rates.shortIncall, 5000000);
      expect(rates.nightOutcall, 20000000);
      expect(rates.shortOutcall, isNull);
      expect(rates.hasAny, isTrue);
    });

    test('an empty profile has nothing to show', () {
      expect(parse(<String, dynamic>{}).hasAny, isFalse);
      expect(parse(<String, dynamic>{}).isVisible, isFalse);
    });

    test('a missing ratesVisible defaults to visible', () {
      // An older endpoint that does not serialise the column must not hide
      // rates it did send.
      final rates = parse(<String, dynamic>{'rateShortIncall': 100});
      expect(rates.ratesVisible, isTrue);
      expect(rates.isVisible, isTrue);
    });

    test('the member switch hides everything, however much is published', () {
      final rates = parse(<String, dynamic>{
        'ratesVisible': false,
        'rateShortIncall': 5000000,
      });
      expect(rates.hasAny, isTrue);
      expect(rates.isVisible, isFalse, reason: 'the member turned it off');
    });

    test('a duration with neither price set is omitted from the table', () {
      // Not rendered as a row of dashes: an empty row implies the member
      // declined to price it, when in fact they have not filled it in.
      final rates = parse(<String, dynamic>{
        'currency': 'NGN',
        'rateShortIncall': 5000000,
      });

      final rows = rates.tableRows('NG');
      expect(rows, hasLength(1));
      expect(rows.single.label, 'Short time');
      expect(rows.single.incall, '₦50,000');
      expect(rows.single.outcall, isNull);
    });

    test('per-minute rows omit anything unpublished', () {
      final rates = parse(<String, dynamic>{
        'currency': 'NGN',
        'rateVideoPerMin': 50000,
      });

      final rows = rates.perMinuteRows('NG');
      expect(rows, hasLength(1));
      expect(rows.single.label, 'Custom video');
      expect(rows.single.amount, '₦500');
    });

    test('falls back to the country currency when none is stored', () {
      final rates = parse(<String, dynamic>{'rateShortIncall': 5000});
      expect(rates.resolvedCurrency('JP').code, 'JPY');
      // And formats without dividing, because JPY has no minor unit.
      expect(rates.tableRows('JP').single.incall, '¥5,000');
    });
  });
}
