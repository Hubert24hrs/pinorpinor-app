import '../../core/constants/hookup_services.dart';
import '../../core/constants/primary_services.dart';
import '../../core/constants/services.dart';
import 'enums.dart';
import 'json.dart';
import 'live_sessions.dart';
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
    this.primaryService,
    this.hookupServices = const <String>[],
    this.liveSessions = MemberLiveSessions.empty,
    this.state,
    this.build,
    this.languages = const <String>[],
    this.rates = MemberRates.empty,
    this.presence,
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

  /// The one thing this member is here for: a single id from
  /// `lib/core/constants/primary_services.dart`, or **null** for a member who
  /// registered before 2026-08-21 and has not chosen. Null renders no badge and
  /// must never be given a default — see [primaryServiceOption].
  final String? primaryService;

  /// The explicit list, from `lib/core/constants/hookup_services.dart`.
  ///
  /// Only meaningful when [offersHookup] holds. The server strips it from every
  /// payload where it does not (`withGatedHookupServices`), and
  /// [hookupServiceOptions] applies the same gate again on read — a client that
  /// renders an ungated list is a client that will eventually post one.
  final List<String> hookupServices;

  /// Per-minute prices in **credits**, not money. See
  /// `lib/core/constants/live_sessions.dart`.
  final MemberLiveSessions liveSessions;

  /// Subdivision within the country (a Nigerian state, a UK nation...).
  final String? state;

  /// Body type, from the website's `BUILD_OPTIONS`.
  final String? build;

  final List<String> languages;

  /// What the member charges. Check [MemberRates.isVisible] before rendering —
  /// the member can switch the whole block off.
  final MemberRates rates;

  /// A coarse activity bucket. Never a timestamp — see [Presence].
  ///
  /// **Null means the member switched presence off**, which is not the same as
  /// [Presence.away]: away is a claim about her, null is the absence of a claim.
  /// Render nothing at all for null rather than substituting a bucket.
  final Presence? presence;

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

  /// The catalogue entry for [primaryService], or null when unchosen.
  PrimaryServiceOption? get primaryServiceOption =>
      primaryServiceFor(primaryService);

  /// Whether this member's booking block and explicit list should render.
  bool get offersHookup => primaryService == kHookupId;

  /// The explicit list as catalogue entries — **empty unless [offersHookup]**.
  List<HookupServiceOption> get hookupServiceOptions => offersHookup
      ? hookupServicesForIds(hookupServices)
      : const <HookupServiceOption>[];

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

  /// "Ikeja, Lagos, Nigeria" where all are known, falling back to whichever
  /// parts exist.
  ///
  /// `location` is the backend's own pre-composed string and wins when present:
  /// it is rebuilt server-side on every city or state change, so preferring the
  /// parts would risk showing a stale combination.
  String? get placeLabel {
    if (location != null && location!.isNotEmpty) return location;
    final parts = <String>[
      if (city != null && city!.isNotEmpty) city!,
      if (state != null && state!.isNotEmpty) state!,
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
      primaryService: sanitizePrimaryService(profile['primaryService']),
      // Gated again on the way in. The server already does this, but the rule
      // is cheap to hold and the failure it guards against is a public profile
      // rendering an explicit list beside a "Chat Buddy" badge.
      hookupServices: sanitizeHookupServices(
        asStringList(profile['hookupServices']),
        // Compared to the id directly rather than through offersHookup(): this
        // is a factory, and the same name is an instance getter below.
        offersHookup: asStringOrNull(profile['primaryService']) == kHookupId,
      ),
      liveSessions: MemberLiveSessions.fromProfileJson(profile),
      state: asStringOrNull(profile['state']),
      build: asStringOrNull(profile['build']),
      languages: asStringList(profile['languages']),
      rates: MemberRates.fromProfileJson(profile),
      // Presence sits on the user, not the dating profile: it is a bucket of
      // `users.lastSeenAt`, which the server never sends raw. Parsed
      // null-preserving, because a null here is the member's own choice.
      presence: Presence.parseOrNull(json['presence']),
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
    // Three endpoints, three names for the same collection: `/api/ladies`
    // calls it `ladies`, `/api/public/profiles` calls it `profiles`, and
    // `/api/public/online` calls it `members`. All are read so one page type
    // covers every surface.
    final rows = json.containsKey('profiles')
        ? json['profiles']
        : json.containsKey('ladies')
        ? json['ladies']
        : json['members'];

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
