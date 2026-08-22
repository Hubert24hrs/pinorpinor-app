import '../config/app_config.dart';
import 'app_routes.dart';

/// Translates an inbound link into an in-app path.
///
/// Two forms are accepted:
///   * `pinorpinor://profile/zainab` — the custom scheme,
///   * `https://pinorpinor.com/zainab` — App Links / Universal Links, so a
///     shared profile link opens the app rather than the browser.
///
/// **Untrusted input.** A link can come from anywhere — a message, a QR code, a
/// malicious page — so this never returns anything but a known in-app path. It
/// cannot produce an external URL, cannot carry a session token, and cannot
/// trigger an action: every destination is a screen that then does its own
/// authenticated fetch. A link to a protected screen is still subject to the
/// router's auth redirect.
class DeepLinks {
  const DeepLinks._();

  /// Returns the in-app location for [uri], or null when the link is not one
  /// the app claims. Null must be ignored, never opened.
  static String? resolve(Uri uri) {
    final isCustomScheme = uri.scheme == AppConfig.deepLinkScheme;
    final isWebLink =
        (uri.scheme == 'https') &&
        (uri.host == AppConfig.deepLinkHost ||
            uri.host == 'www.${AppConfig.deepLinkHost}');

    if (!isCustomScheme && !isWebLink) return null;

    // `pinorpinor://profile/zainab` puts "profile" in the host, not the path.
    final segments = <String>[
      if (isCustomScheme && uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments.where((segment) => segment.isNotEmpty),
    ];

    if (segments.isEmpty) return AppRoutes.home;

    final first = segments.first.toLowerCase();
    final second = segments.length > 1 ? segments[1] : null;

    switch (first) {
      case 'profile':
        if (second == null) return AppRoutes.discover;
        return AppRoutes.profileFor(_safeSegment(second));

      case 'conversation':
      case 'messages':
        if (second == null) return AppRoutes.messages;
        return AppRoutes.conversationFor(_safeSegment(second));

      case 'notifications':
        return AppRoutes.notifications;

      case 'reset-password':
      case 'reset_password':
        final token = uri.queryParameters['token'];
        if (token == null || token.isEmpty) return AppRoutes.forgotPassword;
        // The token is passed straight through to the reset screen, which
        // submits it to the backend. It is single-use, hashed at rest and
        // expires in an hour; the app never stores it.
        return '${AppRoutes.resetPassword}?token=${Uri.encodeQueryComponent(token)}';

      case 'verify':
      case 'verification':
        return AppRoutes.verification;

      case 'credits':
        return AppRoutes.credits;

      case 'settings':
        return AppRoutes.settings;

      case 'discover':
      case 'browse':
      case 'women':
      case 'ladies':
        return AppRoutes.discover;

      case 'login':
        return AppRoutes.login;

      case 'join':
      case 'register':
      case 'signup':
        return AppRoutes.join;

      case 'forgot-password':
      case 'forgot_password':
        return AppRoutes.forgotPassword;

      // The website calls the member's own hub /dashboard; the app calls it
      // /me. Without this a member tapping their own dashboard link fell
      // through to the username branch below and got a profile lookup for
      // somebody called "dashboard".
      case 'dashboard':
        return AppRoutes.account;

      case 'live':
        return AppRoutes.live;

      case 'videos':
        return AppRoutes.videos;

      case 'locations':
        return AppRoutes.locations;

      // Every live-session option on the website links to /app, so this is a
      // link members will actually receive.
      case 'app':
        return AppRoutes.getTheApp;

      case 'favorites':
      case 'saved':
        return AppRoutes.favorites;

      case 'matches':
        return AppRoutes.matches;

      // Sections the website itself has not built, plus its marketing and legal
      // pages. These stay on the web.
      //
      // **Listing them explicitly is load-bearing**, not tidiness. Every one of
      // these is a valid username shape (`^[a-z0-9_]{3,20}$`), so without a case
      // here they fall through to the default branch and open a profile lookup
      // for a member who does not exist — pinorpinor.com/faq would land on
      // "profile not found". Any new website section needs adding here on the
      // same day, and `deep_links_test.dart` fails if one is missed.
      case 'about':
      case 'adverts':
      case 'events':
      case 'exclusive':
      case 'faq':
      case 'feeds':
      case 'maintenance':
      case 'privacy':
      case 'reviews':
      case 'rooms':
      case 'safety':
      case 'contact':
      case 'terms':
      case 'testimonials':
        return null;

      default:
        // The website serves bare `/<username>` as a profile. Only accept a
        // segment that could actually be a username — anything else is not a
        // link this app claims.
        if (_looksLikeUsername(first)) return AppRoutes.profileFor(first);
        return null;
    }
  }

  /// Usernames are `^[a-z0-9_]{3,20}$` at the database level.
  static bool _looksLikeUsername(String value) =>
      RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(value);

  /// Percent-encodes anything that could alter the resulting path shape.
  static String _safeSegment(String value) =>
      Uri.encodeComponent(value.trim().toLowerCase());
}
