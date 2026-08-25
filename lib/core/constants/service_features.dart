/// What a member offers, under whichever primary service they chose.
///
/// **Generated from the website's `src/lib/service-features.ts`.**
///
/// ## Why this generalises the Hookup list
///
/// Until 2026-08-22 only Hookup had a detail list. Every other primary service
/// was a bare badge, so a profile saying "Relationship" told a visitor nothing
/// beyond the word while a Hookup profile carried thirty specifics. That
/// asymmetry made the explicit list look like the point of the platform rather
/// than one option on it. Each of the six now has its own catalogue.
///
/// The Hookup catalogue is **not** duplicated here: it stays in
/// `hookup_services.dart` and is reshaped into this type by [featuresFor], for
/// the same reason the website keeps it in its own module - it is the only
/// explicit list, it has its own gating history, and folding it in would bury
/// that.
///
/// ## One column, validated per service
///
/// All six store into `dating_profiles.serviceFeatures`, renamed from
/// `hookupServices` on 2026-08-22. A member has exactly one primary service, so
/// at most one catalogue is ever live for them.
///
/// **Switching primary service clears the column**, and that is deliberate: the
/// ids belong to the old catalogue and mean nothing under the new one, so
/// keeping them would leave a Relationship profile holding Hookup selections
/// that any read path forgetting to check would publish.
///
/// Ids are prefixed per service (`rel_`, `din_`, `fwb_`, `chat_`, `open_`) so no
/// id can ever be valid under two catalogues. Without the prefix "travel" would
/// be legitimate under three of them, and a member switching service would keep
/// a selection that happened to collide.
///
/// `test/unit/service_features_test.dart` reads the real TypeScript and fails
/// when the two drift.
library;

import 'hookup_services.dart';
import 'primary_services.dart';

class ServiceFeature {
  const ServiceFeature({
    required this.id,
    required this.label,
    required this.group,
  });

  /// Stable storage key. Never change it once shipped.
  final String id;

  /// Display text. Safe to reword.
  final String label;

  /// Heading it renders under. A plain string rather than an enum, because the
  /// groups differ per catalogue and are editorial.
  final String group;
}

const List<ServiceFeature> _kRelationshipFeatures = <ServiceFeature>[
  ServiceFeature(id: 'rel_long_term', label: 'Long term', group: 'What I want'),
  ServiceFeature(id: 'rel_exclusive', label: 'Exclusive', group: 'What I want'),
  ServiceFeature(
    id: 'rel_marriage_minded',
    label: 'Marriage minded',
    group: 'What I want',
  ),
  ServiceFeature(
    id: 'rel_serious_dating',
    label: 'Serious dating',
    group: 'What I want',
  ),
  ServiceFeature(
    id: 'rel_take_it_slow',
    label: 'Happy to take it slow',
    group: 'What I want',
  ),
  ServiceFeature(
    id: 'rel_wants_children',
    label: 'Wants children',
    group: 'Life plans',
  ),
  ServiceFeature(
    id: 'rel_has_children',
    label: 'Has children',
    group: 'Life plans',
  ),
  ServiceFeature(
    id: 'rel_open_to_relocate',
    label: 'Open to relocating',
    group: 'Life plans',
  ),
  ServiceFeature(
    id: 'rel_long_distance_ok',
    label: 'Long distance is fine',
    group: 'Life plans',
  ),
  ServiceFeature(
    id: 'rel_daily_contact',
    label: 'Daily conversation',
    group: 'How I connect',
  ),
  ServiceFeature(
    id: 'rel_emotional_support',
    label: 'Emotional support',
    group: 'How I connect',
  ),
  ServiceFeature(
    id: 'rel_quality_time',
    label: 'Quality time together',
    group: 'How I connect',
  ),
  ServiceFeature(
    id: 'rel_meet_family',
    label: 'Meeting family and friends',
    group: 'How I connect',
  ),
  ServiceFeature(
    id: 'rel_faith_matters',
    label: 'Shared faith matters to me',
    group: 'How I connect',
  ),
];

