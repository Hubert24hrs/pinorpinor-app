import '../../core/constants/primary_services.dart';
import '../../core/constants/service_features.dart';
import 'enums.dart';
import 'json.dart';
import 'live_sessions.dart';
import 'media_item.dart';
import 'rates.dart';

/// The signed-in member's own account, from `GET /api/profile`.
///
/// Unlike [ProfileSummary] this carries private fields the owner is allowed to
/// see — email, phone-verification flags, discovery switches — and includes
/// media still awaiting moderation, flagged with `isApproved: false`.
class Account {
  const Account({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    required this.role,
    this.gender,
    this.interestedIn,
    this.verificationStatus = VerificationStatus.none,
    this.emailVerifiedAt,
    this.phone,
    this.phoneVerifiedAt,
    this.createdAt,
    this.profile = const DatingProfile(),
    this.media = const <MediaItem>[],
  });

  final String id;
  final String email;
  final String username;
  final String displayName;
  final UserRole role;
  final Gender? gender;
  final InterestedIn? interestedIn;
  final VerificationStatus verificationStatus;
  final DateTime? emailVerifiedAt;

  /// The member's own number. Never another member's — those are resolved
  /// server-side by the WhatsApp redirect and never sent to a client.
  final String? phone;

  final DateTime? phoneVerifiedAt;
  final DateTime? createdAt;
  final DatingProfile profile;
  final List<MediaItem> media;

  bool get emailVerified => emailVerifiedAt != null;
  bool get phoneVerified => phoneVerifiedAt != null;
  bool get isVerified => verificationStatus.isVerified;
  bool get canUploadMedia => role.canUploadMedia;

  /// Women must clear email **and** phone; men only email. Mirrors the rule in
  /// `/api/auth/verify/confirm`.
  bool get requiresPhoneVerification => gender == Gender.woman;

  bool get fullyVerified =>
      emailVerified && (!requiresPhoneVerification || phoneVerified);

  InterestedIn get effectiveInterestedIn =>
      interestedIn ?? InterestedIn.defaultFor(gender);

  List<MediaItem> get profilePhotos => media
      .where((m) => m.mediaType == MediaType.profilePhoto)
      .toList(growable: false);

  List<MediaItem> get galleryPhotos => media
      .where((m) => m.mediaType == MediaType.galleryPhoto)
      .toList(growable: false);

  List<MediaItem> get videos => media
      .where((m) => m.mediaType == MediaType.video)
      .toList(growable: false);

  MediaItem? get avatar {
    for (final item in media) {
      if (item.mediaType == MediaType.profilePhoto &&
          item.isApproved &&
          item.hasUrl) {
        return item;
      }
    }
    return null;
  }

  bool get hasPendingMedia => media.any((m) => !m.isApproved);

  /// Whether this member appears in listings at all.
  ///
  /// Since 2026-08-24 every public read filters on an **approved**
  /// `PROFILE_PHOTO` (`HAS_PROFILE_PHOTO` server-side), so a member without one
  /// is not merely plain-looking in the grid — they are absent from it, from
  /// discovery, from their own city's count and from their own public profile,
  /// which 404s for everyone but themselves and staff.
  ///
  /// A gallery shot or a clip does not count: it must be a profile photo. The
  /// owner still sees their own profile, which is the point of that exception —
  /// somebody who has just registered has to be able to look at it and be told
  /// what is missing rather than get a 404 for an account they made a minute
  /// ago.
  bool get isListable => media.any(
    (MediaItem m) => m.mediaType == MediaType.profilePhoto && m.isApproved,
  );

