import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/routing/deep_link_handler.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/splash_screen.dart';
import 'features/onboarding/age_gate_controller.dart';
import 'features/onboarding/age_gate_screen.dart';

/// The application root.
class PinorpinorApp extends ConsumerStatefulWidget {
  const PinorpinorApp({super.key});

  @override
  ConsumerState<PinorpinorApp> createState() => _PinorpinorAppState();
}

class _PinorpinorAppState extends ConsumerState<PinorpinorApp> {
  @override
  void initState() {
    super.initState();
    // Restore the stored session before the first frame settles, so the splash
    // resolves into the right screen rather than flashing signed-out.
    //
    // The age acknowledgement is read in parallel: both are local reads, and
    // sequencing them would add a round trip to every cold start for no reason.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).restore();
      ref.read(ageGateControllerProvider.notifier).restore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return DeepLinkHandler(
      router: router,
      child: MaterialApp.router(
        title: 'Pinorpinor',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // The website ships a single light identity with no theme switcher, so
        // the app follows it rather than inventing a dark mode the brand has
        // never had. The theming is structured to accept one later.
        themeMode: ThemeMode.light,
        routerConfig: router,
        builder: (context, child) {
          // Respect the platform text-size setting, but stop an extreme scale
          // from breaking layouts that must still work at 320px wide.
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.4,
              ),
            ),
            // The gate wraps the router's output rather than being a route.
            //
            // As a route it would be reachable by deep link and skippable by
            // one — `pinorpinor://profile/x` would land straight on a profile
            // photo without the notice ever rendering. Wrapping the whole
            // navigator means nothing paints until the acknowledgement is
            // resolved, whatever brought the member into the app.
            child: _AgeGateBoundary(child: child ?? const SizedBox.shrink()),
          );
        },
      ),
    );
  }
}

/// Holds the app behind the 18+ acknowledgement.
///
/// Keeps [child] mounted underneath rather than swapping it out, so the router
/// keeps its state and the member lands exactly where their deep link pointed
/// once they accept — no second navigation, no lost destination.
class _AgeGateBoundary extends ConsumerWidget {
  const _AgeGateBoundary({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(ageGateControllerProvider);

    return switch (phase) {
      // Local read, typically a frame or two. The splash already reads as
      // "starting up", so reusing it avoids a second distinct loading state.
      AgeGatePhase.checking => const SplashScreen(),

      AgeGatePhase.required => AgeGateScreen(
        onAccept: () => ref.read(ageGateControllerProvider.notifier).accept(),
        onDecline: () => ref.read(ageGateControllerProvider.notifier).decline(),
      ),

      AgeGatePhase.declined => const AgeGateDeclinedScreen(),

      AgeGatePhase.accepted => child,
    };
  }
}
