import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/constants/live_sessions.dart';
import 'package:pinorpinor_app/core/utils/money.dart';
import 'package:pinorpinor_app/data/models/live_sessions.dart';
import 'package:pinorpinor_app/data/models/rates.dart';

/// Guards live-session prices, which are **credits and not money**.
///
/// The two are one careless import apart and the failure is silent in both
/// directions: `formatMoney` on a credit column renders 50 credits as "₦0.50",
/// and `parseRateInput` on the way in would store 50 credits as 5000. The
/// website keeps separate columns, a separate parser and a separate payload key
/// (`liveRates`, not `rates`) precisely so nothing can mix them, and these tests
/// hold the app to the same separation.
void main() {
  final websiteCatalogue = File('../pinorpinor/src/lib/live-sessions.ts');

  group('catalogue self-consistency', () {
    test('every id and column is unique', () {
      expect(
        kLiveSessions.map((s) => s.id).toSet(),
        hasLength(kLiveSessions.length),
      );
      expect(kLiveSessionFields.toSet(), hasLength(kLiveSessions.length));
    });

    test('every entry has a label and a description', () {
      for (final option in kLiveSessions) {
        expect(option.label.trim(), isNotEmpty, reason: option.id);
        expect(option.description.trim(), isNotEmpty, reason: option.id);
      }
    });

    test('no column name collides with a money rate column', () {
      // The whole point of the separation. A shared name would put two units
      // behind one number with nothing in the data to say which.
      final money = kRateFields.map((f) => f.field).toSet();
      for (final field in kLiveSessionFields) {
        expect(money, isNot(contains(field)), reason: field);
      }
    });
  });

  group('validation mirrors parseLiveSessionInput', () {
    test('empty means "not offered" and is valid', () {
      expect(validateLiveSessionCredits(''), isNull);
      expect(validateLiveSessionCredits('   '), isNull);
      expect(validateLiveSessionCredits(null), isNull);
    });

    test('zero is a real price, distinct from empty', () {
      // "Free" is a claim a member may make. Conflating it with unset would
      // leave no value that means "take this off my profile".
      expect(validateLiveSessionCredits('0'), isNull);
      expect(liveSessionPriceLabel(0), 'Free');
    });

    test('separators are stripped rather than rejected', () {
      expect(validateLiveSessionCredits('1,000'), isNull);
      expect(validateLiveSessionCredits('1 000'), isNull);
    });

    test('credits are whole numbers', () {
      expect(validateLiveSessionCredits('12.5'), 'Credits are whole numbers.');
    });

    test('text and negatives are refused', () {
      expect(validateLiveSessionCredits('free'), 'Enter a number.');
      expect(validateLiveSessionCredits('-5'), 'A price cannot be negative.');
    });

    test('the ceiling is enforced, and named in the message', () {
      final tooBig = (kMaxCreditsPerMin + 1).toString();
      expect(validateLiveSessionCredits(tooBig), contains('100,000'));
      expect(validateLiveSessionCredits(kMaxCreditsPerMin.toString()), isNull);
    });
  });

  group('rendering', () {
    test('the singular is used for one credit', () {
      expect(liveSessionPriceLabel(1), '1 credit / min');
      expect(liveSessionPriceLabel(2), '2 credits / min');
      expect(liveSessionPriceLabel(1500), '1,500 credits / min');
    });

    test('unpriced options are omitted entirely, not greyed out', () {
      // Listing all four and disabling three advertises what someone declined
      // as prominently as what they offer.
      final sessions = MemberLiveSessions.fromProfileJson(<String, dynamic>{
        kLiveSessionFields.first: 40,
      });

      expect(sessions.rows, hasLength(1));
      expect(sessions.rows.single.credits, 40);
      expect(sessions.hasAny, isTrue);
    });

    test('a profile with no prices renders no block at all', () {
      final sessions = MemberLiveSessions.fromProfileJson(<String, dynamic>{
        'city': 'Lagos',
      });
      expect(sessions.hasAny, isFalse);
      expect(sessions.rows, isEmpty);
    });

    test('credits are never run through money formatting', () {
      // The regression this guards: 50 credits rendered as "0.50" because a
      // caller reached for formatMoney, which divides by the minor unit.
      expect(liveSessionPriceLabel(50), '50 credits / min');
      expect(formatMoney(50, currencyCode: 'NGN'), isNot(contains('50 ')));
    });
  });

  group('the patch body', () {
    test('empty strings become null, which is how an offer is withdrawn', () {
      final body = MemberLiveSessions.patchBody(<String, String>{
        kLiveSessionFields.first: '',
        kLiveSessionFields[1]: '30',
      });

      expect(body[kLiveSessionFields.first], isNull);
      expect(body[kLiveSessionFields[1]], '30');
    });

    test('unknown keys never reach the wire', () {
      final body = MemberLiveSessions.patchBody(<String, String>{
        'rateShortIncall': '50000',
        kLiveSessionFields.first: '30',
      });

      expect(
        body.containsKey('rateShortIncall'),
        isFalse,
        reason:
            'a money column posted under liveRates would be parsed as credits',
      );
      expect(body, hasLength(1));
    });

    test('a stored profile round-trips into the editor and back', () {
      final sessions = MemberLiveSessions.fromProfileJson(<String, dynamic>{
        kLiveSessionFields.first: 0,
        kLiveSessionFields[2]: 250,
      });

      final input = sessions.toInput();
      expect(input[kLiveSessionFields.first], '0', reason: 'free, not unset');
      expect(input[kLiveSessionFields[1]], '');
      expect(input[kLiveSessionFields[2]], '250');

      final body = MemberLiveSessions.patchBody(input);
      expect(body[kLiveSessionFields.first], '0');
      expect(body[kLiveSessionFields[1]], isNull);
      expect(body[kLiveSessionFields[2]], '250');
    });
  });

  group('parity with the website', () {
    test('the same ids, labels and columns, in the same order', () {
      if (!websiteCatalogue.existsSync()) {
        markTestSkipped(
          'website checkout not present at ${websiteCatalogue.path}; '
          'catalogue parity is unverified in this run',
        );
        return;
      }

      final source = websiteCatalogue.readAsStringSync();
      final body = source
          .split('export const LIVE_SESSIONS: LiveSessionOption[] = [')
          .last
          .split('\n];')
          .first;

      final entry = RegExp(
        r'id:\s*"([a-z0-9_]+)",\s*\n\s*label:\s*"([^"]+)",'
        r'\s*\n\s*description:\s*"([^"]+)",\s*\n\s*field:\s*"([A-Za-z]+)"',
      );
      final matches = entry.allMatches(body).toList();

      expect(
        matches,
        isNotEmpty,
        reason: 'could not parse live-sessions.ts; its shape has changed',
      );

      expect(kLiveSessions.map((s) => s.id).toList(), <String>[
        for (final m in matches) m.group(1)!,
      ]);
      expect(kLiveSessions.map((s) => s.label).toList(), <String>[
        for (final m in matches) m.group(2)!,
      ]);
      expect(kLiveSessions.map((s) => s.description).toList(), <String>[
        for (final m in matches) m.group(3)!,
      ]);
      // The column names are the part that must not drift by even a character:
      // a wrong key is dropped silently by zod and the price never saves.
      expect(kLiveSessions.map((s) => s.field).toList(), <String>[
        for (final m in matches) m.group(4)!,
      ]);
    });

    test('the ceiling matches', () {
      if (!websiteCatalogue.existsSync()) {
        markTestSkipped('website checkout not present');
        return;
      }
      final source = websiteCatalogue.readAsStringSync();
      final match = RegExp(
        r'export const MAX_CREDITS_PER_MIN = ([0-9_]+)',
      ).firstMatch(source);

      expect(match, isNotNull);
      expect(
        kMaxCreditsPerMin,
        int.parse(match!.group(1)!.replaceAll('_', '')),
      );
    });
  });
}