  /// A rough completeness score for the dashboard nudge. Purely cosmetic — no
  /// access decision anywhere depends on it.
  double get completeness {
    final checks = <bool>[
      displayName.isNotEmpty,
      (profile.bio ?? '').trim().length >= 20,
      (profile.city ?? '').isNotEmpty,
      profile.countryCode != null,
      // Not "has any media": a gallery shot does not make anyone listable, and
      // completeness that says 100% while the member is invisible is worse than
      // no number at all.
      isListable,
      // The primary service replaced the deprecated dateTypes column here: it
      // is the one field a member must choose for their card to carry a badge.
      profile.primaryService != null,
      emailVerified,
      !requiresPhoneVerification || phoneVerified,
    ];
    final done = checks.where((c) => c).length;
    return done / checks.length;
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    final user = json.containsKey('user') ? asMap(json['user']) : json;
    return Account(
      id: asString(user['id']),
      email: asString(user['email']),
      username: asString(user['username']),
      displayName: asString(
        user['displayName'],
        fallback: asString(user['username']),
      ),
      role: UserRole.parse(user['role']),
      gender: Gender.parse(user['gender']),
      interestedIn: InterestedIn.parse(user['interestedIn']),
      verificationStatus: VerificationStatus.parse(user['verificationStatus']),
      emailVerifiedAt: asDateOrNull(user['emailVerified']),
      phone: asStringOrNull(user['phone']),
      phoneVerifiedAt: asDateOrNull(user['phoneVerified']),
      createdAt: asDateOrNull(user['createdAt']),
      profile: DatingProfile.fromJson(asMap(user['datingProfile'])),
      media: MediaItem.listFrom(user['media']),
    );
  }

  Account copyWith({
    String? displayName,
    InterestedIn? interestedIn,
    DatingProfile? profile,
    List<MediaItem>? media,
  }) => Account(
    id: id,
    email: email,
    username: username,
    displayName: displayName ?? this.displayName,
    role: role,
    gender: gender,
    interestedIn: interestedIn ?? this.interestedIn,
    verificationStatus: verificationStatus,
    emailVerifiedAt: emailVerifiedAt,
    phone: phone,
    phoneVerifiedAt: phoneVerifiedAt,
    createdAt: createdAt,
    profile: profile ?? this.profile,
    media: media ?? this.media,
  );
}

/// The editable half of a member's profile — the `dating_profiles` row.
///
/// `lat`/`lng` are absent by design: the API strips them before the payload
/// leaves the server, so there is nothing to model.
class DatingProfile {
  const DatingProfile({
    this.bio,
    this.tagline,
    this.height,
    this.ethnicity,
    this.city,
    this.country,
    this.countryCode,
    this.location,
    this.relationshipIntent,
    this.dateTypes = const <String>[],
    this.services = const <String>[],
    this.primaryService,
    this.birthYear,
    this.serviceFeatures = const <String>[],
    this.liveSessions = MemberLiveSessions.empty,
    this.state,
    this.build,
    this.languages = const <String>[],
    this.rates = MemberRates.empty,
    this.isAvailableToday = false,
    this.showOnline = true,
    this.isPublic = true,
    this.isDiscoverable = true,
    this.whatsappEnabled = true,
    this.isRedHot = false,
    this.isFeatured = false,
    this.boostTier = 0,
    this.boostExpiresAt,
    this.featuredUntil,
    this.viewCount = 0,
  });

  final String? bio;
  final String? tagline;
  final String? height;
  final String? ethnicity;
  final String? city;
  final String? country;
  final String? countryCode;
  final String? location;
  final RelationshipIntent? relationshipIntent;

  /// **Deprecated.** The pre-2026-08-13 "Preferred Date Activities". Read-only:
  /// `profileUpdateSchema` deliberately refuses it, so nothing can write it any
  /// more. Kept so a member who still has some sees them. [services] replaced it.
  final List<String> dateTypes;

  /// Catalogue ids from `lib/core/constants/services.dart`, never labels.
  final List<String> services;

  /// The member's one primary service, or null when they have never chosen —
  /// which is every account created before 2026-08-21. The editor must offer
  /// "not chosen" as a real state rather than preselecting an option, because
  /// saving a guess publishes a claim the member never made.
  final String? primaryService;

  /// The year the member typed, or null for an account that predates the
  /// question.
  ///
  /// **The owner's own value, and only theirs.** It is stripped from every
  /// public payload alongside `birthDate`, because publishing a precise year is
  /// worse than the derived age it replaces. Other members' profiles carry
  /// `age`, already resolved server-side.
  final int? birthYear;

  /// What the member offers under [primaryService].
  ///
  /// Renamed from `hookupServices` on 2026-08-22 and generalised to all six
  /// services. **Switching primary service clears the column** server-side: the
  /// ids belong to the old catalogue and mean nothing under the new one, so
  /// keeping them would leave a Relationship profile holding Hookup selections.
  final List<String> serviceFeatures;

