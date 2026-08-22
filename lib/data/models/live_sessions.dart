import '../../core/constants/live_sessions.dart';
import 'json.dart';

/// The per-minute credit prices a member publishes for live sessions.
///
/// The catalogue and the reasoning live in
/// `lib/core/constants/live_sessions.dart`. The one rule worth repeating here:
/// **these are credits, not money.** Never pass them through `formatMoney` or
/// the `rates` payload key — the first divides by a currency's minor unit and
/// the second multiplies by it, and either would misprice a member's profile by
/// a factor of a hundred.
///
/// `null` means "not offered". `0` means free, which the backend accepts and
/// stores. Conflating them would make an offer impossible to withdraw.
class MemberLiveSessions {
  const MemberLiveSessions({this.creditsByField = const <String, int>{}});

  static const MemberLiveSessions empty = MemberLiveSessions();

  /// Column name to whole credits per minute. A field absent from this map is
  /// not offered.
  final Map<String, int> creditsByField;

  bool get hasAny => creditsByField.isNotEmpty;

  int? creditsFor(String field) => creditsByField[field];

  /// The sessions this member actually offers, ready to render.
  ///
  /// Options with no price are **omitted entirely** rather than shown as
  /// unavailable — listing all four and greying three out advertises what
  /// someone declined as prominently as what they offer. Mirrors
  /// `liveSessionRows`.
  List<LiveSessionRow> get rows => <LiveSessionRow>[
    for (final LiveSessionOption option in kLiveSessions)
      if (creditsByField[option.field] != null)
        LiveSessionRow(
          option: option,
          credits: creditsByField[option.field]!,
          priceLabel: liveSessionPriceLabel(creditsByField[option.field]!),
        ),
  ];

  /// Reads the `liveXCredits` columns off a `datingProfile` object.
  ///
  /// The keys are the raw Prisma column names, because that is what the API
  /// serialises — there is no `liveSessions` sub-object on the wire.
  factory MemberLiveSessions.fromProfileJson(Map<String, dynamic> profile) {
    final Map<String, int> values = <String, int>{};
    for (final String field in kLiveSessionFields) {
      final int? credits = asIntOrNull(profile[field]);
      if (credits != null) values[field] = credits;
    }
    return MemberLiveSessions(creditsByField: values);
  }

  /// Stored values as editor strings, empty for "not offered". Mirrors
  /// `liveSessionsToInput`.
  Map<String, String> toInput() => <String, String>{
    for (final String field in kLiveSessionFields)
      field: creditsByField[field]?.toString() ?? '',
  };

  /// The `liveRates` sub-object `PATCH /api/profile` expects.
  ///
  /// Sent as typed. An empty string becomes null, which is how a member takes an
  /// option off their profile.
  static Map<String, Object?> patchBody(Map<String, String> typedByField) =>
      <String, Object?>{
        for (final MapEntry<String, String> e in typedByField.entries)
          if (kLiveSessionFields.contains(e.key))
            e.key: e.value.trim().isEmpty ? null : e.value.trim(),
      };
}

/// One priced session, ready to render.
class LiveSessionRow {
  const LiveSessionRow({
    required this.option,
    required this.credits,
    required this.priceLabel,
  });

  final LiveSessionOption option;
  final int credits;

  /// Preformatted, so no widget has to decide how to say it.
  final String priceLabel;
}
