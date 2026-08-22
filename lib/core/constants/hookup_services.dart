/// The explicit service list, restored on the website 2026-08-21 behind the
/// Hookup gate.
///
/// **Generated from the website's `src/lib/hookup-services.ts`.** This is the
/// catalogue that was taken off the platform on 2026-08-20 and left in
/// `services.ts` as an "Archived" block. It is back, under two conditions that
/// did not exist before:
///
///   1. it is only offered to a member whose primary service is Hookup, and
///   2. it only renders on a profile whose primary service is still Hookup.
///
/// Both are enforced server-side, in `sanitizeHookupServices()` and in
/// `withGatedHookupServices()`, which strips the column from all five
/// profile-returning endpoints. That walker exists because of what went wrong
/// the first time this list moved: the screens stopped showing it while the four
/// public endpoints kept publishing the whole list as JSON. **Removing a
/// catalogue from the screen is not removing it.**
///
/// The app applies the same gate on read and on write. It is not the thing
/// enforcing it — the server is — but a client that renders an ungated list is a
/// client that will eventually post one.
///
/// ## Ids are deliberately identical to the archived ones
///
/// Same slugs as the `archived` group in `services.dart`. That block stays
/// retired: members hold those ids in their `services` column and it is what
/// makes those rows readable. Reusing the spellings means the two lists cannot
/// drift into describing the same thing under different keys.
///
/// `test/unit/hookup_services_test.dart` reads the real TypeScript and fails
/// when the two drift.
library;

enum HookupServiceGroup {
  companionship('Companionship'),
  massageTouch('Massage & Touch'),
  oral('Oral'),
  kinkFantasy('Kink & Fantasy'),
  extras('Extras');

  const HookupServiceGroup(this.label);

  /// Heading text, matching `HOOKUP_SERVICE_GROUPS` on the website. The enum's
  /// declaration order is the render order.
  final String label;
}

class HookupServiceOption {
  const HookupServiceOption({
    required this.id,
    required this.label,
    required this.group,
  });

  /// Stable storage key. Never change this once shipped.
  final String id;

  /// Display text. Safe to reword.
  final String label;

  final HookupServiceGroup group;
}

/// The catalogue, in the website's order.
const List<HookupServiceOption> kHookupServices = <HookupServiceOption>[
  // Companionship
  HookupServiceOption(
    id: 'gfe',
    label: 'GFE',
    group: HookupServiceGroup.companionship,
  ),
  HookupServiceOption(
    id: 'pse',
    label: 'PSE',
    group: HookupServiceGroup.companionship,
  ),
  HookupServiceOption(
    id: 'couples',
    label: 'Couples',
    group: HookupServiceGroup.companionship,
  ),
  HookupServiceOption(
    id: 'threesome',
    label: 'Threesome',
    group: HookupServiceGroup.companionship,
  ),
  HookupServiceOption(
    id: 'mmf_3somes',
    label: 'MMF 3somes',
    group: HookupServiceGroup.companionship,
  ),
  HookupServiceOption(
    id: 'lap_dancing',
    label: 'Lap dancing',
    group: HookupServiceGroup.companionship,
  ),

  // Massage & Touch
  HookupServiceOption(
    id: 'massage',
    label: 'Massage',
    group: HookupServiceGroup.massageTouch,
  ),
  HookupServiceOption(
    id: 'erotic_massage',
    label: 'Erotic massage',
    group: HookupServiceGroup.massageTouch,
  ),
  HookupServiceOption(
    id: 'tantric_massage',
    label: 'Tantric massage',
    group: HookupServiceGroup.massageTouch,
  ),
  HookupServiceOption(
    id: 'prostate_massage',
    label: 'Prostate massage',
    group: HookupServiceGroup.massageTouch,
  ),
  HookupServiceOption(
    id: 'body_worship',
    label: 'Body worship',
    group: HookupServiceGroup.massageTouch,
  ),
  HookupServiceOption(
    id: 'hand_job',
    label: 'Hand job',
    group: HookupServiceGroup.massageTouch,
  ),

  // Oral
  HookupServiceOption(id: 'dfk', label: 'DFK', group: HookupServiceGroup.oral),
  HookupServiceOption(
    id: 'french_kissing',
    label: 'French kissing',
    group: HookupServiceGroup.oral,
  ),
  HookupServiceOption(
    id: 'blow_job',
    label: 'Blow job',
    group: HookupServiceGroup.oral,
  ),
  HookupServiceOption(id: 'owo', label: 'OWO', group: HookupServiceGroup.oral),
  HookupServiceOption(
    id: 'oral_with_condom',
    label: 'Oral with condom',
    group: HookupServiceGroup.oral,
  ),
  HookupServiceOption(
    id: 'sixty_nine',
    label: '69',
    group: HookupServiceGroup.oral,
  ),
  HookupServiceOption(id: 'cim', label: 'CIM', group: HookupServiceGroup.oral),
  HookupServiceOption(id: 'cof', label: 'COF', group: HookupServiceGroup.oral),
  HookupServiceOption(id: 'cob', label: 'COB', group: HookupServiceGroup.oral),
  HookupServiceOption(
    id: 'swallow',
    label: 'Swallow',
    group: HookupServiceGroup.oral,
  ),
  HookupServiceOption(
    id: 'rimming_giving',
    label: 'Rimming',
    group: HookupServiceGroup.oral,
  ),
  HookupServiceOption(
    id: 'face_sitting',
    label: 'Face sitting',
    group: HookupServiceGroup.oral,
  ),

  // Kink & Fantasy
  HookupServiceOption(
    id: 'role_play_fantasy',
    label: 'Role play and fantasy',
    group: HookupServiceGroup.kinkFantasy,
  ),
  HookupServiceOption(
    id: 'bdsm_giving',
    label: 'BDSM',
    group: HookupServiceGroup.kinkFantasy,
  ),
  HookupServiceOption(
    id: 'tie_and_tease',
    label: 'Tie and tease',
    group: HookupServiceGroup.kinkFantasy,
  ),
  HookupServiceOption(
    id: 'erotic_spanking_giving',
    label: 'Erotic spanking',
    group: HookupServiceGroup.kinkFantasy,
  ),
  HookupServiceOption(
    id: 'humiliation_giving',
    label: 'Humiliation',
    group: HookupServiceGroup.kinkFantasy,
  ),
  HookupServiceOption(
    id: 'pegging',
    label: 'Pegging',
    group: HookupServiceGroup.kinkFantasy,
  ),
  HookupServiceOption(
    id: 'foot_fetish',
    label: 'Foot fetish',
    group: HookupServiceGroup.kinkFantasy,
  ),

  // Extras
  HookupServiceOption(
    id: 'sex_toys',
    label: 'Sex toys',
    group: HookupServiceGroup.extras,
  ),
  HookupServiceOption(
    id: 'golden_shower',
    label: 'Golden shower',
    group: HookupServiceGroup.extras,
  ),
  HookupServiceOption(
    id: 'watersports_giving',
    label: 'Watersports',
    group: HookupServiceGroup.extras,
  ),
  HookupServiceOption(
    id: 'food_play',
    label: 'Food play',
    group: HookupServiceGroup.extras,
  ),
];

