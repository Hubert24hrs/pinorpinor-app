import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/routing/deep_link_handler.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).restore();
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
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
