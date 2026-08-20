import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/constants/services.dart';

/// Guards the services catalogue against drift from the website's definition.
///
/// `lib/core/constants/services.dart` is a transcription of the website's
/// `src/lib/services.ts`, and the backend validates every id against *that*
/// file on write. Drift is silent and asymmetric:
///
///   * an id here but not there is dropped by `sanitizeServiceIds` on save, so
///     a member's selection vanishes without an error;
///   * an id there but not here renders as a raw slug like "gfe" on a public
///     profile.
///
/// Neither shows up in a build, a run, or any other test. This one reads the
/// real TypeScript when the sibling checkout is present.
///
/// **It skips when the website is not checked out**, because the app must stay
/// buildable on its own. That is a deliberate hole: CI running only this
/// repository proves nothing here. The check earns its place on a developer
/// machine, where both trees exist and where the edit that causes drift is
/// actually made.
void main() {
  // The website sits beside this repository in the same scratch directory.
  final websiteServices = File('../pinorpinor/src/lib/services.ts');

  group('catalogue self-consistency', () {
    test('every id is unique', () {
      final ids = kServices.map((s) => s.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every id is a lowercase slug', () {
      // Ids are storage keys that end up in a query string, comma-separated.
      // A space or comma in one would silently split a filter in two.
      final slug = RegExp(r'^[a-z0-9_]+$');
      for (final option in kServices) {
        expect(
          slug.hasMatch(option.id),
          isTrue,
          reason: '"${option.id}" is not a safe storage key',
        );
      }
    });

    test('no label is empty', () {
      for (final option in kServices) {
        expect(option.label.trim(), isNotEmpty, reason: option.id);
      }
    });

    test('sanitize drops unknown ids and imposes catalogue order', () {
      // Derived rather than hardcoded: the catalogue is regenerated from the
      // website, and a fixture naming specific ids goes stale the moment one
      // of them is retired. (It did — this test used to name "gfe".)
      final selectable = kServices.where((s) => !s.retired).toList();
      final first = selectable.first.id;
      final second = selectable[1].id;

      final result = sanitizeServiceIds(<String>[
        second,
        'not_a_real_service',
        first,
        second, // duplicate
      ]);

      expect(result, <String>[first, second]);
      expect(result, isNot(contains('not_a_real_service')));
      expect(
        result.indexOf(first),
        lessThan(result.indexOf(second)),
        reason: 'catalogue order, not tap order',
      );
    });

    test('sanitize refuses a retired id, so it cannot be re-selected', () {
      final retired = kServices.where((s) => s.retired).toList();
      if (retired.isEmpty) {
        markTestSkipped('no retired entries in the current catalogue');
        return;
      }

      // Readable but not writable: a member keeps seeing what they already
      // hold, and nobody can newly choose it.
      expect(sanitizeServiceIds(<String>[retired.first.id]), isEmpty);
      expect(serviceLabel(retired.first.id), retired.first.label);
    });

    test('an unknown id still renders as something', () {
      // A profile holding an id dropped from the catalogue by mistake must not
      // render as a blank chip.
      expect(serviceLabel('mystery_id'), 'mystery_id');
    });

    test('grouping covers every selectable option exactly once', () {
      final grouped = servicesByGroup()
          .expand((g) => g.options)
          .map((o) => o.id)
          .toList();
      final selectable = kServices
          .where((s) => !s.retired)
          .map((s) => s.id)
          .toList();

      expect(grouped.toSet(), selectable.toSet());
      expect(grouped, hasLength(selectable.length));
    });

    test('retired entries are readable but not selectable', () {
      for (final option in kServices.where((s) => s.retired)) {
        expect(isValidServiceId(option.id), isFalse, reason: option.id);
        expect(servicesForIds(<String>[option.id]), hasLength(1));
      }
    });
  });

  group('parity with the website catalogue', () {
    test('ids and labels match src/lib/services.ts exactly', () {
      if (!websiteServices.existsSync()) {
        markTestSkipped(
          'website checkout not present at ${websiteServices.path}; '
          'catalogue parity is unverified in this run',
        );
        return;
      }

      final source = websiteServices.readAsStringSync();
      final body = source
          .split('export const SERVICES: ServiceOption[] = [')
          .last
          .split('\n];')
          .first;

      final entry = RegExp(
        r'\{\s*id:\s*"([^"]+)",\s*label:\s*"([^"]+)"',
        multiLine: true,
      );
      final expected = <String, String>{
        for (final match in entry.allMatches(body))
          match.group(1)!: match.group(2)!,
      };

      expect(
        expected,
        isNotEmpty,
        reason: 'could not parse the website catalogue; the shape has changed',
      );

      final actual = <String, String>{
        for (final option in kServices) option.id: option.label,
      };

      expect(
        actual.keys.toSet(),
        expected.keys.toSet(),
        reason:
            'services.ts and lib/core/constants/services.dart disagree on which '
            'ids exist. An id only the app knows is dropped silently on save; '
            'an id only the website knows renders as a raw slug.',
      );

      for (final id in expected.keys) {
        expect(
          actual[id],
          expected[id],
          reason: 'label for "$id" has drifted from the website',
        );
      }
    });
  });
}
