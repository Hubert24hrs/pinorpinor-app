import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/constants/primary_services.dart';

/// Guards the primary-service catalogue against drift from the website.
///
/// This is the field that broke registration on 2026-08-21: the route made it
/// **required**, the app did not know it existed, and every attempt to create an
/// account answered 400 without a single compile error, failing test or bad
/// build. The same shape of failure as the `identifier` break in August, from
/// the same cause — a contract that lives in the website's source and nowhere
/// this repository can see it.
///
/// Drift here is silent in both directions:
///
///   * an id here but not there is rejected outright by `sanitizePrimaryService`
///     server-side, so the member cannot register or save at all;
///   * an id there but not here renders as **no badge** on a public profile,
///     because [primaryServiceFor] returns null for anything it does not know —
///     which looks exactly like a member who has not chosen.
///
/// **It skips when the website is not checked out**, because the app must stay
/// buildable on its own. That is a deliberate hole: CI running only this
/// repository proves nothing here. The check earns its place on a developer
/// machine, where both trees exist and where the edit that causes drift is made.
void main() {
  final websiteCatalogue = File('../pinorpinor/src/lib/primary-services.ts');

  group('catalogue self-consistency', () {
    test('every id is unique', () {
      final ids = kPrimaryServices.map((s) => s.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every id is a lowercase slug', () {
      final slug = RegExp(r'^[a-z0-9_]+$');
      for (final option in kPrimaryServices) {
        expect(
          slug.hasMatch(option.id),
          isTrue,
          reason: '"${option.id}" is not a safe storage key',
        );
      }
    });

    test('every entry has a label, a hint and a glyph', () {
      for (final option in kPrimaryServices) {
        expect(option.label.trim(), isNotEmpty, reason: option.id);
        expect(option.hint.trim(), isNotEmpty, reason: option.id);
        expect(option.glyph.trim(), isNotEmpty, reason: option.id);
      }
    });

    test('the hookup id is in the catalogue', () {
      // Four places key off this one value. A typo in the constant would show
      // or hide an entire section with no error anywhere.
      expect(isPrimaryServiceId(kHookupId), isTrue);
      expect(offersHookup(kHookupId), isTrue);
    });

    test('offersHookup is true for exactly one entry', () {
      final gated = kPrimaryServices.where((s) => offersHookup(s.id));
      expect(gated, hasLength(1));
      expect(gated.single.id, kHookupId);
    });
  });

  group('null is a real state', () {
    test('sanitize returns null rather than a default', () {
      // A member who joined before 2026-08-21 has not chosen. Substituting a
      // default here would publish a claim on a real person's public profile
      // that they never made.
      expect(sanitizePrimaryService(null), isNull);
      expect(sanitizePrimaryService(''), isNull);
      expect(sanitizePrimaryService('not_a_service'), isNull);
      expect(sanitizePrimaryService(42), isNull);
      expect(sanitizePrimaryService(<String>['hookup']), isNull);
    });

    test('an unset service has no label and no badge', () {
      expect(primaryServiceFor(null), isNull);
      expect(primaryServiceLabel(null), isEmpty);
      expect(offersHookup(null), isFalse);
    });

    test('a known id round-trips', () {
      for (final option in kPrimaryServices) {
        expect(sanitizePrimaryService(option.id), option.id);
        expect(primaryServiceLabel(option.id), option.label);
      }
    });

    test('an unknown id never renders as a raw slug', () {
      // The failure this prevents: "gfe" printed on a public profile because
      // the label lookup fell through to the id.
      expect(primaryServiceLabel('some_new_id'), isEmpty);
    });
  });

  group('parity with the website', () {
    test('the same six ids, in the same order', () {
      if (!websiteCatalogue.existsSync()) {
        markTestSkipped(
          'website checkout not present at ${websiteCatalogue.path}; '
          'catalogue parity is unverified in this run',
        );
        return;
      }

      final source = websiteCatalogue.readAsStringSync();
      final body = source
          .split('export const PRIMARY_SERVICES: PrimaryServiceOption[] = [')
          .last
          .split('\n];')
          .first;

      final entry = RegExp(r'id:\s*"([a-z0-9_]+)"');
      final expected = <String>[
        for (final m in entry.allMatches(body)) m.group(1)!,
      ];

      expect(
        expected,
        isNotEmpty,
        reason: 'could not parse primary-services.ts; its shape has changed',
      );

      // Order matters as well as membership: it is the render order of the
      // picker, and the website's list is the one a member has already seen.
      expect(
        kPrimaryServices.map((s) => s.id).toList(),
        expected,
        reason:
            'the app catalogue has drifted from src/lib/primary-services.ts. '
            'An id the server does not know is rejected on save; an id the app '
            'does not know renders as no badge at all.',
      );
    });

    test('HOOKUP_ID matches', () {
      if (!websiteCatalogue.existsSync()) {
        markTestSkipped('website checkout not present');
        return;
      }
      final source = websiteCatalogue.readAsStringSync();
      final match = RegExp(
        r'export const HOOKUP_ID: PrimaryServiceId = "([a-z0-9_]+)"',
      ).firstMatch(source);

      expect(match, isNotNull, reason: 'HOOKUP_ID is no longer declared');
      expect(kHookupId, match!.group(1));
    });

    test('labels match, because they are what a member reads', () {
      if (!websiteCatalogue.existsSync()) {
        markTestSkipped('website checkout not present');
        return;
      }
      final source = websiteCatalogue.readAsStringSync();
      final pairs = RegExp(r'id:\s*"([a-z0-9_]+)",\s*\n\s*label:\s*"([^"]+)"');
      final expected = <String, String>{
        for (final m in pairs.allMatches(source)) m.group(1)!: m.group(2)!,
      };

      // The hookup entry is declared with `id: HOOKUP_ID` in the app, so it is
      // matched by id here rather than by position.
      for (final MapEntry<String, String> e in expected.entries) {
        expect(
          primaryServiceLabel(e.key),
          e.value,
          reason: 'the label for "${e.key}" differs from the website',
        );
      }
    });
  });
}
