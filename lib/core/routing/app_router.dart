import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/app_info/get_the_app_screen.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/join_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/password_screens.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/credits/credits_screen.dart';
import '../../features/discovery/discover_screen.dart';
import '../../features/discovery/swipe_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/discovery/live_screen.dart';
import '../../features/discovery/locations_screen.dart';
import '../../features/discovery/videos_screen.dart';
import '../../features/favorites/favorites_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/media/manage_media_screen.dart';
import '../../features/messaging/conversation_screen.dart';
import '../../features/messaging/matches_screen.dart';
import '../../features/messaging/messages_screen.dart';
import '../../features/notifications/contact_requests_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/profile/account_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/profile_detail_screen.dart';
import '../../features/settings/account_settings_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/verification/verification_screen.dart';
import 'app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Navigator key for the root stack, so deep links and the notification tap
/// handler can push without a `BuildContext`.
GlobalKey<NavigatorState> get rootNavigatorKey => _rootNavigatorKey;

final routerProvider = Provider<GoRouter>((ref) {
  // A plain notifier rather than watching the provider: rebuilding the router
  // on every auth change would tear down the whole navigation stack.
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: false,

    /// The only auth gate in the client. It is a convenience: every protected
    /// screen's data comes from an endpoint that checks the session itself, and
    /// `requireAuth()` re-reads the account on each call so a ban takes effect
    /// immediately regardless of what the app believes.
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      // Hold on the splash until the stored session has been checked.
      if (auth.isRestoring) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // Home is the landing screen either way: browsing is open to everyone,
      // and a signed-in member sees the same screen with more of it enabled.
      if (location == AppRoutes.splash) return AppRoutes.home;

      if (!auth.isSignedIn && AppRoutes.isProtected(location)) {
        final target = Uri.encodeComponent(state.uri.toString());
        return '${AppRoutes.login}?redirect=$target';
      }

      if (auth.isSignedIn && AppRoutes.isAuthOnly(location)) {
        // A signed-in member following a reset-password link is the one case
        // where an auth-only screen is still the right destination.
        if (location.startsWith(AppRoutes.resetPassword)) return null;
        return AppRoutes.home;
      }

      return null;
    },

    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) =>
            LoginScreen(redirectTo: state.uri.queryParameters['redirect']),
      ),
      GoRoute(
        path: AppRoutes.join,
        builder: (context, state) => const JoinScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) =>
            ResetPasswordScreen(token: state.uri.queryParameters['token']),
      ),

      // The five bottom-navigation branches. Each keeps its own stack, so
      // switching tabs does not lose a scroll position or an open profile.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.discover,
                builder: (context, state) => const DiscoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.messages,
                builder: (context, state) => const MessagesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.notifications,
                builder: (context, state) => const NotificationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.account,
                builder: (context, state) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),

      // Full-screen routes, pushed above the shell.
      GoRoute(
        path: '${AppRoutes.profile}/:username',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ProfileDetailScreen(
          username: state.pathParameters['username'] ?? '',
        ),
      ),
      GoRoute(
        path: '${AppRoutes.conversation}/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ConversationScreen(
          conversationId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.swipe,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SwipeScreen(),
      ),
      GoRoute(
        path: AppRoutes.matches,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MatchesScreen(),
      ),
      GoRoute(
        path: AppRoutes.favorites,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: AppRoutes.live,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LiveScreen(),
      ),
      GoRoute(
        path: AppRoutes.videos,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const VideosScreen(),
      ),
      GoRoute(
        path: AppRoutes.getTheApp,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GetTheAppScreen(),
      ),
      GoRoute(
        path: AppRoutes.locations,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LocationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.manageMedia,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ManageMediaScreen(),
      ),
      GoRoute(
        path: AppRoutes.verification,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const VerificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.credits,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreditsScreen(),
      ),
      GoRoute(
        path: AppRoutes.contactRequests,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ContactRequestsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'preferences',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const PreferencesScreen(),
          ),
          GoRoute(
            path: 'blocked',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const BlockedUsersScreen(),
          ),
          GoRoute(
            path: 'account',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const AccountSettingsScreen(),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) =>
        _RouteNotFound(location: state.uri.toString()),
  );
});

/// Bridges Riverpod's auth state to `GoRouter.refreshListenable`.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    _removeListener = ref.listen<AuthState>(authControllerProvider, (
      previous,
      next,
    ) {
      // Only a change in signed-in-ness affects routing; ignore the rest so
      // an unrelated state update does not trigger a redirect pass.
      if (previous?.isSignedIn != next.isSignedIn ||
          previous?.isRestoring != next.isRestoring) {
        notifyListeners();
      }
    }).close;
  }

  late final VoidCallback _removeListener;

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }
}

class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.explore_off_rounded, size: 42),
              const SizedBox(height: 16),
              Text(
                "That page isn't in the app.",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                location,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
