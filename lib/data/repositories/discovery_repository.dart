import '../../core/network/api_client.dart';
import '../models/messaging.dart';
import '../models/profile.dart';
import '../models/settings.dart';

/// Filters the discovery surfaces accept.
///
/// `country` is only honoured for signed-out visitors — a signed-in member is
/// pinned to their own country by `resolveViewerCountry`, and sending a
/// different one changes nothing. `ageMin` is floored at 18 server-side however
/// low the client asks.
class DiscoveryFilters {
  const DiscoveryFilters({
    this.city,
    this.countryCode,
    this.ageMin = 18,
    this.ageMax = 99,
    this.verifiedOnly = false,
    this.availableTodayOnly = false,
  });

  final String? city;
  final String? countryCode;
  final int ageMin;
  final int ageMax;
  final bool verifiedOnly;
  final bool availableTodayOnly;

  static const none = DiscoveryFilters();

  bool get isDefault =>
      (city == null || city!.isEmpty) &&
      ageMin <= 18 &&
      ageMax >= 99 &&
      !verifiedOnly &&
      !availableTodayOnly;

  /// How many filters are active, for the badge on the filter button.
  int get activeCount => <bool>[
    city != null && city!.isNotEmpty && city != 'ALL',
    ageMin > 18 || ageMax < 99,
    verifiedOnly,
    availableTodayOnly,
  ].where((active) => active).length;

  DiscoveryFilters copyWith({
    String? city,
    bool clearCity = false,
    String? countryCode,
    int? ageMin,
    int? ageMax,
    bool? verifiedOnly,
    bool? availableTodayOnly,
  }) => DiscoveryFilters(
    city: clearCity ? null : (city ?? this.city),
    countryCode: countryCode ?? this.countryCode,
    ageMin: ageMin ?? this.ageMin,
    ageMax: ageMax ?? this.ageMax,
    verifiedOnly: verifiedOnly ?? this.verifiedOnly,
    availableTodayOnly: availableTodayOnly ?? this.availableTodayOnly,
  );

  Map<String, dynamic> toQuery({
    required int page,
    required int limit,
  }) => <String, dynamic>{
    'page': page,
    'limit': limit,
    // Never below 18, whatever a caller sets locally.
    'ageMin': ageMin < 18 ? 18 : ageMin,
    'ageMax': ageMax,
    if (city != null && city!.isNotEmpty && city != 'ALL') 'city': city,
    if (countryCode != null && countryCode!.isNotEmpty) 'country': countryCode,
    if (verifiedOnly) 'verified': 'true',
    if (availableTodayOnly) 'available': 'true',
  };
}

class DiscoveryRepository {
  DiscoveryRepository(this._api);

  final ApiClient _api;

  /// The public browse grid. Works signed out, which is the whole point: the
  /// website has no login wall for browsing and the app keeps that.
  Future<ProfilePage> browse({
    DiscoveryFilters filters = DiscoveryFilters.none,
    int page = 1,
    int limit = 12,
  }) async {
    final json = await _api.getJson(
      '/api/public/profiles',
      query: filters.toQuery(page: page, limit: limit),
    );
    return ProfilePage.fromJson(json);
  }

  /// The women rail used on the home screen. Only returns profiles that have at
  /// least one approved profile photo, so it never renders an empty card.
  Future<ProfilePage> ladies({
    DiscoveryFilters filters = DiscoveryFilters.none,
    int page = 1,
    int limit = 24,
  }) async {
    final json = await _api.getJson(
      '/api/ladies',
      query: filters.toQuery(page: page, limit: limit),
    );
    return ProfilePage.fromJson(json);
  }

  /// The signed-in swipe deck. Excludes self, anyone already swiped on, and both
  /// directions of a block — all decided server-side.
  Future<List<ProfileSummary>> deck({
    DiscoveryFilters filters = DiscoveryFilters.none,
    int page = 1,
    int limit = 10,
  }) async {
    final json = await _api.getJson(
      '/api/discover',
      query: <String, dynamic>{
        'page': page,
        'limit': limit,
        'ageMin': filters.ageMin < 18 ? 18 : filters.ageMin,
        'ageMax': filters.ageMax,
        if (filters.city != null &&
            filters.city!.isNotEmpty &&
            filters.city != 'ALL')
          'city': filters.city,
      },
    );
    return ProfileSummary.listFrom(json['candidates']);
  }

  Future<Spotlight> spotlight({String? countryCode}) async {
    final json = await _api.getJson(
      '/api/spotlight',
      query: <String, dynamic>{
        if (countryCode != null && countryCode.isNotEmpty)
          'country': countryCode,
      },
    );
    return Spotlight.fromJson(json);
  }

  Future<List<LocationCount>> locations() async {
    final json = await _api.getJson('/api/public/locations');
    return LocationCount.listFrom(json['locations']);
  }

  /// Records a like/pass/superlike. A mutual like creates the match and its
  /// conversation atomically on the server and notifies both members.
  Future<SwipeResult> swipe({
    required String targetUserId,
    required SwipeActionInput action,
  }) async {
    final json = await _api.postJson(
      '/api/swipe',
      body: <String, String>{
        'targetUserId': targetUserId,
        'action': action.wire,
      },
    );
    return SwipeResult.fromJson(json);
  }

  Future<List<MatchSummary>> matches() async {
    final json = await _api.getJson('/api/matches');
    return MatchSummary.listFrom(json['matches']);
  }
}

/// Local alias so screens do not have to import the model enums directly.
enum SwipeActionInput {
  like('LIKE'),
  pass('PASS'),
  superlike('SUPERLIKE');

  const SwipeActionInput(this.wire);
  final String wire;
}
