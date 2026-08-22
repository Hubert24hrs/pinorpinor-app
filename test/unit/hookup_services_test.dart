import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/constants/hookup_services.dart';
import 'package:pinorpinor_app/core/constants/services.dart';

/// Guards the explicit service catalogue, and the gate in front of it.
///
/// Two separate failures are covered here, and the second is the one with a
/// victim.
///
/// **Drift**, as with every generated catalogue: an id here but not there is
/// dropped by `sanitizeHookupServices` on save, so a member's selection vanishes
/// with no error; an id there but not here renders as a raw slug on a public
/// profile.
///
/// **The gate.** This list may only be stored or rendered while the member's
/// primary service is Hookup. The website learned this the hard way in August:
/// its screens stopped showing the list, and four public endpoints carried on
/// publishing the whole thing as JSON to anonymous callers. Removing a
/// catalogue from the screen is not removing it, which is why the app applies
/// the gate in the model and on the way out, not only in the widgets.
void main() {
  final websiteCatalogue = File('../pinorpinor/src/lib/hookup-services.ts');
  final websiteServices = File('../pinorpinor/src/lib/services.ts');

  group('catalogue self-consistency', () {
    test('every id is unique', () {
      final ids = kHookupServices.map((s) => s.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every id is a lowercase slug', () {
      final slug = RegExp(r'^[a-z0-9_]+$');
      for (final option in kHookupServices) {
        expect(slug.hasMatch(option.id), isTrue, reason: option.id);
      }
    });

    test('no label is empty', () {
      for (final option in kHookupServices) {
        expect(option.label.trim(), isNotEmpty, reason: option.id);
      }
    });

    test('every group has at least one option', () {
      for (final grouping in hookupServicesByGroup()) {
        expect(grouping.options, isNotEmpty, reason: grouping.group.label);
      }
    });

    test('grouping covers the whole catalogue exactly once', () {
      final grouped = <String>[
        for (final g in hookupServicesByGroup())
          for (final o in g.options) o.id,
      ];
      expect(grouped.toSet(), kHookupServices.map((s) => s.id).toSet());
      expect(grouped, hasLength(kHookupServices.length));
    });
  });

  group('the gate', () {
    test('sanitize returns nothing at all when the member is not offering', () {
      final ids = kHookupServices.take(3).map((s) => s.id).toList();

      expect(sanitizeHookupServices(ids, offersHookup: true), ids);
      expect(
        sanitizeHookupServices(ids, offersHookup: false),
        isEmpty,
        reason:
            'a member whose primary service is not Hookup stores an empty '
            'list, full stop',
      );
    });

    test('null input is empty, not an error', () {
      expect(sanitizeHookupServices(null, offersHookup: true), isEmpty);
    });

    test('unknown ids are dropped rather than rejecting the whole list', () {
      // Matches the server: saving from a screen that was open when the
      // catalogue changed should not fail the entire write over one stale chip.
      final known = kHookupServices.first.id;
      final result = sanitizeHookupServices(<String>[
        'not_a_real_service',
        known,
      ], offersHookup: true);

      expect(result, <String>[known]);
    });

    test('duplicates collapse and catalogue order is imposed', () {
      final first = kHookupServices[0].id;
      final second = kHookupServices[1].id;

      final result = sanitizeHookupServices(<String>[
        second,
        first,
        second,
      ], offersHookup: true);

      expect(result, <String>[first, second], reason: 'catalogue order');
    });

    test('label lookup never returns a raw slug', () {
      expect(hookupServiceLabel('not_a_real_service'), isEmpty);
      for (final option in kHookupServices) {
        expect(hookupServiceLabel(option.id), option.label);
      }
    });
  });

  group('ids are shared with the retired block, deliberately', () {
    test('every hookup id also exists in the archived services group', () {
      // The website reuses the archived slugs on purpose, so the two lists
      // cannot drift into describing the same thing under different keys. Two
      // live members still hold these ids in their `services` column, and that
      // is what keeps those rows readable.
      final Set<String> archived = <String>{
        for (final s in kServices)
          if (s.retired) s.id,
      };

      for (final option in kHookupServices) {
        expect(
          archived,
          contains(option.id),
          reason:
              '"${option.id}" is not among the retired services. Either the '
              'website minted a new id here, or the archived block lost one - '
              'and a member holding it now renders a bare slug.',
        );
      }
    });
  });

  group('parity with the website', () {
    test('the same ids, in the same order', () {
      if (!websiteCatalogue.existsSync()) {
        markTestSkipped(
          'website checkout not present at ${websiteCatalogue.path}; '
          'catalogue parity is unverified in this run',
        );
        return;
      }

      final source = websiteCatalogue.readAsStringSync();
      final body = source
          .split('export const HOOKUP_SERVICES: HookupServiceOption[] = [')
          .last
          .split('\n];')
          .first;

      final entry = RegExp(r'\{\s*id:\s*"([a-z0-9_]+)",\s*label:\s*"([^"]+)"');
      final matches = entry.allMatches(body).toList();

      expect(
        matches,
        isNotEmpty,
        reason: 'could not parse hookup-services.ts; its shape has changed',
      );

      expect(kHookupServices.map((s) => s.id).toList(), <String>[
        for (final m in matches) m.group(1)!,
      ]);
      expect(kHookupServices.map((s) => s.label).toList(), <String>[
        for (final m in matches) m.group(2)!,
      ]);
    });

    test('the same group headings, in the same order', () {
      if (!websiteCatalogue.existsSync()) {
        markTestSkipped('website checkout not present');
        return;
      }

      final source = websiteCatalogue.readAsStringSync();
      final body = source
          .split('export const HOOKUP_SERVICE_GROUPS: HookupServiceGroup[] = [')
          .last
          .split('\n];')
          .first;

      final expected = <String>[
        for (final m in RegExp(r'"([^"]+)"').allMatches(body)) m.group(1)!,
      ];

      expect(expected, isNotEmpty);
      expect(HookupServiceGroup.values.map((g) => g.label).toList(), expected);
    });

    test('the archived block on the website still holds these ids', () {
      if (!websiteServices.existsSync()) {
        markTestSkipped('website checkout not present');
        return;
      }

      final source = websiteServices.readAsStringSync();
      for (final option in kHookupServices) {
        expect(
          source.contains('"${option.id}"'),
          isTrue,
          reason:
              '"${option.id}" has disappeared from services.ts. The retired '
              'entries are what keep an existing profile readable.',
        );
      }
    });
  });
}
