import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/constants/abuse_reasons.dart';
import 'package:pinorpinor_app/data/repositories/safety_repository.dart';

/// The abuse-report reasons, pinned against the website's own catalogue.
///
/// **This test exists because the app silently filed every report as "other".**
///
/// `ReportReason.wire` returned the member-facing *label* — "This person
/// appears to be under 18" — on the stated grounds that "the backend accepts
/// any string up to 100 characters". That was true when it was written. Then
/// `/api/report` started passing the reason through `sanitizeAbuseReason`,
/// which accepts only the seven ids in `src/lib/support.ts` and returns
/// `DEFAULT_ABUSE_REASON` for everything else.
///
/// Nothing failed. The request was a 200, the member was thanked, and the
/// moderation queue showed **Something else** for every report the app had
/// ever sent — on an adult platform, with underage reports among them.
///
/// The eighth test to read the website's TypeScript, and the same reason as
/// the other seven: a contract that can drift silently has to be read, not
/// remembered.
void main() {
  final File support = File('../pinorpinor/src/lib/support.ts');

  group('abuse reasons mirror the website', () {
    late String source;

    setUp(() {
      if (support.existsSync()) source = support.readAsStringSync();
    });

    bool skipIfAbsent() {
      if (support.existsSync()) return false;
      markTestSkipped(
        'website checkout not present at ${support.path}; the abuse-reason '
        'contract is unverified in this run',
      );
      return true;
    }

    /// The ids inside `ABUSE_REASONS`, read off the real array.
    Set<String> websiteIds(String source) {
      final int start = source.indexOf('export const ABUSE_REASONS');
      expect(
        start,
        isNot(-1),
        reason: 'ABUSE_REASONS has gone from support.ts; its shape has changed',
      );
      final int end = source.indexOf('];', start);
      final String block = source.substring(start, end);
      return RegExp(
        r'id:\s*"([a-z_]+)"',
      ).allMatches(block).map((m) => m.group(1)!).toSet();
    }

    test('every id the app can send is one the route accepts', () {
      if (skipIfAbsent()) return;

      final Set<String> accepted = websiteIds(source);
      expect(accepted, isNotEmpty);

      for (final reason in kAbuseReasons) {
        expect(
          accepted,
          contains(reason.id),
          reason:
              'the app offers "${reason.label}" and sends the id '
              '"${reason.id}", which sanitizeAbuseReason does not accept. It '
              'will be filed as "$kDefaultAbuseReason" and the reason lost.',
        );
      }
    });

    test('no reason the website offers is missing from the app', () {
      if (skipIfAbsent()) return;

      final Set<String> ours = kAbuseReasons.map((r) => r.id).toSet();
      expect(
        websiteIds(source).difference(ours),
        isEmpty,
        reason:
            'the website offers a reason this app does not, so a member can '
            'report something on the site that they cannot report here',
      );
    });

    test('the fallback is the id the route falls back to', () {
      if (skipIfAbsent()) return;

      final RegExpMatch? match = RegExp(
        r'DEFAULT_ABUSE_REASON\s*=\s*"([a-z_]+)"',
      ).firstMatch(source);
      expect(match, isNotNull, reason: 'DEFAULT_ABUSE_REASON has moved');
      expect(kDefaultAbuseReason, match!.group(1));
    });

    test('the details bounds match the ones the website enforces', () {
      if (skipIfAbsent()) return;

      int constant(String name) {
        final RegExpMatch? m = RegExp(
          '$name\\s*=\\s*(\\d+)',
        ).firstMatch(source);
        expect(m, isNotNull, reason: '$name has moved');
        return int.parse(m!.group(1)!);
      }

      expect(
        kReportDetailsMin,
        constant('SUPPORT_MESSAGE_MIN'),
        reason:
            'the app would accept a description the website would refuse, or '
            'refuse one it would accept',
      );
      expect(
        kReportDetailsMax,
        constant('SUPPORT_MESSAGE_MAX'),
        reason:
            'the app clamped details to 1000 against a 4000 limit, cutting the '
            'end off exactly the long, careful accounts a moderator needs',
      );
    });
  });

  group('the catalogue itself', () {
    test('ids are unique', () {
      final ids = kAbuseReasons.map((r) => r.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every id resolves, and an unknown one does not', () {
      for (final reason in kAbuseReasons) {
        expect(abuseReasonById(reason.id), same(reason));
      }
      expect(abuseReasonById('not_a_reason'), isNull);
    });

    test('the fallback is itself a real reason', () {
      expect(abuseReasonById(kDefaultAbuseReason), isNotNull);
    });

    test('no label is sent as a reason id', () {
      // The regression this whole file is about: a label contains spaces and
      // capitals, an id never does.
      for (final reason in kAbuseReasons) {
        expect(
          RegExp(r'^[a-z_]+$').hasMatch(reason.id),
          isTrue,
          reason: '"${reason.id}" looks like a label, not an id',
        );
      }
    });
  });
}
