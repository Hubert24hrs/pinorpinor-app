/// The member Services catalogue — what a member may advertise on their
/// profile.
///
/// **Transcribed from the website's `src/lib/services.ts`, which is the single
/// definition.** The backend validates every id against that file on write
/// (`sanitizeServiceIds`), so an id present here but not there is silently
/// dropped on save, and an id there but not here renders as a raw slug. If
/// that file changes, change this one in the same commit —
/// `test/unit/services_catalogue_test.dart` reads the real TypeScript and
/// fails when the two drift.
///
/// ## Why ids and not labels
///
/// `DatingProfile.services` stores the `id` ("gfe", "cim"), never the display
/// label. Labels are editorial and get reworded; ids are data. Storing
/// "OWO (Oral without condom)" and later dropping the parenthetical would
/// silently unmatch every member who had selected it, from both the catalogue
/// and the discovery filter, with no way to tell a rename from a deletion.
///
/// The consequence, same as on the website: **never change an existing id.**
/// Reword `label` freely. To retire an entry keep its id and mark it
/// `retired`, so members who already hold it keep seeing a label rather than a
/// bare slug.
library;

enum ServiceGroup {
  companionship('Companionship'),
  massageTouch('Massage & Touch'),
  intimacy('Intimacy'),
  fetishRoleplay('Fetish & Roleplay');

  const ServiceGroup(this.label);

  /// Heading text, matching the website's grouping.
  final String label;
}

class ServiceOption {
  const ServiceOption({
    required this.id,
    required this.label,
    required this.group,
    this.retired = false,
  });

  /// Stable storage key. Never change this once shipped.
  final String id;

  /// Display text. Safe to reword.
  final String label;

  final ServiceGroup group;

  /// Hidden from new selections, but still rendered for members who hold it.
  final bool retired;
}

/// The catalogue, in the website's order. The selector and the profile both
/// render in this order, so a profile reads the same however the chips were
/// tapped.
const List<ServiceOption> kServices = <ServiceOption>[
  ServiceOption(id: 'dinner_dates', label: 'Dinner Dates', group: ServiceGroup.companionship),
  ServiceOption(id: 'couples', label: 'Couples', group: ServiceGroup.companionship),
  ServiceOption(id: 'gfe', label: 'GFE (Girlfriend experience)', group: ServiceGroup.companionship),
  ServiceOption(id: 'pse', label: 'PSE (Porn Star Experience)', group: ServiceGroup.companionship),
  ServiceOption(id: 'preparing_a_meal', label: 'Preparing a meal', group: ServiceGroup.companionship),
  ServiceOption(id: 'lap_dancing', label: 'Lap dancing', group: ServiceGroup.companionship),
  ServiceOption(id: 'massage', label: 'Massage', group: ServiceGroup.massageTouch),
  ServiceOption(id: 'erotic_massage', label: 'Erotic massage', group: ServiceGroup.massageTouch),
  ServiceOption(id: 'tantric_massage', label: 'Tantric Massage', group: ServiceGroup.massageTouch),
  ServiceOption(id: 'prostate_massage', label: 'Prostate Massage', group: ServiceGroup.massageTouch),
  ServiceOption(id: 'body_worship', label: 'Body Worship', group: ServiceGroup.massageTouch),
  ServiceOption(id: 'sixty_nine', label: '69', group: ServiceGroup.intimacy),
  ServiceOption(id: 'dfk', label: 'DFK (Deep french kissing)', group: ServiceGroup.intimacy),
  ServiceOption(id: 'french_kissing', label: 'French Kissing', group: ServiceGroup.intimacy),
  ServiceOption(id: 'blow_job', label: 'Blow Job', group: ServiceGroup.intimacy),
  ServiceOption(id: 'owo', label: 'OWO (Oral without condom)', group: ServiceGroup.intimacy),
  ServiceOption(id: 'oral_with_condom', label: 'Oral with condom', group: ServiceGroup.intimacy),
  ServiceOption(id: 'hand_job', label: 'Hand Job', group: ServiceGroup.intimacy),
  ServiceOption(id: 'cim', label: 'CIM (Cum in mouth)', group: ServiceGroup.intimacy),
  ServiceOption(id: 'cof', label: 'COF (Cum on face)', group: ServiceGroup.intimacy),
  ServiceOption(id: 'cob', label: 'COB (Cum on body)', group: ServiceGroup.intimacy),
  ServiceOption(id: 'swallow', label: 'Swallow (at discretion)', group: ServiceGroup.intimacy),
  ServiceOption(id: 'threesome', label: 'Threesome', group: ServiceGroup.intimacy),
  ServiceOption(id: 'mmf_3somes', label: 'MMF 3somes', group: ServiceGroup.intimacy),
  ServiceOption(id: 'rimming_giving', label: 'Rimming (giving)', group: ServiceGroup.intimacy),
  ServiceOption(id: 'face_sitting', label: 'Face Sitting', group: ServiceGroup.intimacy),
  ServiceOption(id: 'role_play_fantasy', label: 'Role Play & Fantasy', group: ServiceGroup.fetishRoleplay),
  ServiceOption(id: 'bdsm_giving', label: 'BDSM (giving)', group: ServiceGroup.fetishRoleplay),
  ServiceOption(id: 'tie_and_tease', label: 'Tie & Tease', group: ServiceGroup.fetishRoleplay),
  ServiceOption(id: 'erotic_spanking_giving', label: 'Erotic Spanking (giving)', group: ServiceGroup.fetishRoleplay),
  ServiceOption(id: 'humiliation_giving', label: 'Humiliation (giving)', group: ServiceGroup.fetishRoleplay),
  ServiceOption(id: 'pegging', label: 'Pegging', group: ServiceGroup.fetishRoleplay),
  ServiceOption(id: 'foot_fetish', label: 'Foot Fetish', group: ServiceGroup.fetishRoleplay),
  ServiceOption(id: 'sex_toys', label: 'Sex toys', group: ServiceGroup.fetishRoleplay),
  ServiceOption(id: 'golden_shower', label: 'Golden shower', group: ServiceGroup.fetishRoleplay),
  ServiceOption(id: 'watersports_giving', label: 'Watersports (giving)', group: ServiceGroup.fetishRoleplay),
  ServiceOption(id: 'food_play', label: 'Food Play', group: ServiceGroup.fetishRoleplay),];