const List<ServiceFeature> _kDinnerDateFeatures = <ServiceFeature>[
  ServiceFeature(
    id: 'din_fine_dining',
    label: 'Fine dining',
    group: 'Where I like to go',
  ),
  ServiceFeature(
    id: 'din_casual',
    label: 'Casual restaurants',
    group: 'Where I like to go',
  ),
  ServiceFeature(
    id: 'din_lounge',
    label: 'Lounges and bars',
    group: 'Where I like to go',
  ),
  ServiceFeature(
    id: 'din_drinks',
    label: 'Drinks and cocktails',
    group: 'Where I like to go',
  ),
  ServiceFeature(
    id: 'din_nightlife',
    label: 'Nightlife and clubbing',
    group: 'Where I like to go',
  ),
  ServiceFeature(
    id: 'din_cinema',
    label: 'Cinema',
    group: 'Where I like to go',
  ),
  ServiceFeature(
    id: 'din_live_music',
    label: 'Live music and concerts',
    group: 'Where I like to go',
  ),
  ServiceFeature(
    id: 'din_beach',
    label: 'Beach and pool days',
    group: 'Where I like to go',
  ),
  ServiceFeature(
    id: 'din_brunch',
    label: 'Coffee and brunch',
    group: 'Where I like to go',
  ),
  ServiceFeature(
    id: 'din_plus_one',
    label: 'Plus one for events',
    group: 'Occasions',
  ),
  ServiceFeature(
    id: 'din_business_dinner',
    label: 'Business dinners',
    group: 'Occasions',
  ),
  ServiceFeature(
    id: 'din_weddings',
    label: 'Weddings and parties',
    group: 'Occasions',
  ),
  ServiceFeature(
    id: 'din_birthdays',
    label: 'Birthday celebrations',
    group: 'Occasions',
  ),
  ServiceFeature(
    id: 'din_travel_companion',
    label: 'Travel companion',
    group: 'Occasions',
  ),
  ServiceFeature(
    id: 'din_dutch',
    label: 'Happy to split the bill',
    group: 'How it works',
  ),
  ServiceFeature(
    id: 'din_public_first',
    label: 'Public place for a first meet',
    group: 'How it works',
  ),
];

const List<ServiceFeature> _kFwbFeatures = <ServiceFeature>[
  ServiceFeature(
    id: 'fwb_ongoing',
    label: 'Ongoing arrangement',
    group: 'The arrangement',
  ),
  ServiceFeature(
    id: 'fwb_no_strings',
    label: 'No strings attached',
    group: 'The arrangement',
  ),
  ServiceFeature(
    id: 'fwb_exclusive',
    label: 'Exclusive to one person',
    group: 'The arrangement',
  ),
  ServiceFeature(
    id: 'fwb_discreet',
    label: 'Discreet',
    group: 'The arrangement',
  ),
  ServiceFeature(
    id: 'fwb_friends_first',
    label: 'Friends first',
    group: 'The arrangement',
  ),
  ServiceFeature(id: 'fwb_regular', label: 'Regular meetups', group: 'When'),
  ServiceFeature(id: 'fwb_weekends', label: 'Weekends', group: 'When'),
  ServiceFeature(id: 'fwb_evenings', label: 'Evenings', group: 'When'),
  ServiceFeature(id: 'fwb_occasional', label: 'Now and then', group: 'When'),
  ServiceFeature(id: 'fwb_sleepovers', label: 'Sleepovers', group: 'When'),
  ServiceFeature(id: 'fwb_my_place', label: 'My place', group: 'Where'),
  ServiceFeature(id: 'fwb_your_place', label: 'Your place', group: 'Where'),
  ServiceFeature(id: 'fwb_hotels', label: 'Hotels', group: 'Where'),
  ServiceFeature(id: 'fwb_travel', label: 'Travel together', group: 'Where'),
  ServiceFeature(
    id: 'fwb_chat_between',
    label: 'Chat between meetups',
    group: 'Between times',
  ),
  ServiceFeature(
    id: 'fwb_no_chat_between',
    label: 'No contact between meetups',
    group: 'Between times',
  ),
];

