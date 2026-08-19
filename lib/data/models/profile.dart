import '../../core/constants/services.dart';
import 'enums.dart';
import 'json.dart';
import 'media_item.dart';
import 'presence.dart';
import 'rates.dart';

/// A profile as seen by someone else.
///
/// Assembled from three response shapes that differ only in how much they carry:
/// `/api/public/profiles` (list), `/api/public/profiles/[username]` (detail) and
/// `/api/ladies` (home rail, which renames `datingProfile` to `ladyProfile`).
/// Age is always computed server-side — `birthDate` never leaves the backend.
class ProfileSummary {
  const ProfileSummary({
    required this.id,
    required this.username,
    required this.displayName,
    this.age,
    this.verificationStatus = VerificationStatus.none,
    this.tagline,
    this.bio,
    this.city,
    this.country,
    this.countryCode,
    this.location,
    this.height,
    this.ethnicity,
    this.relationshipIntent,
    this.dateTypes = const <String>[],
    this.services = const <String>[],
    this.state,
    this.build,
    this.languages = const <String>[],
    this.rates = MemberRates.empty,
    this.presence = Presence.away,
    this.viewCount = 0,
    this.prompts = const <String, String>{},
    this.isAvailableToday = false,
    this.isRedHot = false,
    this.isFeatured = false,
    this.isLiveNow = false,
    this.media = const <MediaItem>[],
    this.createdAt,
  });

  final String id;
  final String username;
  final String displayName;
  final int? age;
  final VerificationStatus verificationStatus;

  final String? tagline;
  final String? bio;
  final String? city;
  final String? country;
  final String? countryCode;
  final String? location;
  final String? height;
  final String? ethnicity;
  final RelationshipIntent? relationshipIntent;
  /// **Deprecated.** The pre-2026-08-13 "Preferred Date Activities", kept
  /// because existing rows hold real choices. Nothing writes to it any more —
  /// [services] replaced it. Read-only here for the same reason.
  final List<String> dateTypes;

  /// Catalogue ids from `lib/core/constants/services.dart` — never labels.
  /// Render with [serviceOptions] rather than printing these raw.
  final List<String> services;

  /// Subdivision within the country (a Nigerian state, a UK nation...).
  final String? state;

  /// Body type, from the website's `BUILD_OPTIONS`.
  final String? build;

  final List<String> languages;

  /// What the member charges. Check [MemberRates.isVisible] before rendering —
  /// the member can switch the whole block off.
  final MemberRates rates;

  /// A coarse activity bucket. Never a timestamp — see [Presence].
  final Presence presence;

  final int viewCount;

  final Map<String, String> prompts;

  final bool isAvailableToday;

  /// Cache of an active paid boost — `isRedHot` on `dating_profiles`.
  final bool isRedHot;

  /// New profiles surface for their first 24 hours.
  final bool isFeatured;

  final bool isLiveNow;
  final List<MediaItem> media;
  final DateTime? createdAt;

  bool get isVerified => verificationStatus.isVerified;

  /// The member's services as catalogue entries, in catalogue order. Retired
  /// entries are included so a profile keeps rendering everything it holds.
  List<ServiceOption> get serviceOptions => servicesForIds(services);

  List<MediaItem> get photos =>
      media.where((m) => !m.isVideo && m.hasUrl).toList(growable: false);

  List<MediaItem> get videos =>
      media.where((m) => m.isVideo && m.hasUrl).toList(growable: false);

  MediaItem? get primaryPhoto {
    for (final item in media) {
      if (item.mediaType == MediaType.profilePhoto && item.hasUrl) return item;
    }
    for (final item in media) {
      if (!item.isVideo && item.hasUrl) return item;
    }
    return null;
  }