/// The most a member may select — the same ceiling the API validates against.
final int kMaxServices = kServices.length;

final Map<String, ServiceOption> _byId = <String, ServiceOption>{
  for (final ServiceOption s in kServices) s.id: s,
};

final Set<String> _selectableIds = <String>{
  for (final ServiceOption s in kServices)
    if (!s.retired) s.id,
};

/// Whether [id] may be written. Retired entries stay readable but are not
/// selectable, mirroring the backend.
bool isValidServiceId(String id) => _selectableIds.contains(id);

/// Display text for a stored id.
///
/// Falls back to the raw id so an entry dropped from the catalogue by mistake
/// renders as *something* rather than vanishing off a member's profile.
String serviceLabel(String id) => _byId[id]?.label ?? id;

/// Coerce stored or chosen ids into a clean, storable list.
///
/// Unknown ids are dropped rather than rejected — a member saving from a stale
/// screen after an entry is retired should not have the whole save fail.
/// Duplicates collapse and catalogue order is imposed, exactly as
/// `sanitizeServiceIds` does server-side.
List<String> sanitizeServiceIds(Iterable<String> input) {
  final Set<String> wanted = input.where(isValidServiceId).toSet();
  return <String>[
    for (final ServiceOption s in kServices)
      if (wanted.contains(s.id)) s.id,
  ];
}

/// Catalogue entries for a member's stored ids, in catalogue order. Retired
/// entries are included, so a profile keeps rendering everything it holds.
List<ServiceOption> servicesForIds(Iterable<String>? ids) {
  if (ids == null) return const <ServiceOption>[];
  final Set<String> wanted = ids.toSet();
  if (wanted.isEmpty) return const <ServiceOption>[];
  return <ServiceOption>[
    for (final ServiceOption s in kServices)
      if (wanted.contains(s.id)) s,
  ];
}

/// One group and its selectable options, for the selector UI.
typedef ServiceGrouping = ({ServiceGroup group, List<ServiceOption> options});

/// Grouped for the selector UI. Retired entries are excluded from selection.
List<ServiceGrouping> servicesByGroup() {
  return <ServiceGrouping>[
    for (final ServiceGroup g in ServiceGroup.values)
      (
        group: g,
        options: <ServiceOption>[
          for (final ServiceOption s in kServices)
            if (s.group == g && !s.retired) s,
        ],
      ),
  ].where((ServiceGrouping r) => r.options.isNotEmpty).toList();
}
