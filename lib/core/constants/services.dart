/// The member Services catalogue — what a member may advertise on their
/// profile.
///
/// **Generated from the website's `src/lib/services.ts`, which is the single
/// definition.** The backend validates every id against that file on write
/// (`sanitizeServiceIds`), so an id present here but not there is silently
/// dropped on save, and an id there but not here renders as a raw slug on a
/// public profile. Neither failure produces an error anywhere.
///
/// `test/unit/services_catalogue_test.dart` reads the real TypeScript and
/// fails when the two drift. It has already caught one live divergence.
///
/// ## Why ids and not labels
///
/// `DatingProfile.services` stores the `id` ("dinner_dates"), never the
/// display label. Labels are editorial and get reworded; ids are data.
///
/// The consequence, same as on the website: **never change an existing id.**
/// Reword `label` freely. To retire an entry keep its id and mark it
/// `retired`, so members who already hold it keep seeing a label rather than a
/// bare slug.
///
/// The catalogue was reworked on 2026-08-20 from an explicit list to a
/// companionship one. The 35 old ids are still here, `retired: true` in the
/// `archived` group — that is the retire-don't-delete rule doing its job, and
/// it is why a profile written before the change still renders properly.
library;

enum ServiceGroup {
  datesOutings('Dates & Outings', 0),
  eventsOccasions('Events & Occasions', 1),
  travelGetaways('Travel & Getaways', 2),
  conversationCompany('Conversation & Company', 3),
  archived('Archived', -1);

  const ServiceGroup(this.label, this.renderOrder);

  /// Heading text, matching the website's grouping.
  final String label;

  /// Position in the selector, or -1 for a group that is never rendered.
  ///
  /// "Archived" holds the retired entries and is deliberately absent from the
  /// website's `SERVICE_GROUPS`. Keeping it in the enum is what lets a profile
  /// still render an id a member selected before the catalogue changed.
  final int renderOrder;

