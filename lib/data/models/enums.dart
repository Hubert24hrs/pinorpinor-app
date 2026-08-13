/// Enum mirrors of `prisma/schema.prisma`.
///
/// The API sends these as the exact uppercase strings Prisma stores, so parsing
/// is a straight name match with a documented fallback for values a newer
/// backend might introduce — an unknown enum must never crash a screen.
library;

enum UserRole {
  man,
  woman,
  moderator,
  admin,
  superAdmin,
  unknown;

  static UserRole parse(Object? value) => switch (value) {
    'MAN' => UserRole.man,
    'WOMAN' => UserRole.woman,
    'MODERATOR' => UserRole.moderator,
    'ADMIN' => UserRole.admin,
    'SUPER_ADMIN' => UserRole.superAdmin,
    _ => UserRole.unknown,
  };

  String get wire => switch (this) {
    UserRole.man => 'MAN',
    UserRole.woman => 'WOMAN',
    UserRole.moderator => 'MODERATOR',
    UserRole.admin => 'ADMIN',
    UserRole.superAdmin => 'SUPER_ADMIN',
    UserRole.unknown => 'MAN',
  };

  /// Mirrors `ADMIN_ROLES` in `src/lib/api-helpers.ts`.
  bool get isStaff =>
      this == UserRole.moderator ||
      this == UserRole.admin ||
      this == UserRole.superAdmin;

  /// Only lady accounts may upload media — see `/api/upload/presigned-url`.
  bool get canUploadMedia => this == UserRole.woman;
}

enum Gender {
  man,
  woman;

  static Gender? parse(Object? value) => switch (value) {
    'MAN' => Gender.man,
    'WOMAN' => Gender.woman,
    _ => null,
  };

  String get wire => this == Gender.woman ? 'WOMAN' : 'MAN';
  String get label => this == Gender.woman ? 'Woman' : 'Man';
}

enum InterestedIn {
  men,
  women,
  both;

  static InterestedIn? parse(Object? value) => switch (value) {
    'MEN' => InterestedIn.men,
    'WOMEN' => InterestedIn.women,
    'BOTH' => InterestedIn.both,
    _ => null,
  };

  String get wire => switch (this) {
    InterestedIn.men => 'MEN',
    InterestedIn.women => 'WOMEN',
    InterestedIn.both => 'BOTH',
  };

  String get label => switch (this) {
    InterestedIn.men => 'Men',
    InterestedIn.women => 'Women',
    InterestedIn.both => 'Everyone',
  };

  /// `defaultInterestFor` in `src/lib/visibility.ts`: men see women first,
  /// women see everyone.
  static InterestedIn defaultFor(Gender? gender) =>
      gender == Gender.woman ? InterestedIn.both : InterestedIn.women;
}

enum VerificationStatus {
  none,
  pending,
  verified,
  rejected;

  static VerificationStatus parse(Object? value) => switch (value) {
    'PENDING' => VerificationStatus.pending,
    'VERIFIED' => VerificationStatus.verified,
    'REJECTED' => VerificationStatus.rejected,
    _ => VerificationStatus.none,
  };

  bool get isVerified => this == VerificationStatus.verified;

  String get label => switch (this) {
    VerificationStatus.none => 'Not verified',
    VerificationStatus.pending => 'Verification pending',
    VerificationStatus.verified => 'Verified',
    VerificationStatus.rejected => 'Verification rejected',
  };
}

enum VerificationChannel {
  email,
  phone;

  String get wire => this == VerificationChannel.email ? 'EMAIL' : 'PHONE';
  String get label => this == VerificationChannel.email ? 'Email' : 'Phone';
}

enum MediaType {
  profilePhoto,
  galleryPhoto,
  video,
  verificationSelfie,
  unknown;

  static MediaType parse(Object? value) => switch (value) {
    'PROFILE_PHOTO' => MediaType.profilePhoto,
    'GALLERY_PHOTO' => MediaType.galleryPhoto,
    'VIDEO' => MediaType.video,
    'VERIFICATION_SELFIE' => MediaType.verificationSelfie,
    _ => MediaType.unknown,
  };

  String get wire => switch (this) {
    MediaType.profilePhoto => 'PROFILE_PHOTO',
    MediaType.galleryPhoto => 'GALLERY_PHOTO',
    MediaType.video => 'VIDEO',
    MediaType.verificationSelfie => 'VERIFICATION_SELFIE',
    MediaType.unknown => 'GALLERY_PHOTO',
  };

  bool get isVideo => this == MediaType.video;
}

enum RelationshipIntent {
  casual,
  serious,
  friends,
  open;

  static RelationshipIntent? parse(Object? value) => switch (value) {
    'CASUAL' => RelationshipIntent.casual,
    'SERIOUS' => RelationshipIntent.serious,
    'FRIENDS' => RelationshipIntent.friends,
    'OPEN' => RelationshipIntent.open,
    _ => null,
  };

  String get wire => switch (this) {
    RelationshipIntent.casual => 'CASUAL',
    RelationshipIntent.serious => 'SERIOUS',
    RelationshipIntent.friends => 'FRIENDS',
    RelationshipIntent.open => 'OPEN',
  };

  String get label => switch (this) {
    RelationshipIntent.casual => 'Something casual',
    RelationshipIntent.serious => 'Something serious',
    RelationshipIntent.friends => 'New friends',
    RelationshipIntent.open => 'Open to anything',
  };
}

enum SwipeAction {
  like,
  pass,
  superlike;

  String get wire => switch (this) {
    SwipeAction.like => 'LIKE',
    SwipeAction.pass => 'PASS',
    SwipeAction.superlike => 'SUPERLIKE',
  };
}

enum ContactRequestStatus {
  pending,
  accepted,
  declined,
  none;

  static ContactRequestStatus parse(Object? value) => switch (value) {
    'PENDING' => ContactRequestStatus.pending,
    'ACCEPTED' => ContactRequestStatus.accepted,
    'DECLINED' => ContactRequestStatus.declined,
    _ => ContactRequestStatus.none,
  };

  String get wire => switch (this) {
    ContactRequestStatus.pending => 'PENDING',
    ContactRequestStatus.accepted => 'ACCEPTED',
    ContactRequestStatus.declined => 'DECLINED',
    ContactRequestStatus.none => 'PENDING',
  };
}

enum NotificationType {
  match,
  message,
  dateProposal,
  dateAccepted,
  dateDeclined,
  likeReceived,
  profileVerified,
  reportResolved,
  contactRequest,
  contactAccepted,
  contactDeclined,
  system;

  static NotificationType parse(Object? value) => switch (value) {
    'MATCH' => NotificationType.match,
    'MESSAGE' => NotificationType.message,
    'DATE_PROPOSAL' => NotificationType.dateProposal,
    'DATE_ACCEPTED' => NotificationType.dateAccepted,
    'DATE_DECLINED' => NotificationType.dateDeclined,
    'LIKE_RECEIVED' => NotificationType.likeReceived,
    'PROFILE_VERIFIED' => NotificationType.profileVerified,
    'REPORT_RESOLVED' => NotificationType.reportResolved,
    'CONTACT_REQUEST' => NotificationType.contactRequest,
    'CONTACT_ACCEPTED' => NotificationType.contactAccepted,
    'CONTACT_DECLINED' => NotificationType.contactDeclined,
    _ => NotificationType.system,
  };
}

enum MessageStatus {
  sent,
  delivered,
  read;

  static MessageStatus parse(Object? value) => switch (value) {
    'DELIVERED' => MessageStatus.delivered,
    'READ' => MessageStatus.read,
    _ => MessageStatus.sent,
  };
}