  /// "Lagos, Nigeria" where both are known, falling back to whichever exists.
  String? get placeLabel {
    if (location != null && location!.isNotEmpty) return location;
    final parts = <String>[
      if (city != null && city!.isNotEmpty) city!,
      if (country != null && country!.isNotEmpty) country!,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  factory ProfileSummary.fromJson(Map<String, dynamic> json) {
    // `/api/ladies` renames the relation; everything else keeps Prisma's name.
    final profile = json.containsKey('datingProfile')
        ? asMap(json['datingProfile'])
        : asMap(json['ladyProfile']);

    return ProfileSummary(
      id: asString(json['id']),
      username: asString(json['username']),
      displayName: asString(
        json['displayName'],
        fallback: asString(json['username']),
      ),
      age: asIntOrNull(json['age']),
      verificationStatus: VerificationStatus.parse(json['verificationStatus']),
      tagline: asStringOrNull(profile['tagline']),
      bio: asStringOrNull(profile['bio']),
      city: asStringOrNull(profile['city']),
      country: asStringOrNull(profile['country']),
      countryCode: asStringOrNull(profile['countryCode']),
      location: asStringOrNull(profile['location']),
      height: asStringOrNull(profile['height']),
      ethnicity: asStringOrNull(profile['ethnicity']),
      relationshipIntent: RelationshipIntent.parse(
        profile['relationshipIntent'],
      ),
      dateTypes: asStringList(profile['dateTypes']),
      services: asStringList(profile['services']),
      state: asStringOrNull(profile['state']),
      build: asStringOrNull(profile['build']),
      languages: asStringList(profile['languages']),
      rates: MemberRates.fromProfileJson(profile),
      // Presence sits on the user, not the dating profile: it is a bucket of
      // `users.lastSeenAt`, which the server never sends raw.
      presence: Presence.parse(json['presence']),
      viewCount: asIntOrNull(profile['viewCount']) ?? 0,
      prompts: _readPrompts(profile['prompts']),
      isAvailableToday: asBool(profile['isAvailableToday']),
      isRedHot: asBool(profile['isRedHot']),
      isFeatured: asBool(profile['isFeatured']),
      isLiveNow: asBool(profile['isLiveNow']),
      media: MediaItem.listFrom(json['media']),
      createdAt: asDateOrNull(json['createdAt']),
    );
  }

  static Map<String, String> _readPrompts(Object? value) {
    final map = asMap(value);
    if (map.isEmpty) return const <String, String>{};
    return map.map((key, value) => MapEntry(key, asString(value)));
  }

  static List<ProfileSummary> listFrom(Object? value) =>
      asMapList(value).map(ProfileSummary.fromJson).toList(growable: false);
}

/// A page of profiles plus the country the backend resolved for the caller.
///
/// `scope.pinned` is true for signed-in members: discovery never crosses
/// borders for them, and the request's `country` parameter is ignored. The UI
/// uses it to decide whether to offer a country picker at all.
class ProfilePage {
  const ProfilePage({
    required this.profiles,
    required this.page,
    required this.totalPages,
    required this.total,
    this.countryCode,
    this.countryName,
    this.pinned = false,
  });

  final List<ProfileSummary> profiles;
  final int page;
  final int totalPages;
  final int total;
  final String? countryCode;
  final String? countryName;
  final bool pinned;

  bool get hasMore => page < totalPages;

  static const empty = ProfilePage(
    profiles: <ProfileSummary>[],
    page: 1,
    totalPages: 0,
    total: 0,
  );

  factory ProfilePage.fromJson(Map<String, dynamic> json) {
    final pagination = asMap(json['pagination']);
    final scope = asMap(json['scope']);
    // `/api/ladies` calls the collection `ladies`; `/api/public/profiles` calls
    // it `profiles`. Both are read so one page type covers each surface.
    final rows = json.containsKey('profiles')
        ? json['profiles']
        : json['ladies'];

    return ProfilePage(
      profiles: ProfileSummary.listFrom(rows),
      page: asInt(pagination['page'], fallback: 1),
      totalPages: asInt(pagination['totalPages']),
      total: asInt(pagination['total']),
      countryCode: asStringOrNull(scope['countryCode']),
      countryName: asStringOrNull(scope['countryName']),
      pinned: asBool(scope['pinned']),
    );
  }

  ProfilePage merge(ProfilePage next) => ProfilePage(
    profiles: <ProfileSummary>[...profiles, ...next.profiles],
    page: next.page,
    totalPages: next.totalPages,
    total: next.total,
    countryCode: next.countryCode ?? countryCode,
    countryName: next.countryName ?? countryName,
    pinned: next.pinned,
  );
}