  /// Whether this group appears in the selector at all.
  bool get isSelectable => renderOrder >= 0;
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
  ServiceOption(id: 'dinner_dates', label: 'Dinner dates', group: ServiceGroup.datesOutings),
  ServiceOption(id: 'lunch_dates', label: 'Lunch dates', group: ServiceGroup.datesOutings),
  ServiceOption(id: 'coffee_dates', label: 'Coffee and brunch', group: ServiceGroup.datesOutings),
  ServiceOption(id: 'cinema_dates', label: 'Cinema and movie nights', group: ServiceGroup.datesOutings),
  ServiceOption(id: 'drinks_out', label: 'Drinks and cocktails', group: ServiceGroup.datesOutings),
  ServiceOption(id: 'nightlife', label: 'Nightlife and clubbing', group: ServiceGroup.datesOutings),
  ServiceOption(id: 'live_music', label: 'Live music and concerts', group: ServiceGroup.datesOutings),
  ServiceOption(id: 'beach_days', label: 'Beach and pool days', group: ServiceGroup.datesOutings),
  ServiceOption(id: 'sightseeing', label: 'City tours and sightseeing', group: ServiceGroup.datesOutings),
  ServiceOption(id: 'shopping_trips', label: 'Shopping trips', group: ServiceGroup.datesOutings),
  ServiceOption(id: 'plus_one', label: 'Plus one for events', group: ServiceGroup.eventsOccasions),
  ServiceOption(id: 'wedding_guest', label: 'Weddings and parties', group: ServiceGroup.eventsOccasions),
  ServiceOption(id: 'business_dinner', label: 'Business dinners', group: ServiceGroup.eventsOccasions),
  ServiceOption(id: 'corporate_events', label: 'Corporate and networking events', group: ServiceGroup.eventsOccasions),
  ServiceOption(id: 'birthday_celebrations', label: 'Birthday celebrations', group: ServiceGroup.eventsOccasions),
  ServiceOption(id: 'family_functions', label: 'Family functions', group: ServiceGroup.eventsOccasions),
  ServiceOption(id: 'sports_events', label: 'Sports and match days', group: ServiceGroup.eventsOccasions),
  ServiceOption(id: 'travel_companion', label: 'Travel companion', group: ServiceGroup.travelGetaways),
  ServiceOption(id: 'weekend_getaway', label: 'Weekend getaways', group: ServiceGroup.travelGetaways),
  ServiceOption(id: 'road_trips', label: 'Road trips', group: ServiceGroup.travelGetaways),
  ServiceOption(id: 'staycations', label: 'Hotel staycations', group: ServiceGroup.travelGetaways),
  ServiceOption(id: 'city_guide', label: 'Local guide and city host', group: ServiceGroup.travelGetaways),
  ServiceOption(id: 'good_conversation', label: 'Good conversation', group: ServiceGroup.conversationCompany),
  ServiceOption(id: 'video_call_dates', label: 'Video call dates', group: ServiceGroup.conversationCompany),
  ServiceOption(id: 'phone_calls', label: 'Phone call catch ups', group: ServiceGroup.conversationCompany),
  ServiceOption(id: 'chat_partner', label: 'Texting and chat', group: ServiceGroup.conversationCompany),
  ServiceOption(id: 'preparing_a_meal', label: 'Cooking together', group: ServiceGroup.conversationCompany),
  ServiceOption(id: 'workout_partner', label: 'Gym and workout partner', group: ServiceGroup.conversationCompany),
  ServiceOption(id: 'dance_partner', label: 'Dancing', group: ServiceGroup.conversationCompany),
  ServiceOption(id: 'game_night', label: 'Games and game nights', group: ServiceGroup.conversationCompany),
  ServiceOption(id: 'art_and_culture', label: 'Museums, art and culture', group: ServiceGroup.conversationCompany),
  ServiceOption(id: 'couples', label: 'Couples', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'gfe', label: 'GFE', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'pse', label: 'PSE', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'lap_dancing', label: 'Lap dancing', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'massage', label: 'Massage', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'erotic_massage', label: 'Erotic massage', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'tantric_massage', label: 'Tantric massage', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'prostate_massage', label: 'Prostate massage', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'body_worship', label: 'Body worship', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'sixty_nine', label: '69', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'dfk', label: 'DFK', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'french_kissing', label: 'French kissing', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'blow_job', label: 'Blow job', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'owo', label: 'OWO', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'oral_with_condom', label: 'Oral with condom', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'hand_job', label: 'Hand job', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'cim', label: 'CIM', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'cof', label: 'COF', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'cob', label: 'COB', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'swallow', label: 'Swallow', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'threesome', label: 'Threesome', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'mmf_3somes', label: 'MMF 3somes', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'rimming_giving', label: 'Rimming', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'face_sitting', label: 'Face sitting', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'role_play_fantasy', label: 'Role play and fantasy', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'bdsm_giving', label: 'BDSM', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'tie_and_tease', label: 'Tie and tease', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'erotic_spanking_giving', label: 'Erotic spanking', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'humiliation_giving', label: 'Humiliation', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'pegging', label: 'Pegging', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'foot_fetish', label: 'Foot fetish', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'sex_toys', label: 'Sex toys', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'golden_shower', label: 'Golden shower', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'watersports_giving', label: 'Watersports', group: ServiceGroup.archived, retired: true),
  ServiceOption(id: 'food_play', label: 'Food play', group: ServiceGroup.archived, retired: true),];

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

/// Catalogue entries for a member's stored ids, in catalogue order.
///
/// Retired entries are **included**, which is the whole point of retiring
/// rather than deleting: a member who selected "gfe" before the catalogue was
/// reworked still sees a label on their profile instead of a bare slug.
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

/// Grouped for the selector UI, in the website's render order.
///
/// Retired entries and the "Archived" group are excluded — a member choosing
/// what to offer should only ever be shown what they may still select.
List<ServiceGrouping> servicesByGroup() {
  final List<ServiceGroup> ordered =
      ServiceGroup.values.where((ServiceGroup g) => g.isSelectable).toList()
        ..sort((ServiceGroup a, ServiceGroup b) =>
            a.renderOrder.compareTo(b.renderOrder));

  return <ServiceGrouping>[
    for (final ServiceGroup g in ordered)
      (
        group: g,
        options: <ServiceOption>[
          for (final ServiceOption s in kServices)
            if (s.group == g && !s.retired) s,
        ],
      ),
  ].where((ServiceGrouping r) => r.options.isNotEmpty).toList();
}
