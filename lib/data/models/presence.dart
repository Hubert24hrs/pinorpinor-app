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
  online('Online now'),
  today('Active today'),
  thisWeek('Active this week'),
  away('Away');

  const Presence(this.label);

  /// Display text, matching `PRESENCE_LABEL` on the website.
  final String label;

  /// Parses the wire value. Anything unrecognised falls back to [away], which
  /// is the claim that asserts least about the member.
  static Presence parse(Object? value) {
    return switch (value?.toString().toUpperCase()) {
      'ONLINE' => Presence.online,
      'TODAY' => Presence.today,
      'THIS_WEEK' => Presence.thisWeek,
      _ => Presence.away,
    };
  }

  /// Only [online] earns a live indicator. Showing a dot for "active this
  /// week" would make an absent member look present.
  bool get isOnlineNow => this == Presence.online;
}