final Map<String, HookupServiceOption> _byId = <String, HookupServiceOption>{
  for (final HookupServiceOption s in kHookupServices) s.id: s,
};

/// The most a member may tick. The whole catalogue is a legitimate answer.
final int kMaxHookupServices = kHookupServices.length;

bool isValidHookupServiceId(String id) => _byId.containsKey(id);

/// Display text for a stored id. Empty string for anything unrecognised.
String hookupServiceLabel(String id) => _byId[id]?.label ?? '';

/// Coerces input into a clean, storable list, in catalogue order.
///
/// Mirrors `sanitizeHookupServices`, including its argument order. Unknown ids
/// are dropped rather than rejected, so saving from a screen that was open when
/// the catalogue changed does not fail the whole write.
///
/// [offersHookup] is a **required** argument rather than an optional flag, for
/// the same reason it is on the website: a member whose primary service is not
/// Hookup stores an empty list, full stop, and making every caller answer the
/// question means a new write path cannot forget it exists.
List<String> sanitizeHookupServices(
  Iterable<String>? input, {
  required bool offersHookup,
}) {
  if (!offersHookup || input == null) return const <String>[];
  final Set<String> wanted = input.where(isValidHookupServiceId).toSet();
  return <String>[
    for (final HookupServiceOption s in kHookupServices)
      if (wanted.contains(s.id)) s.id,
  ];
}

/// Catalogue entries for stored ids, in catalogue order.
List<HookupServiceOption> hookupServicesForIds(Iterable<String>? ids) {
  if (ids == null) return const <HookupServiceOption>[];
  final Set<String> wanted = ids.toSet();
  if (wanted.isEmpty) return const <HookupServiceOption>[];
  return <HookupServiceOption>[
    for (final HookupServiceOption s in kHookupServices)
      if (wanted.contains(s.id)) s,
  ];
}

/// One group and its options, for the selector UI.
typedef HookupServiceGrouping = ({
  HookupServiceGroup group,
  List<HookupServiceOption> options,
});

/// Grouped for the selector, empty groups omitted.
List<HookupServiceGrouping> hookupServicesByGroup() => <HookupServiceGrouping>[
  for (final HookupServiceGroup g in HookupServiceGroup.values)
    (
      group: g,
      options: <HookupServiceOption>[
        for (final HookupServiceOption s in kHookupServices)
          if (s.group == g) s,
      ],
    ),
].where((HookupServiceGrouping r) => r.options.isNotEmpty).toList();
