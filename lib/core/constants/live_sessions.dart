/// Live sessions: what a member offers **inside the app**, priced in credits
/// per minute.
///
/// **Generated from the website's `src/lib/live-sessions.ts`.**
///
/// ## Why this is not `MemberRates`
///
/// The two look alike and are deliberately separate, because they are priced in
/// different units and settled in different places:
///
///   * **Rates** (`lib/data/models/rates.dart`) are MONEY, in the member's own
///     currency, stored as integer minor units. The platform never touches that
///     money — it is arranged between two people over WhatsApp.
///   * **Live sessions** (this file) are CREDITS, the platform's own unit, a
///     plain whole number per minute.
///
/// `formatMoney()` must never be pointed at these values: it divides by the
/// currency's minor unit, so 50 credits would render as "₦0.50", and
/// `parseRateInput` would multiply them by 100 on the way in. Separate columns,
/// separate parser, separate payload key (`liveRates`, not `rates`).
///
/// ## Credits are whole numbers
///
/// A credit is not divisible anywhere else in the product — the wallet, the
/// ledger and boosts are all integers — so a fractional per-minute price could
/// never actually be charged. Input is rejected rather than silently truncated.
///
/// ## What the app cannot do yet, and says so
///
/// There is no session backend and no delivery path: nothing in this app can
/// start a video call, record to a request, or bill a minute. A member may
/// publish prices, and a viewer sees them, exactly as on the website — and the
/// website sends every one of these options to `/app`, which says plainly that
/// the feature has not shipped. `features/app/get_the_app_screen.dart` is this
/// app's copy of that answer. **Do not wire a fake session flow to these
/// prices.**
///
/// `test/unit/live_sessions_test.dart` reads the real TypeScript and fails when
/// the two drift.
library;

class LiveSessionOption {
  const LiveSessionOption({
    required this.id,
    required this.label,
    required this.description,
    required this.field,
  });

  /// Stable id. Never change it once shipped.
  final String id;

  /// Display text. Safe to reword.
  final String label;

  /// What the member is agreeing to provide. Shown under the label.
  final String description;

  /// The `dating_profiles` column holding the price, and the key `liveRates`
  /// expects on `PATCH /api/profile`.
  final String field;
}

/// The catalogue, in the website's order.
const List<LiveSessionOption> kLiveSessions = <LiveSessionOption>[
  LiveSessionOption(
    id: 'custom_video',
    label: 'Custom video',
    description: 'A video recorded to your request.',
    field: 'liveCustomVideoCredits',
  ),
  LiveSessionOption(
    id: 'custom_audio',
    label: 'Custom audio',
    description: 'A voice note recorded to your request.',
    field: 'liveCustomAudioCredits',
  ),
  LiveSessionOption(
    id: 'erotic_video',
    label: 'Erotic video',
    description: 'An adult video call, 18+ only.',
    field: 'liveEroticVideoCredits',
  ),
  LiveSessionOption(
    id: 'sex_chat',
    label: 'Sex chat',
    description: 'An adult text session, 18+ only.',
    field: 'liveSexChatCredits',
  ),
];

/// The column names, in catalogue order. Mirrors `LIVE_SESSION_FIELDS`.
final List<String> kLiveSessionFields = <String>[
  for (final LiveSessionOption s in kLiveSessions) s.field,
];

/// Ceiling on a per-minute price, in credits.
///
/// The column is a 32-bit integer, and a member fat-fingering three extra zeroes
/// should be told rather than publishing a price nobody can pay. **0 is allowed
/// and is a real claim ("free"), distinct from null.**
const int kMaxCreditsPerMin = 100000;

/// Validates one typed per-minute price, mirroring `parseLiveSessionInput`.
///
/// Returns the backend's own message, or null when the value is storable. An
/// empty string is valid and means "not offered" — deliberately distinct from
/// 0, because conflating them would leave no way to withdraw an offer once made.
String? validateLiveSessionCredits(String? raw) {
  final String value = (raw ?? '').trim();
  if (value.isEmpty) return null;

  // People paste "1,000". Strip separators before parsing rather than failing
  // on them, exactly as the route does.
  final String cleaned = value.replaceAll(RegExp(r'[\s,]'), '');
  final num? parsed = num.tryParse(cleaned);
  if (parsed == null || !parsed.isFinite) return 'Enter a number.';
  if (parsed != parsed.roundToDouble()) return 'Credits are whole numbers.';
  if (parsed < 0) return 'A price cannot be negative.';
  if (parsed > kMaxCreditsPerMin) {
    return 'That is above the maximum of ${_grouped(kMaxCreditsPerMin)}.';
  }
  return null;
}

/// "1,000" — thousands separated, matching `toLocaleString()` on the website.
String _grouped(int value) {
  final String digits = value.abs().toString();
  final StringBuffer out = StringBuffer(value < 0 ? '-' : '');
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Formats a stored per-minute price the way the website's `liveSessionRows`
/// does, including the free case and the singular.
String liveSessionPriceLabel(int credits) {
  if (credits == 0) return 'Free';
  return '${_grouped(credits)} ${credits == 1 ? 'credit' : 'credits'} / min';
}
