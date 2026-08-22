import '../../core/constants/services.dart';
import '../../core/network/api_client.dart';
import '../models/messaging.dart';
import '../models/profile.dart';
import '../models/settings.dart';

/// How recently a member must have been active to be included.
enum ActivityFilter {
  any(null, 'Any time'),
  online('online', 'Online now'),
  thisWeek('week', 'Active this week');

  const ActivityFilter(this.wire, this.label);

  /// The `activity` query value, or null for no constraint.
  final String? wire;
  final String label;
}

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
    this.services = const <String>[],
    this.activity = ActivityFilter.any,
  });

  final String? city;
  final String? countryCode;
  final int ageMin;
  final int ageMax;
  final bool verifiedOnly;
  final bool availableTodayOnly;

  /// Catalogue ids. The backend matches on **overlap**, not containment — a
  /// profile offering any one of these is included, which is what a member
  /// selecting three things expects.
  final List<String> services;

  final ActivityFilter activity;

  static const none = DiscoveryFilters();

  bool get isDefault =>
      (city == null || city!.isEmpty) &&
      ageMin <= 18 &&
      ageMax >= 99 &&
      !verifiedOnly &&
      !availableTodayOnly &&
      services.isEmpty &&
      activity == ActivityFilter.any;

  /// How many filters are active, for the badge on the filter button.
  int get activeCount => active.length;

  /// The active filters, each with a label and the filters that result from
  /// dropping it.
  ///
  /// Lets the UI show one chip per active filter with its own clear button, so
  /// a member can see and undo a single narrowing without reopening the sheet.
  /// Age is one entry rather than two — "18–30" is the unit a person thinks in,
  /// and clearing half of it is not a thing anyone wants.
  List<ActiveFilter> get active => <ActiveFilter>[
    if (city != null && city!.isNotEmpty && city != 'ALL')
      ActiveFilter(label: city!, clear: () => copyWith(clearCity: true)),
    if (ageMin > 18 || ageMax < 99)
      ActiveFilter(
        label: '$ageMin–$ageMax years',
        clear: () => copyWith(ageMin: 18, ageMax: 99),
      ),
    if (verifiedOnly)
      ActiveFilter(
        label: 'Verified',
        clear: () => copyWith(verifiedOnly: false),
      ),
    if (availableTodayOnly)
      ActiveFilter(
        label: 'Available today',
        clear: () => copyWith(availableTodayOnly: false),
      ),
    if (activity != ActivityFilter.any)
      ActiveFilter(
        label: activity.label,
        clear: () => copyWith(activity: ActivityFilter.any),
      ),
    // One chip per service rather than one for all of them: a member who
    // picked four and wants to drop one should not have to clear the lot.
    for (final id in services)
      ActiveFilter(
        label: serviceLabel(id),
        clear: () => copyWith(
          services: <String>[
            for (final other in services)
              if (other != id) other,
          ],
        ),
      ),
  ];

  DiscoveryFilters copyWith({
    String? city,
    bool clearCity = false,
    String? countryCode,
    int? ageMin,
    int? ageMax,
    bool? verifiedOnly,
    bool? availableTodayOnly,
    List<String>? services,
    ActivityFilter? activity,
  }) => DiscoveryFilters(
    city: clearCity ? null : (city ?? this.city),
    countryCode: countryCode ?? this.countryCode,
    ageMin: ageMin ?? this.ageMin,
    ageMax: ageMax ?? this.ageMax,
    verifiedOnly: verifiedOnly ?? this.verifiedOnly,
    availableTodayOnly: availableTodayOnly ?? this.availableTodayOnly,
    services: services ?? this.services,
    activity: activity ?? this.activity,
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
    // Comma-separated, and sanitised first: the route splits on "," and drops
    // unknown ids, so sending a retired one would silently widen the result set
    // rather than narrowing it.
    if (services.isNotEmpty) 'services': sanitizeServiceIds(services).join(','),
    if (activity.wire != null) 'activity': activity.wire,
  };
}

/// One active filter, with the label to show and the way to drop it.
///
/// Carrying the removal as a closure keeps the "what does clearing this mean"
/// decision beside the "what is this called" decision, instead of splitting
/// them across a widget and a switch on a string key.
class ActiveFilter {
  const ActiveFilter({required this.label, required this.clear});

  final String label;

  /// The filters that result from removing this one.
  final DiscoveryFilters Function() clear;
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

  /// The home rail. Only returns profiles that have at
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

  /// Members who are online, or were recently.
  ///
  /// Backs the "Online now" surface. It replaced a page on the website that
  /// rendered invented streamers with fabricated viewer counts — there is no
  /// streaming backend here, so the honest version is who is actually present.
  ///
  /// [strictlyOnline] narrows to the five-minute window. The default widens to
  /// seven days so the section is not empty on a platform this young; every
  /// member carries their real [Presence] bucket either way, so nothing is
  /// presented as online that is not.
  Future<ProfilePage> online({
    bool strictlyOnline = false,
    String? countryCode,
    int page = 1,
    int limit = 24,
  }) async {
    final json = await _api.getJson(
      '/api/public/online',
      query: <String, dynamic>{
        'page': page,
        'limit': limit,
        if (strictlyOnline) 'strict': 'true',
        if (countryCode != null && countryCode.isNotEmpty)
          'country': countryCode,
      },
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