const List<ServiceFeature> _kChatBuddyFeatures = <ServiceFeature>[
  ServiceFeature(id: 'chat_texting', label: 'Texting', group: 'How we talk'),
  ServiceFeature(
    id: 'chat_voice_notes',
    label: 'Voice notes',
    group: 'How we talk',
  ),
  ServiceFeature(
    id: 'chat_voice_calls',
    label: 'Voice calls',
    group: 'How we talk',
  ),
  ServiceFeature(
    id: 'chat_video_calls',
    label: 'Video calls',
    group: 'How we talk',
  ),
  ServiceFeature(
    id: 'chat_photos',
    label: 'Sharing photos',
    group: 'How we talk',
  ),
  ServiceFeature(id: 'chat_morning', label: 'Morning check ins', group: 'When'),
  ServiceFeature(id: 'chat_daily', label: 'Every day', group: 'When'),
  ServiceFeature(
    id: 'chat_late_night',
    label: 'Late night chats',
    group: 'When',
  ),
  ServiceFeature(id: 'chat_weekends', label: 'Weekends', group: 'When'),
  ServiceFeature(
    id: 'chat_good_listener',
    label: 'Good listener',
    group: 'What to expect',
  ),
  ServiceFeature(
    id: 'chat_emotional_support',
    label: 'Emotional support',
    group: 'What to expect',
  ),
  ServiceFeature(
    id: 'chat_banter',
    label: 'Jokes and banter',
    group: 'What to expect',
  ),
  ServiceFeature(
    id: 'chat_gaming',
    label: 'Gaming together',
    group: 'What to expect',
  ),
  ServiceFeature(
    id: 'chat_language_practice',
    label: 'Language practice',
    group: 'What to expect',
  ),
  ServiceFeature(
    id: 'chat_online_only',
    label: 'Online only, no meeting up',
    group: 'Boundaries',
  ),
  ServiceFeature(
    id: 'chat_open_to_meet_later',
    label: 'Open to meeting later',
    group: 'Boundaries',
  ),
];

const List<ServiceFeature> _kOpenToAnythingFeatures = <ServiceFeature>[
  ServiceFeature(
    id: 'open_lets_talk',
    label: 'Let us talk and see',
    group: 'How to start',
  ),
  ServiceFeature(
    id: 'open_online_first',
    label: 'Online first',
    group: 'How to start',
  ),
  ServiceFeature(
    id: 'open_public_first',
    label: 'Public place first',
    group: 'How to start',
  ),
  ServiceFeature(id: 'open_no_rush', label: 'No rush', group: 'How to start'),
  ServiceFeature(
    id: 'open_to_serious',
    label: 'Could be serious',
    group: 'Open to',
  ),
  ServiceFeature(
    id: 'open_to_casual',
    label: 'Could be casual',
    group: 'Open to',
  ),
  ServiceFeature(
    id: 'open_to_friendship',
    label: 'Friendship',
    group: 'Open to',
  ),
  ServiceFeature(
    id: 'open_to_dates',
    label: 'Dates and outings',
    group: 'Open to',
  ),
  ServiceFeature(id: 'open_to_travel', label: 'Travel', group: 'Open to'),
  ServiceFeature(
    id: 'open_to_events',
    label: 'Events and occasions',
    group: 'Open to',
  ),
  ServiceFeature(
    id: 'open_flexible_schedule',
    label: 'Flexible schedule',
    group: 'Practicalities',
  ),
  ServiceFeature(
    id: 'open_evenings',
    label: 'Evenings',
    group: 'Practicalities',
  ),
  ServiceFeature(
    id: 'open_weekends',
    label: 'Weekends',
    group: 'Practicalities',
  ),
];

/// The Hookup catalogue, unchanged, reshaped to the shared type.
List<ServiceFeature> get _hookupFeatures => <ServiceFeature>[
  for (final HookupServiceOption s in kHookupServices)
    ServiceFeature(id: s.id, label: s.label, group: s.group.label),
];

