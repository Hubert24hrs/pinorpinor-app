import '../../core/utils/money.dart';
import 'json.dart';

/// The rates a member advertises.
///
/// Every amount here is an **integer in minor units** exactly as stored — see
/// `lib/core/utils/money.dart` for why that matters and why dividing by 100 is
/// wrong for a third of the world's currencies.
///
/// `null` means "not published". It is not zero: zero is a real claim ("free")
/// that the backend accepts and stores, and conflating the two would make a
/// published rate impossible to withdraw.
class MemberRates {
  const MemberRates({
    this.currency,
    this.ratesVisible = true,
    this.shortIncall,
    this.shortOutcall,
    this.nightIncall,
    this.nightOutcall,
    this.weekendIncall,
    this.weekendOutcall,
    this.audioPerMin,
    this.videoPerMin,
    this.callPerMin,
  });

  static const MemberRates empty = MemberRates();

  /// ISO 4217. Null means "derive it from the member's country".
  final String? currency;

  /// The member's switch for the whole block. False hides every rate.
  final bool ratesVisible;

  final int? shortIncall;
  final int? shortOutcall;
  final int? nightIncall;
  final int? nightOutcall;
  final int? weekendIncall;
  final int? weekendOutcall;

  /// Per-minute prices the member advertises. **The platform does not deliver
  /// calls or custom media in-app** — these are quoted here and arranged
  /// through the existing WhatsApp consent gate, exactly as on the website.
  final int? audioPerMin;
  final int? videoPerMin;
  final int? callPerMin;

  /// Whether the member has published anything at all, which decides whether
  /// the block renders.
  bool get hasAny =>
      shortIncall != null ||
      shortOutcall != null ||
      nightIncall != null ||
      nightOutcall != null ||
      weekendIncall != null ||
      weekendOutcall != null ||
      audioPerMin != null ||
      videoPerMin != null ||
      callPerMin != null;

  /// Visible to a viewer only when the member has both published something and
  /// left the block switched on.
  bool get isVisible => ratesVisible && hasAny;

  /// The currency actually in force, given the profile's country.
  Currency resolvedCurrency(String? countryCode) =>
      resolveCurrency(storedCurrency: currency, countryCode: countryCode);

  /// Booking rows for the public table.
  ///
  /// A duration with neither price set is omitted rather than rendered as a row
  /// of dashes: an empty row implies the member declined to price it, when in
  /// fact they simply have not filled it in. Mirrors `rateTableRows`.
  List<RateRow> tableRows(String? countryCode) {
    final String code = resolvedCurrency(countryCode).code;
    final List<RateRow> rows = <RateRow>[
      RateRow(
        label: 'Short time',
        incall: formatMoney(shortIncall, currencyCode: code),
        outcall: formatMoney(shortOutcall, currencyCode: code),
      ),
      RateRow(
        label: 'Overnight',
        incall: formatMoney(nightIncall, currencyCode: code),
        outcall: formatMoney(nightOutcall, currencyCode: code),
      ),
      RateRow(
        label: 'Weekend',
        incall: formatMoney(weekendIncall, currencyCode: code),
        outcall: formatMoney(weekendOutcall, currencyCode: code),
      ),
    ];
    return rows
        .where((RateRow r) => r.incall != null || r.outcall != null)
        .toList(growable: false);
  }

  /// Per-minute rows, omitting anything unpublished. Mirrors `perMinuteRows`.
  List<({String label, String amount})> perMinuteRows(String? countryCode) {
    final String code = resolvedCurrency(countryCode).code;
    final List<({String label, String amount})> rows =
        <({String label, String amount})>[];
    void add(String label, int? minor) {
      final String? amount = formatMoney(minor, currencyCode: code);
      if (amount != null) rows.add((label: label, amount: amount));
    }

    add('Custom audio', audioPerMin);
    add('Custom video', videoPerMin);
    add('Phone call', callPerMin);
    return rows;
  }

  /// Reads the rate columns off a `datingProfile` object.
  ///
  /// The keys are the raw Prisma column names, because that is what the API
  /// serialises — there is no rates sub-object on the wire.
  factory MemberRates.fromProfileJson(Map<String, dynamic> profile) {
    return MemberRates(
      currency: asStringOrNull(profile['currency']),
      // Absent means visible: the column defaults to true, and a response that
      // omits it (an older endpoint) must not hide rates it did send.
      ratesVisible: profile.containsKey('ratesVisible')
          ? asBool(profile['ratesVisible'])
          : true,
      shortIncall: asIntOrNull(profile['rateShortIncall']),
      shortOutcall: asIntOrNull(profile['rateShortOutcall']),
      nightIncall: asIntOrNull(profile['rateNightIncall']),
      nightOutcall: asIntOrNull(profile['rateNightOutcall']),
      weekendIncall: asIntOrNull(profile['rateWeekendIncall']),
      weekendOutcall: asIntOrNull(profile['rateWeekendOutcall']),
      audioPerMin: asIntOrNull(profile['rateAudioPerMin']),
      videoPerMin: asIntOrNull(profile['rateVideoPerMin']),
      callPerMin: asIntOrNull(profile['rateCallPerMin']),
    );
  }

  /// The `rates` sub-object `PATCH /api/profile` expects.
  ///
  /// Values are sent in **major** units, as typed, because the route converts
  /// with `parseRateInput` against the profile's currency. Converting here as
  /// well is how a rate ends up stored a hundred times out.
  static Map<String, Object?> patchBody(Map<String, String> majorByField) {
    return <String, Object?>{
      for (final MapEntry<String, String> e in majorByField.entries)
        e.key: e.value.trim().isEmpty ? null : e.value.trim(),
    };
  }
}

/// One booking row: a duration with an incall and/or outcall price.
class RateRow {
  const RateRow({required this.label, this.incall, this.outcall});

  final String label;

  /// Already formatted for display, or null when unpublished.
  final String? incall;
  final String? outcall;
}

/// The rate field names `PATCH /api/profile` accepts, matching `RATE_FIELDS`.
const List<({String field, String label})> kRateFields =
    <({String field, String label})>[
  (field: 'rateShortIncall', label: 'Short time — incall'),
  (field: 'rateShortOutcall', label: 'Short time — outcall'),
  (field: 'rateNightIncall', label: 'Overnight — incall'),
  (field: 'rateNightOutcall', label: 'Overnight — outcall'),
  (field: 'rateWeekendIncall', label: 'Weekend — incall'),
  (field: 'rateWeekendOutcall', label: 'Weekend — outcall'),
  (field: 'rateAudioPerMin', label: 'Custom audio, per minute'),
  (field: 'rateVideoPerMin', label: 'Custom video, per minute'),
  (field: 'rateCallPerMin', label: 'Phone call, per minute'),
];

/// Upper bound on any single rate, in major units — the same ceiling the
/// backend enforces. The column is a 32-bit integer, so a large enough figure
/// in a 2-digit currency overflows and Postgres rejects the write with an
/// opaque error.
const int kMaxRateMajor = 10000000;
