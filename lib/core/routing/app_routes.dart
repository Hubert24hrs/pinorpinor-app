/// Every route path in one place, so deep links, redirects and navigation calls
/// cannot drift apart.
///
/// Paths mirror the website's URLs wherever one exists, which is what lets an
/// `https://pinorpinor.com/...` link open the equivalent screen in the app.
library;

class AppRoutes {
  const AppRoutes._();

  static const splash = '/';

  // Auth
  static const login = '/login';
  static const join = '/join';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';

  // Shell tabs
  static const home = '/home';
  static const discover = '/discover';
  static const messages = '/messages';
  static const notifications = '/notifications';
  static const account = '/me';

  // Detail routes
  static const profile = '/profile';
  static String profileFor(String username) => '$profile/$username';

  static const conversation = '/conversation';
  static String conversationFor(String id) => '$conversation/$id';

  static const editProfile = '/me/edit';
  static const manageMedia = '/me/media';
  static const verification = '/verify';
  static const credits = '/credits';
  static const contactRequests = '/contact-requests';
  static const matches = '/matches';

  // Settings
  static const settings = '/settings';
  static const settingsPreferences = '/settings/preferences';
  static const settingsBlocked = '/settings/blocked';
  static const settingsAccount = '/settings/account';

  /// Paths that require a session. Checked in the router's redirect, and
  /// re-checked by the backend on every request these screens make — the client
  /// guard is convenience, not security.
  static const Set<String> protectedPrefixes = <String>{
    messages,
    notifications,
    account,
    conversation,
    editProfile,
    manageMedia,
    verification,
    credits,
    contactRequests,
    matches,
    settings,
  };

  /// Paths a signed-in member has no reason to see.
  static const Set<String> authOnly = <String>{
    login,
    join,
    forgotPassword,
    resetPassword,
  };

  static bool isProtected(String location) =>
      protectedPrefixes.any((prefix) => location.startsWith(prefix));

  static bool isAuthOnly(String location) =>
      authOnly.any((prefix) => location.startsWith(prefix));
}
