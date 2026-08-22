import 'dart:ui' show Color;

/// How recently a member was active, as a coarse bucket.
///
/// **The raw timestamp never leaves the server, by design.** "Last seen 21:47"
/// published to strangers on a meetup platform is a movement log: watched over
/// a few days it reveals when someone sleeps, works and is alone at home. The
/// website's `src/lib/presence.ts` therefore exposes only these four buckets,
/// and they are deliberately wide so an observer cannot difference two loads
/// to recover the underlying time.
///
/// The app must never try to reconstruct a timestamp from one of these, and
/// must never render anything more precise than the label below.
enum Presence {
  online('Online now', Color(0xFF10B981)),
  today('Active today', Color(0xFFF59E0B)),
  thisWeek('Active this week', Color(0xFFA8A29E)),
  away('Away', Color(0xFFD6D3D1));

  const Presence(this.label, this.dotColor);

  /// Display text, matching `PRESENCE_LABEL` on the website.
  final String label;

  /// The indicator colour, matching `PRESENCE_DOT`.
  final Color dotColor;

  /// Parses the wire value. Anything unrecognised falls back to [away], which
  /// is the claim that asserts least about the member.
  static Presence parse(Object? value) => parseOrNull(value) ?? Presence.away;

  /// Parses the wire value, preserving **null**.
  ///
  /// Since 2026-08-21 a member can switch presence off (`showOnline: false`)
  /// without going undiscoverable, and `publicPresence()` then sends null rather
  /// than a bucket. That distinction is load-bearing and must not be collapsed:
  /// [away] is a claim about her ("she has not been here in a week"), null is
  /// the *absence* of a claim, which is what she actually asked for. Both render
  /// nothing, but only one of them is ours to say.
  ///
  /// Use this everywhere a member other than the owner is being shown. [parse]
  /// is for the owner's own view, where there is no switch to honour.
  static Presence? parseOrNull(Object? value) {
    return switch (value?.toString().toUpperCase()) {
      'ONLINE' => Presence.online,
      'TODAY' => Presence.today,
      'THIS_WEEK' => Presence.thisWeek,
      'AWAY' => Presence.away,
      _ => null,
    };
  }

  /// Only [online] earns the "Online now" badge. Showing that for "active this
  /// week" would make an absent member look present.
  bool get isOnlineNow => this == Presence.online;

  /// Whether a member card should draw the presence dot at all.
  ///
  /// [away] does not: "she has not been here in a week" is a claim nobody
  /// benefits from seeing rendered, and the website's card suppresses it for the
  /// same reason. Null presence — the member's own switch — never reaches this
  /// getter, because there is nothing to call it on.
  bool get showsDot => this != Presence.away;
}
