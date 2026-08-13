import 'json.dart';

/// The `settings` row plus the caller's block list, from `GET /api/settings`.
class MemberSettings {
  const MemberSettings({
    this.notifyOnMatch = true,
    this.notifyOnMessage = true,
    this.notifyOnDateProposal = true,
    this.notifyOnLike = false,
    this.showInDiscovery = true,
    this.showDistance = true,
    this.maxDistanceKm = 50,
    this.ageRangeMin = 18,
    this.ageRangeMax = 60,
  });

  final bool notifyOnMatch;
  final bool notifyOnMessage;
  final bool notifyOnDateProposal;
  final bool notifyOnLike;
  final bool showInDiscovery;
  final bool showDistance;
  final int maxDistanceKm;

  /// The floor is 18 everywhere — the backend clamps it regardless of what the
  /// client sends, and so does this model.
  final int ageRangeMin;

  final int ageRangeMax;

  static const defaults = MemberSettings();

  factory MemberSettings.fromJson(Map<String, dynamic> json) {
    final settings = json.containsKey('settings')
        ? asMap(json['settings'])
        : json;
    return MemberSettings(
      notifyOnMatch: asBool(settings['notifyOnMatch'], fallback: true),
      notifyOnMessage: asBool(settings['notifyOnMessage'], fallback: true),
      notifyOnDateProposal: asBool(
        settings['notifyOnDateProposal'],
        fallback: true,
      ),
      notifyOnLike: asBool(settings['notifyOnLike']),
      showInDiscovery: asBool(settings['showInDiscovery'], fallback: true),
      showDistance: asBool(settings['showDistance'], fallback: true),
      maxDistanceKm: asInt(settings['maxDistanceKm'], fallback: 50),
      ageRangeMin: asInt(settings['ageRangeMin'], fallback: 18).clamp(18, 100),
      ageRangeMax: asInt(settings['ageRangeMax'], fallback: 60).clamp(18, 100),
    );
  }

  MemberSettings copyWith({
    bool? notifyOnMatch,
    bool? notifyOnMessage,
    bool? notifyOnDateProposal,
    bool? notifyOnLike,
    bool? showInDiscovery,
    bool? showDistance,
    int? maxDistanceKm,
    int? ageRangeMin,
    int? ageRangeMax,
  }) => MemberSettings(
    notifyOnMatch: notifyOnMatch ?? this.notifyOnMatch,
    notifyOnMessage: notifyOnMessage ?? this.notifyOnMessage,
    notifyOnDateProposal: notifyOnDateProposal ?? this.notifyOnDateProposal,
    notifyOnLike: notifyOnLike ?? this.notifyOnLike,
    showInDiscovery: showInDiscovery ?? this.showInDiscovery,
    showDistance: showDistance ?? this.showDistance,
    maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
    ageRangeMin: ageRangeMin ?? this.ageRangeMin,
    ageRangeMax: ageRangeMax ?? this.ageRangeMax,
  );

  Map<String, dynamic> toPatch() => <String, dynamic>{
    'notifyOnMatch': notifyOnMatch,
    'notifyOnMessage': notifyOnMessage,
    'notifyOnDateProposal': notifyOnDateProposal,
    'notifyOnLike': notifyOnLike,
    'showInDiscovery': showInDiscovery,
    'showDistance': showDistance,
    'maxDistanceKm': maxDistanceKm,
    'ageRangeMin': ageRangeMin,
    'ageRangeMax': ageRangeMax,
  };
}

class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.username,
    required this.displayName,
  });

  final String id;
  final String username;
  final String displayName;

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
    id: asString(json['id']),
    username: asString(json['username']),
    displayName: asString(
      json['displayName'],
      fallback: asString(json['username']),
    ),
  );

  static List<BlockedUser> listFrom(Object? value) =>
      asMapList(value).map(BlockedUser.fromJson).toList(growable: false);
}

class SettingsBundle {
  const SettingsBundle({required this.settings, required this.blockedUsers});

  final MemberSettings settings;
  final List<BlockedUser> blockedUsers;

  static const empty = SettingsBundle(
    settings: MemberSettings.defaults,
    blockedUsers: <BlockedUser>[],
  );

  factory SettingsBundle.fromJson(Map<String, dynamic> json) => SettingsBundle(
    settings: MemberSettings.fromJson(json),
    blockedUsers: BlockedUser.listFrom(json['blockedUsers']),
  );
}

/// A city with the number of public profiles in it — `GET /api/public/locations`.
class LocationCount {
  const LocationCount({
    required this.city,
    required this.count,
    this.highlight,
  });

  final String city;
  final int count;
  final String? highlight;

  factory LocationCount.fromJson(Map<String, dynamic> json) => LocationCount(
    city: asString(json['city']),
    count: asInt(json['count']),
    highlight: asStringOrNull(json['highlight']),
  );

  static List<LocationCount> listFrom(Object? value) =>
      asMapList(value).map(LocationCount.fromJson).toList(growable: false);
}

/// `GET /api/spotlight` — one Face of the Day per country, plus a top rail.
class Spotlight {
  const Spotlight({
    this.faceOfTheDay,
    this.topProfiles = const <SpotlightProfile>[],
    this.countryCode,
    this.countryName,
  });

  final SpotlightProfile? faceOfTheDay;
  final List<SpotlightProfile> topProfiles;
  final String? countryCode;
  final String? countryName;

  static const empty = Spotlight();

  bool get isEmpty => faceOfTheDay == null && topProfiles.isEmpty;

  factory Spotlight.fromJson(Map<String, dynamic> json) {
    final scope = asMap(json['scope']);
    final face = asMap(json['faceOfTheDay']);
    return Spotlight(
      faceOfTheDay: face.isEmpty ? null : SpotlightProfile.fromJson(face),
      topProfiles: asMapList(
        json['topProfiles'],
      ).map(SpotlightProfile.fromJson).toList(growable: false),
      countryCode: asStringOrNull(scope['countryCode']),
      countryName: asStringOrNull(scope['countryName']),
    );
  }
}

class SpotlightProfile {
  const SpotlightProfile({
    required this.username,
    required this.displayName,
    this.tagline,
    this.city,
    this.imageUrl,
    this.isFeatured = false,
    this.isBoosted = false,
    this.since,
  });

  final String username;
  final String displayName;
  final String? tagline;
  final String? city;
  final String? imageUrl;
  final bool isFeatured;
  final bool isBoosted;
  final DateTime? since;

  factory SpotlightProfile.fromJson(Map<String, dynamic> json) =>
      SpotlightProfile(
        username: asString(json['username']),
        displayName: asString(
          json['displayName'],
          fallback: asString(json['username']),
        ),
        tagline: asStringOrNull(json['tagline']),
        city: asStringOrNull(json['city']),
        imageUrl: asStringOrNull(json['image']),
        isFeatured: asBool(json['isFeatured']),
        isBoosted: asBool(json['isBoosted']),
        since: asDateOrNull(json['since']),
      );
}
