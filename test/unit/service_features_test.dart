import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinorpinor_app/core/constants/hookup_services.dart';
import 'package:pinorpinor_app/core/constants/primary_services.dart';
import 'package:pinorpinor_app/core/constants/service_features.dart';

/// Guards the per-service feature catalogues, and the gate that keeps them
/// apart.
///
/// This column was `hookupServices` until 2026-08-22 and the rename alone broke
/// the app silently: everything sent under the old key was accepted with a 200
/// and stored nowhere, so a member ticked a list, saved, and watched it vanish.
///
/// The gate matters more than the names. Ids are prefixed per catalogue
/// precisely so no id can be valid under two services — without that, "travel"
/// would be legitimate under three of them and a member switching service would
/// keep a selection that happened to collide. That is the cross-catalogue leak
/// these tests exist to prevent.
void main() {
  final websiteCatalogue = File('../pinorpinor/src/lib/service-features.ts');

  /// Every service that has a catalogue, which is all six.
  final List<String> serviceIds = <String>[
    for (final PrimaryServiceOption s in kPrimaryServices) s.id,
  ];

  group('every service has a list', () {
    test('none of the six is a bare badge any more', () {
      // The asymmetry this removed: a Relationship profile said one word while
      // a Hookup profile carried thirty specifics, which made the explicit list
      // look like the point of the platform rather than one option on it.
      for (final String id in serviceIds) {
        expect(
          featuresFor(id),
          isNotEmpty,
          reason: '$id has no features, so its profiles say nothing',
        );
      }
    });

    test('an unknown service has no catalogue, and no crash', () {
      expect(featuresFor(null), isEmpty);
      expect(featuresFor('not_a_service'), isEmpty);
      expect(maxFeaturesFor(null), 0);
    });

    test('every heading is set, and they are not all the same word', () {
      final Set<String> headings = <String>{
        for (final String id in serviceIds) featuresHeading(id),
      };
      for (final String id in serviceIds) {
        expect(featuresHeading(id).trim(), isNotEmpty, reason: id);
      }
      expect(
        headings,
        hasLength(serviceIds.length),
        reason:
            'the lists mean different things - what someone offers under '
            'Hookup, what they want under Relationship - and one generic '
            'heading over both would make the Relationship list read as a menu',
      );
    });

    test('grouping covers each catalogue exactly once, in order', () {
      for (final String id in serviceIds) {
        final List<String> grouped = <String>[
          for (final ServiceFeatureGrouping g in featuresByGroup(id))
            for (final ServiceFeature f in g.options) f.id,
        ];
        expect(
          grouped,
          featuresFor(id).map((ServiceFeature f) => f.id).toList(),
          reason: '$id regrouped into a different order',
        );
      }
    });
  });

  group('ids cannot cross catalogues', () {
    test('no id is valid under two services', () {
      final Map<String, String> seen = <String, String>{};
      for (final String service in serviceIds) {
        for (final ServiceFeature f in featuresFor(service)) {
          final String? owner = seen[f.id];
          expect(
            owner,
            isNull,
            reason:
                '"${f.id}" belongs to both $owner and $service. A member '
                'switching between them would keep a selection that only '
                'collided by accident.',
          );
          seen[f.id] = service;
        }
      }
    });

    test('the five new catalogues are prefixed', () {
      const Map<String, String> prefixes = <String, String>{
        'relationship': 'rel_',
        'dinner_date': 'din_',
        'fwb': 'fwb_',
        'chat_buddy': 'chat_',
        'open_to_anything': 'open_',
      };
      for (final MapEntry<String, String> e in prefixes.entries) {
        for (final ServiceFeature f in featuresFor(e.key)) {
          expect(f.id, startsWith(e.value), reason: '${e.key}: ${f.id}');
        }
      }
    });

    test('the hookup catalogue is the explicit list, unchanged', () {
      // Not duplicated: it stays in hookup_services.dart, which is where its
      // gating history lives.
      expect(
        featuresFor(kHookupId).map((ServiceFeature f) => f.id).toList(),
        kHookupServices.map((HookupServiceOption s) => s.id).toList(),
      );
      expect(isExplicitCatalogue(kHookupId), isTrue);
      for (final String id in serviceIds) {
        if (id == kHookupId) continue;
        expect(isExplicitCatalogue(id), isFalse, reason: id);
      }
    });
  });

  group('the gate on write', () {
    test('ids from another catalogue are dropped, not rejected', () {
      final String hookupId = featuresFor(kHookupId).first.id;
      final String relId = featuresFor('relationship').first.id;

      expect(
        sanitizeServiceFeatures(<String>[
          hookupId,
          relId,
        ], primaryService: 'relationship'),
        <String>[relId],
      );
    });

    test('an unknown or null service stores nothing at all', () {
      expect(
        sanitizeServiceFeatures(<String>[
          'rel_long_term',
        ], primaryService: null),
        isEmpty,
      );
      expect(
        sanitizeServiceFeatures(<String>[
          'rel_long_term',
        ], primaryService: 'not_a_service'),
        isEmpty,
      );
    });

    test('catalogue order is imposed, and duplicates collapse', () {
      final List<ServiceFeature> all = featuresFor('fwb');
      final String first = all[0].id;
      final String second = all[1].id;

      expect(
        sanitizeServiceFeatures(<String>[
          second,
          first,
          second,
        ], primaryService: 'fwb'),
        <String>[first, second],
        reason: 'a profile must read the same however the chips were tapped',
      );
    });
  });

  group('the gate on read', () {
    test('a label is never the raw slug', () {
      // The failure this prevents is "owo" printed on a public profile.
      expect(featureLabel('relationship', 'not_a_feature'), isEmpty);
      expect(featureLabel(null, 'rel_long_term'), isEmpty);
      expect(featureLabel('relationship', 'rel_long_term'), isNotEmpty);
    });

    test('ids stored under another service render nothing', () {
      final String hookupId = featuresFor(kHookupId).first.id;
      expect(
        serviceFeaturesForIds('relationship', <String>[hookupId]),
        isEmpty,
        reason:
            'a Relationship profile holding Hookup ids must render nothing, '
            'not the other list',
      );
    });
  });

  group('parity with the website', () {
    test('the same ids, labels and groups, per service', () {
      if (!websiteCatalogue.existsSync()) {
        markTestSkipped(
          'website checkout not present at ${websiteCatalogue.path}; '
          'catalogue parity is unverified in this run',
        );
        return;
      }

      final String source = websiteCatalogue.readAsStringSync();
      const Map<String, String> blocks = <String, String>{
        'relationship': 'RELATIONSHIP_FEATURES',
        'dinner_date': 'DINNER_DATE_FEATURES',
        'fwb': 'FWB_FEATURES',
        'chat_buddy': 'CHAT_BUDDY_FEATURES',
        'open_to_anything': 'OPEN_TO_ANYTHING_FEATURES',
      };

      final RegExp entry = RegExp(
        r'\{ id: "([^"]+)", label: "([^"]+)", group: "([^"]+)" \}',
      );

      for (final MapEntry<String, String> e in blocks.entries) {
        final String body = source
            .split('const ${e.value}: ServiceFeature[] = [')
            .last
            .split('\n];')
            .first;
        final List<RegExpMatch> matches = entry.allMatches(body).toList();

        expect(
          matches,
          isNotEmpty,
          reason: 'could not parse ${e.value}; the file shape has changed',
        );

        expect(
          featuresFor(e.key).map((ServiceFeature f) => f.id).toList(),
          <String>[for (final RegExpMatch m in matches) m.group(1)!],
          reason: '${e.key} ids have drifted',
        );
        expect(
          featuresFor(e.key).map((ServiceFeature f) => f.label).toList(),
          <String>[for (final RegExpMatch m in matches) m.group(2)!],
          reason: '${e.key} labels have drifted',
        );
        expect(
          featuresFor(e.key).map((ServiceFeature f) => f.group).toList(),
          <String>[for (final RegExpMatch m in matches) m.group(3)!],
          reason: '${e.key} groups have drifted',
        );
      }
    });

    test('the headings match', () {
      if (!websiteCatalogue.existsSync()) {
        markTestSkipped('website checkout not present');
        return;
      }
      final String source = websiteCatalogue.readAsStringSync();
      final String body = source
          .split(
            'export const FEATURES_HEADING: Record<PrimaryServiceId, string> = {',
          )
          .last
          .split('\n};')
          .first;

      final RegExp line = RegExp(r'(\w+):\s*"([^"]+)"');
      final Map<String, String> expected = <String, String>{
        for (final RegExpMatch m in line.allMatches(body))
          m.group(1)!: m.group(2)!,
      };

      expect(expected, isNotEmpty);
      for (final MapEntry<String, String> e in expected.entries) {
        expect(featuresHeading(e.key), e.value, reason: e.key);
      }
    });

    test('the column the app writes is the one the schema accepts', () {
      final File schema = File('../pinorpinor/src/lib/validations/profile.ts');
      if (!schema.existsSync()) {
        markTestSkipped('website checkout not present');
        return;
      }
      final String source = schema.readAsStringSync();

      expect(
        source.contains('serviceFeatures:'),
        isTrue,
        reason: 'profileUpdateSchema no longer accepts serviceFeatures',
      );
      expect(
        source.contains('hookupServices:'),
        isFalse,
        reason:
            'the old key is back; the app sends serviceFeatures and zod strips '
            'unknown keys silently, so one of the two is being discarded',
      );
    });
  });
}