/// The heading shown above the list, per service.
///
/// Different words because the lists mean different things: what someone
/// *offers* under Hookup, what they *want* under Relationship. One generic
/// "Services" heading over both would make the Relationship list read as a menu.
const Map<String, String> kFeaturesHeading = <String, String>{
  'relationship': 'What I am looking for',
  'dinner_date': 'What I enjoy',
  'fwb': 'How I like it',
  'chat_buddy': 'How I like to chat',
  'hookup': 'What I offer',
  'open_to_anything': 'I am open to',
};

/// The heading for a stored service, or a neutral fallback for an unknown one.
String featuresHeading(String? primaryService) =>
    kFeaturesHeading[primaryService] ?? 'What I offer';

/// Every feature defined for a primary service. Empty for an unknown id.
List<ServiceFeature> featuresFor(String? primaryService) =>
    switch (primaryService) {
      'relationship' => _kRelationshipFeatures,
      'dinner_date' => _kDinnerDateFeatures,
      'fwb' => _kFwbFeatures,
      'chat_buddy' => _kChatBuddyFeatures,
      kHookupId => _hookupFeatures,
      'open_to_anything' => _kOpenToAnythingFeatures,
      _ => const <ServiceFeature>[],
    };

/// One group and its options, for the selector and the profile.
typedef ServiceFeatureGrouping = ({String group, List<ServiceFeature> options});

/// Grouped in declaration order, empty groups omitted.
List<ServiceFeatureGrouping> featuresByGroup(String? primaryService) {
  final List<String> order = <String>[];
  final Map<String, List<ServiceFeature>> byGroup =
      <String, List<ServiceFeature>>{};
  for (final ServiceFeature f in featuresFor(primaryService)) {
    if (!byGroup.containsKey(f.group)) {
      byGroup[f.group] = <ServiceFeature>[];
      order.add(f.group);
    }
    byGroup[f.group]!.add(f);
  }
  return <ServiceFeatureGrouping>[
    for (final String g in order) (group: g, options: byGroup[g]!),
  ];
}

/// Display text for a stored id under a given service.
///
/// Empty when it does not belong there - **never the raw slug**, which is what
/// would print "owo" on a public profile.
String featureLabel(String? primaryService, String id) {
  for (final ServiceFeature f in featuresFor(primaryService)) {
    if (f.id == id) return f.label;
  }
  return '';
}

/// The most a member may tick, for the service they actually chose.
int maxFeaturesFor(String? primaryService) =>
    featuresFor(primaryService).length;

/// Coerces input into a storable list **for the service they chose**.
///
/// Mirrors `sanitizeServiceFeatures`. [primaryService] is a required argument
/// rather than an optional flag: it is the whole gate, and a write path that can
/// forget to pass it is a write path that eventually stores a Hookup list
/// against a Relationship profile.
///
/// A null or unknown service yields an empty list. Ids from another catalogue
/// are dropped rather than rejected, so a stale screen cannot fail a good save.
List<String> sanitizeServiceFeatures(
  Iterable<String>? input, {
  required String? primaryService,
}) {
  final List<ServiceFeature> catalogue = featuresFor(primaryService);
  if (catalogue.isEmpty || input == null) return const <String>[];
  final Set<String> wanted = input.toSet();
  // Catalogue order, not tap order, so a profile renders the same list however
  // it was built.
  return <String>[
    for (final ServiceFeature f in catalogue)
      if (wanted.contains(f.id)) f.id,
  ];
}

/// Catalogue entries for stored ids, in catalogue order.
List<ServiceFeature> serviceFeaturesForIds(
  String? primaryService,
  Iterable<String>? ids,
) {
  if (ids == null) return const <ServiceFeature>[];
  final Set<String> wanted = ids.toSet();
  if (wanted.isEmpty) return const <ServiceFeature>[];
  return <ServiceFeature>[
    for (final ServiceFeature f in featuresFor(primaryService))
      if (wanted.contains(f.id)) f,
  ];
}

/// True when this service's list is the explicit one.
///
/// Used only to decide whether the editor shows the extra warning - never to
/// decide whether the list may be stored, which is [sanitizeServiceFeatures].
bool isExplicitCatalogue(String? primaryService) => primaryService == kHookupId;
