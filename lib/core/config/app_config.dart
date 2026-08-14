/// Build-time configuration.
///
/// Everything here is public information: the origin the app talks to and a few
/// tuning constants. There are deliberately **no keys of any kind** in the
/// Flutter client — see `docs/SECURITY.md`.
///
/// The Pinorpinor backend keeps its Postgres data API closed (`anon` and
/// `authenticated` hold no grants) and its media bucket private, so a mobile
/// client has nothing it could usefully hold. Every privileged operation runs
/// behind the Next.js API on the origin below.
///
/// Override the origin at build time:
///   flutter build appbundle --dart-define=PINORPINOR_API_ORIGIN=https://staging.pinorpinor.com
library;

class AppConfig {
  const AppConfig._();

  /// Canonical production origin. `www` 308-redirects to the apex, so the apex
  /// is used directly — a redirect would drop the session cookie on POSTs.
  static const String apiOrigin = String.fromEnvironment(
    'PINORPINOR_API_ORIGIN',
    defaultValue: 'https://pinorpinor.com',
  );

  /// Custom scheme handled by the app for deep links (`pinorpinor://profile/x`).
  static const String deepLinkScheme = 'pinorpinor';

  /// Host used for HTTPS App Links / Universal Links.
  static const String deepLinkHost = 'pinorpinor.com';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// The API signs media URLs for one hour. Cached images are given a shorter
  /// life so a revoked photo stops rendering well before the signature dies.
  static const Duration mediaCacheTtl = Duration(minutes: 45);

  /// How often the foreground notification poller asks for unread counts.
  /// See `docs/DEPLOYMENT.md` — server-pushed FCM needs a backend change.
  static const Duration notificationPollInterval = Duration(seconds: 45);

  /// Mirrors `src/lib/storage.ts` on the website. The server re-validates all of
  /// these; the client copy exists to fail fast with a friendly message.
  static const int maxImageBytes = 15 * 1024 * 1024;
  static const int maxVideoBytes = 50 * 1024 * 1024;
  static const int maxProfilePhotos = 6;
  static const int maxGalleryPhotos = 30;
  static const int maxVideos = 10;

  static const List<String> allowedImageMimeTypes = <String>[
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'image/heic',
  ];

  static const List<String> allowedVideoMimeTypes = <String>[
    'video/mp4',
    'video/mov',
    'video/webm',
    'video/quicktime',
  ];

  /// Public legal pages, reused by Settings, the age gate and the store
  /// listings.
  ///
  /// `const` rather than getters so they can be used in const constructors —
  /// the age gate's legal links are const widgets, and a getter would force the
  /// whole subtree to rebuild on every frame it appears in.
  static const String privacyPolicyUrl = '$apiOrigin/privacy';
  static const String termsUrl = '$apiOrigin/terms';
  static const String safetyUrl = '$apiOrigin/safety';
  static const String contactUrl = '$apiOrigin/contact';
  static const String aboutUrl = '$apiOrigin/about';
}
