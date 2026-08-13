import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pinorpinor_app/core/theme/app_theme.dart';

/// Pumps a widget inside the app's real theme and a Riverpod scope.
///
/// Using [AppTheme.light] rather than a bare `MaterialApp` matters: several
/// widgets read their sizing and colour from the theme, so testing them without
/// it would test something the member never sees.
extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget widget, {
    List<Override> overrides = const <Override>[],
    Size? surfaceSize,
  }) async {
    if (surfaceSize != null) {
      view.physicalSize = surfaceSize;
      view.devicePixelRatio = 1;
      addTearDown(view.reset);
    }

    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: widget),
        ),
      ),
    );
    await pump();
  }

  /// Same, but without the surrounding [Scaffold] — for widgets that provide
  /// their own.
  Future<void> pumpScreen(
    Widget screen, {
    List<Override> overrides = const <Override>[],
    Size? surfaceSize,
  }) async {
    if (surfaceSize != null) {
      view.physicalSize = surfaceSize;
      view.devicePixelRatio = 1;
      addTearDown(view.reset);
    }

    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          home: screen,
        ),
      ),
    );
    await pump();
  }

  /// Pumps a screen inside a real [GoRouter].
  ///
  /// Several screens call `context.go`, `context.push` or `context.canPop()`,
  /// which need a router in the tree — testing them without one would assert
  /// before the widget ever built. The stub routes exist so navigation away
  /// from the screen under test lands somewhere identifiable.
  Future<void> pumpRouted(
    Widget screen, {
    List<Override> overrides = const <Override>[],
    Size? surfaceSize,
    List<String> stubRoutes = const <String>[],
  }) async {
    if (surfaceSize != null) {
      view.physicalSize = surfaceSize;
      view.devicePixelRatio = 1;
      addTearDown(view.reset);
    }

    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (context, state) => screen),
        for (final route in stubRoutes)
          GoRoute(
            path: route,
            builder: (context, state) =>
                Scaffold(body: Center(child: Text('stub:$route'))),
          ),
      ],
    );
    addTearDown(router.dispose);

    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          routerConfig: router,
        ),
      ),
    );
    await pump();
  }
}

/// Common device sizes, so a responsive assertion names the device it protects
/// rather than a bare number.
class TestDevices {
  const TestDevices._();

  /// The narrowest width the website was audited at.
  static const smallPhone = Size(320, 640);
  static const iPhoneSe = Size(375, 667);
  static const iPhonePro = Size(393, 852);
  static const iPhoneProMax = Size(430, 932);
  static const tablet = Size(768, 1024);
  static const iPadPro = Size(1024, 1366);
}
