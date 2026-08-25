import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/constants/credits.dart';
import 'package:pinorpinor_app/data/models/credits.dart';

/// What credits cost and what they buy, pinned against the website.
///
/// Every figure here is shown to a member before they spend anything, and the
/// server is what actually charges — so a drift between the two is a price
/// quoted wrongly, which is worse than no price at all.
void main() {
  final File credits = File('../pinorpinor/src/lib/credits.ts');
  final File purchase = File('../pinorpinor/src/lib/credit-purchase.ts');

  int? constantIn(File file, String name) {
    if (!file.existsSync()) return null;
    final RegExpMatch? m = RegExp(
      'export const $name = ([0-9_]+)',
    ).firstMatch(file.readAsStringSync());
    return m == null ? null : int.parse(m.group(1)!.replaceAll('_', ''));
  }

  group('the figures match the server', () {
    test('a credit is worth the same in Naira', () {
      final int? theirs = constantIn(credits, 'NAIRA_PER_CREDIT');
      if (theirs == null) {
        markTestSkipped('website checkout not present');
        return;
      }
      expect(kNairaPerCredit, theirs);
    });

    test('a WhatsApp chat costs the same', () {
      final int? theirs = constantIn(credits, 'WHATSAPP_UNLOCK_CREDITS');
      if (theirs == null) {
        markTestSkipped('website checkout not present');
        return;
      }
      expect(
        kWhatsAppUnlockCredits,
        theirs,
        reason:
            'the profile screen labels a button with this before the tap; a '
            'wrong figure is a price quoted wrongly',
      );
    });

    test('credits are sold in the same denomination', () {
      final int? theirs = constantIn(credits, 'CREDIT_DENOMINATION');
      if (theirs == null) {
        markTestSkipped('website checkout not present');
        return;
      }
      expect(kCreditDenomination, theirs);
    });

    test('the presets and bounds match', () {
      if (!purchase.existsSync()) {
        markTestSkipped('website checkout not present');
        return;
      }
      final String source = purchase.readAsStringSync();

      final RegExpMatch? presets = RegExp(
        r'export const CREDIT_PURCHASE_PRESETS = \[([0-9,\s]+)\]',
      ).firstMatch(source);
      expect(presets, isNotNull, reason: 'presets are no longer declared');
      expect(
        kCreditPurchasePresets,
        presets!
            .group(1)!
            .split(',')
            .map((String s) => int.parse(s.trim()))
            .toList(),
      );

      final int? max = constantIn(purchase, 'MAX_CREDIT_PURCHASE');
      expect(kMaxCreditPurchase, max);
    });
  });

  group('quoting a top-up', () {
    test('the denomination is checked before the floor', () {
      // The route's order, and the more useful of the two answers: somebody
      // typing 50 is told about multiples, not about a minimum they also miss.
      expect(creditPurchaseError('50'), contains('sold in 100s'));
    });

    test('a valid amount quotes cleanly', () {
      expect(creditPurchaseError('100'), isNull);
      expect(creditPurchaseError('2,000'), isNull, reason: 'separators strip');
      expect(creditPurchaseError(500), isNull);
    });

    test('nothing, zero and text are refused', () {
      expect(creditPurchaseError(''), isNotNull);
      expect(creditPurchaseError('0'), isNotNull);
      expect(creditPurchaseError('lots'), isNotNull);
    });

    test('an off-denomination amount suggests the nearest one', () {
      expect(creditPurchaseError('150'), contains('200'));
      expect(creditPurchaseError('249'), contains('200'));
    });

    test('the ceiling is refused with a way forward', () {
      expect(
        creditPurchaseError('${kMaxCreditPurchase + kCreditDenomination}'),
        contains('ask again'),
      );
    });

    test('the Naira figure is a plain multiple, never minor units', () {
      // formatMoney divides by the currency's minor unit; pointing it at
      // credits would render 100 credits as a tenth of a Naira.
      expect(nairaForCredits(100), 1000);
      expect(nairaForCredits(kWhatsAppUnlockCredits), 1000);
    });
  });

  group('a recorded request', () {
    test('carries the reference an admin works it by', () {
      final CreditPurchaseResult result = CreditPurchaseResult.fromJson(
        <String, dynamic>{
          'purchase': <String, dynamic>{
            'id': 'p1',
            'reference': 'PNR-7QK4',
            'credits': 500,
            'amountNaira': 5000,
            'status': 'PENDING',
          },
          'whatsappUrl': 'https://wa.me/234800?text=PNR-7QK4',
        },
      );

      expect(result.purchase.reference, 'PNR-7QK4');
      expect(result.purchase.isPending, isTrue);
      expect(result.purchase.statusLabel, 'Waiting for confirmation');
      expect(
        result.whatsappUrl,
        contains('PNR-7QK4'),
        reason:
            'the message, the stored row and the admin queue must not be able '
            'to disagree about what was asked for',
      );
    });

    test('an approved request reads as done', () {
      final CreditPurchase p = CreditPurchase.fromJson(<String, dynamic>{
        'id': 'p2',
        'reference': 'PNR-AAAA',
        'credits': 100,
        'amountNaira': 1000,
        'status': 'APPROVED',
      });
      expect(p.isApproved, isTrue);
      expect(p.isPending, isFalse);
    });
  });
}
