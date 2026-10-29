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

  /// Resetting a password with a WhatsApp code, which is the only
  /// recovery path an account created since 2026-08-14 has: no email
  /// address is collected, so there is nothing to send a link to.
  static const whatsappReset = '/reset-password/whatsapp';

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

  /// The swipe deck. Protected: `/api/discover` and `/api/swipe` both require a
  /// session, and a deck with nothing to swipe on would be a dead screen.
  static const swipe = '/swipe';

  static const editProfile = '/me/edit';
  static const manageMedia = '/me/media';
  static const verification = '/verify';
  static const credits = '/credits';
  static const topUp = '/credits/top-up';
  static const matches = '/matches';
  static const favorites = '/favorites';
  static const live = '/live';
  static const videos = '/videos';
  static const locations = '/locations';

  /// The website's "Get the App" page. Native here, because the website's
  /// version exists to tell a browser visitor there is nothing to download —
  /// which is not the question a member holding the app is asking.
  static const getTheApp = '/app';
  static const section = '/section';

  // Settings
  static const settings = '/settings';
  static const settingsPreferences = '/settings/preferences';
  static const settingsBlocked = '/settings/blocked';
  static const settingsAccount = '/settings/account';
  static const settingsPassword = '/settings/password';
  static const support = '/support';

  /// The website's editorial and legal pages, now native.
  ///
  /// These were [NavKind.website] entries until today: tapping "Safety &
  /// Blacklist" left the app for a browser, which is the worst possible
  /// handover for the one page a member reads when something has gone wrong.
  /// The paths mirror the website's so an `https://pinorpinor.com/safety` link
  /// opens the screen.
  static const about = '/about';
  static const faq = '/faq';
  static const safety = '/safety';
  static const privacy = '/privacy';
  static const terms = '/terms';

  /// Standalone abuse reporting, mirroring the website's `/report-abuse`.
  ///
  /// Distinct from the report sheet on a profile: this one takes a username,
  /// so a member can report an account whose page they can no longer reach.
  static const reportAbuse = '/report-abuse';

  /// Paths that require a session. Checked in the router's redirect, and
  /// re-checked by the backend on every request these screens make — the client
  /// guard is convenience, not security.
  static const Set<String> protectedPrefixes = <String>{
    swipe,
    messages,
    notifications,
    account,
    conversation,
    editProfile,
    manageMedia,
    verification,
    credits,
    topUp,
    // Contact Us posts as the signed-in member: the identity comes from the
    // session, never the form, or anyone could file complaints as anyone else.
    support,
    // `/api/report` calls requireAuth() and records the reporter's id, so a
    // signed-out member would fill in a long account of what happened and
    // lose it to a 401. The screen asks for a sign-in before anything is
    // typed; this keeps a deep link from bypassing that.
    reportAbuse,
    matches,
    // `/api/favorites` requires a session. Without this the screen loads for a
    // signed-out visitor, the request 401s, and `ApiClient` reports that as an
    // invalidated session — so somebody who never signed in is told their
    // session expired instead of being asked to sign in. Reachable by deep
    // link, so it is not a theoretical path.
    favorites,
    settings,
  };

  /// Public counterparts, listed to make the omission deliberate rather than
  /// forgotten: `/live`, `/videos` and `/locations` are backed by
  /// `/api/public/*` endpoints that work signed out, exactly as browsing does.

  /// Paths a signed-in member has no reason to see.
  static const Set<String> authOnly = <String>{
    login,
    join,
    forgotPassword,
    resetPassword,
    whatsappReset,
  };

  static bool isProtected(String location) =>
      protectedPrefixes.any((prefix) => location.startsWith(prefix));

  static bool isAuthOnly(String location) =>
      authOnly.any((prefix) => location.startsWith(prefix));
}
