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

      // Marketing and legal pages have no app equivalent; they stay on the web.
      case 'about':
      case 'safety':
      case 'privacy':
      case 'terms':
      case 'contact':
      case 'locations':
      case 'live':
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