  /// Per-minute prices in **credits**. Never money — see
  /// `lib/core/constants/live_sessions.dart`.
  final MemberLiveSessions liveSessions;

  /// Subdivision within the country. Validated server-side against that
  /// country's list where one exists, free text where it does not.
  final String? state;

  /// Body type, from the website's `BUILD_OPTIONS`.
  final String? build;

  final List<String> languages;

  /// The member's own rates, in minor units. See `lib/core/utils/money.dart`.
  final MemberRates rates;

  final bool isAvailableToday;

  /// The member's presence switch.
  ///
  /// False withholds her presence — she disappears from "Online now" and from
  /// the live strip — **without** hiding her profile, which `isDiscoverable`
  /// would. Before this existed, going dark meant going undiscoverable, and
  /// publishing "she is online right now" to anonymous visitors tells a stranger
  /// when she is awake and when she is alone.
  final bool showOnline;

  /// Whether the profile is listed publicly. Men's profiles are visible to
  /// signed-in members only, and that rule lives in `resolveVisibleGenders()`
  /// server-side — not in this flag.
  final bool isPublic;

  final bool isDiscoverable;

  /// Owner switch for the WhatsApp button on the public profile.
  final bool whatsappEnabled;

  final bool isRedHot;
  final bool isFeatured;
  final int boostTier;
  final DateTime? boostExpiresAt;
  final DateTime? featuredUntil;
  final int viewCount;

  /// Whether the hookup booking block applies to this profile. The editor
  /// renders the rates on this answer; the server re-derives it from the stored
  /// row on every write.
  ///
  /// The feature list is **not** gated on this any more — all six services have
  /// one — but the booking rates still are.
  bool get offersHookup => primaryService == kHookupId;

  /// The member's features as catalogue entries, in catalogue order.
  List<ServiceFeature> get serviceFeatureOptions =>
      serviceFeaturesForIds(primaryService, serviceFeatures);

  /// The catalogue entry for [primaryService], or null when unchosen.
  PrimaryServiceOption? get primaryServiceOption =>
      primaryServiceFor(primaryService);

  factory DatingProfile.fromJson(Map<String, dynamic> json) => DatingProfile(
    bio: asStringOrNull(json['bio']),
    tagline: asStringOrNull(json['tagline']),
    height: asStringOrNull(json['height']),
    ethnicity: asStringOrNull(json['ethnicity']),
    city: asStringOrNull(json['city']),
    country: asStringOrNull(json['country']),
    countryCode: asStringOrNull(json['countryCode']),
    location: asStringOrNull(json['location']),
    relationshipIntent: RelationshipIntent.parse(json['relationshipIntent']),
    dateTypes: asStringList(json['dateTypes']),
    services: asStringList(json['services']),
    primaryService: sanitizePrimaryService(json['primaryService']),
    birthYear: asIntOrNull(json['birthYear']),
    serviceFeatures: sanitizeServiceFeatures(
      asStringList(json['serviceFeatures']),
      primaryService: asStringOrNull(json['primaryService']),
    ),
    liveSessions: MemberLiveSessions.fromProfileJson(json),
    state: asStringOrNull(json['state']),
    build: asStringOrNull(json['build']),
    languages: asStringList(json['languages']),
    rates: MemberRates.fromProfileJson(json),
    isAvailableToday: asBool(json['isAvailableToday']),
    showOnline: asBool(json['showOnline'], fallback: true),
    isPublic: asBool(json['isPublic'], fallback: true),
    isDiscoverable: asBool(json['isDiscoverable'], fallback: true),
    whatsappEnabled: asBool(json['whatsappEnabled'], fallback: true),
    isRedHot: asBool(json['isRedHot']),
    isFeatured: asBool(json['isFeatured']),
    boostTier: asInt(json['boostTier']),
    boostExpiresAt: asDateOrNull(json['boostExpiresAt']),
    featuredUntil: asDateOrNull(json['featuredUntil']),
    viewCount: asInt(json['viewCount']),
  );
}
