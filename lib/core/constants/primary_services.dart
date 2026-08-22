/// The member's PRIMARY SERVICE — the one thing they are here for.
///
/// **Generated from the website's `src/lib/primary-services.ts`, which is the
/// single definition.** Added there on 2026-08-21. This is a single choice, not
/// a list, it is required at registration, and it is the headline fact on a
/// member card: it replaced the two badges that used to sit at the top of every
/// card ("Approved Member" / "Verified Woman"), which said nothing a visitor
/// could act on and covered the member's face while saying it.
///
/// ## Why this is separate from `services`
///
/// [kServices] in `services.dart` is an optional multi-select list of
/// activities. This is exactly one value, it is required, and it **drives
/// behaviour**: choosing [kHookupId] opens the booking form and changes what a
/// public profile renders. The backend keeps them in different columns for the
/// same reason, and `sanitizeHookupServices` reads this value to decide whether
/// the explicit list may be stored at all.
///
/// ## Null is a real state
///
/// A member who registered before 2026-08-21 has no primary service and renders
/// **no badge**. Never substitute a default: guessing one publishes a claim on a
/// real person's public profile that they never made. That is why
/// [sanitizePrimaryService] returns null rather than falling back.
///
/// ## Ids are storage keys
///
/// The same rule as every catalogue here: `id` is what lands in the database and
/// must never change; `label` is editorial and may be reworded freely.
///
/// `test/unit/primary_services_test.dart` reads the real TypeScript and fails
/// when the two drift.
library;

import 'dart:ui' show Color;

/// The id that unlocks the hookup booking block.
///
/// Named rather than written as a bare `'hookup'` at each call site: the rates
/// block, the explicit service list, registration and the profile screen all key
/// off this one value, and a typo in any of them would show or hide a whole
/// section with no error. Mirrors `HOOKUP_ID`.
const String kHookupId = 'hookup';

class PrimaryServiceOption {
  const PrimaryServiceOption({
    required this.id,
    required this.label,
    required this.hint,
    required this.glyph,
    required this.badgeBg,
    required this.badgeFg,
    required this.badgeBorder,
  });

  /// Stable storage key. Never change this once shipped.
  final String id;

  /// Display text. Safe to reword.
  final String label;

  /// One line under the label in the picker. Not shown on cards.
  final String hint;

  /// Shown beside the label on cards and in the picker. An emoji on the website
  /// too, deliberately — a character needs no icon map that can fall out of
  /// step with this list.
  final String glyph;

  /// The badge colours, held here rather than in the widget so the card, the
  /// picker and the profile screen cannot drift apart. These are the literal
  /// values behind the website's `badgeClass` Tailwind tokens.
  final Color badgeBg;
  final Color badgeFg;
  final Color badgeBorder;
}

/// The catalogue, in the order it renders.
///
/// Six entries, and the picker shows all six at once with no search field. That
/// is the point of a short list — the 31-entry activity catalogue needs grouping
/// and a filter to be usable on a phone, and this one must not.
const List<PrimaryServiceOption> kPrimaryServices = <PrimaryServiceOption>[
  PrimaryServiceOption(
    id: 'relationship',
    label: 'Relationship',
    hint: 'Looking for something exclusive and long term.',
    glyph: '💞',
    badgeBg: Color(0xFFFFE4E6),
    badgeFg: Color(0xFF9F1239),
    badgeBorder: Color(0xFFFECDD3),
  ),
  PrimaryServiceOption(
    id: 'dinner_date',
    label: 'Dinner Date',
    hint: 'Dinner, drinks and going out together.',
    glyph: '🍷',
    badgeBg: Color(0xFFFEF3C7),
    badgeFg: Color(0xFF78350F),
    badgeBorder: Color(0xFFFDE68A),
  ),
  PrimaryServiceOption(
    id: 'fwb',
    label: 'FWB',
    hint: 'Friends with benefits. Ongoing, casual, no strings.',
    glyph: '🔥',
    badgeBg: Color(0xFFFFEDD5),
    badgeFg: Color(0xFF7C2D12),
    badgeBorder: Color(0xFFFED7AA),
  ),
  PrimaryServiceOption(
    id: 'chat_buddy',
    label: 'Chat Buddy',
    hint: 'Conversation and company online. No meeting up.',
    glyph: '💬',
    badgeBg: Color(0xFFE0F2FE),
    badgeFg: Color(0xFF0C4A6E),
    badgeBorder: Color(0xFFBAE6FD),
  ),
  PrimaryServiceOption(
    id: kHookupId,
    label: 'Hookup',
    hint: 'Meeting up. You will be asked for your bookings and what you offer.',
    glyph: '🌙',
    badgeBg: Color(0xFFFAE8FF),
    badgeFg: Color(0xFF701A75),
    badgeBorder: Color(0xFFF5D0FE),
  ),
  PrimaryServiceOption(
    id: 'open_to_anything',
    label: 'Open To Anything',
    hint: 'No fixed plan. Say hello and see where it goes.',
    glyph: '✨',
    badgeBg: Color(0xFFD1FAE5),
    badgeFg: Color(0xFF064E3B),
    badgeBorder: Color(0xFFA7F3D0),
  ),
];

final Map<String, PrimaryServiceOption> _byId = <String, PrimaryServiceOption>{
  for (final PrimaryServiceOption s in kPrimaryServices) s.id: s,
};

bool isPrimaryServiceId(Object? value) =>
    value is String && _byId.containsKey(value);

/// Coerces client input into a storable id, or null.
///
/// Mirrors `sanitizePrimaryService`. Null must survive — see the note on null
/// being a real state above.
String? sanitizePrimaryService(Object? input) =>
    isPrimaryServiceId(input) ? input! as String : null;

/// The catalogue entry for a stored id, or null when unset or unrecognised.
PrimaryServiceOption? primaryServiceFor(String? id) {
  if (id == null || id.isEmpty) return null;
  return _byId[id];
}

/// Display text for a stored id. Empty string when unset — **never the raw
/// slug**, which is what a member would otherwise see on a public profile.
String primaryServiceLabel(String? id) => primaryServiceFor(id)?.label ?? '';

/// Whether a stored primary service should show the hookup booking block.
///
/// The app asks this to decide what to *render*; the server re-derives it from
/// the stored row on every write, in four places. A form is not a gate.
bool offersHookup(String? id) => id == kHookupId;
