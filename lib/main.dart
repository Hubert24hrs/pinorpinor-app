import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/theme/app_colors.dart';
import 'core/utils/app_log.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // All four orientations, on every form factor. Landscape earns its place on a
  // tablet, where ContentContainer and the FormFactor breakpoints reflow into
  // the extra width; locking a 10-inch iPad to portrait would be worse than the
  // reflow.
  //
  // This is not a per-device rule and cannot be one from here: setPreferredOrientations
  // is a single static list applied before the first frame, so there is no size
  // to branch on yet. A phone therefore rotates too. Every screen is a vertical
  // list, so it reflows rather than breaking -- but if phone-portrait-only is
  // ever wanted, it belongs in a widget that watches MediaQuery, not here.
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bgSecondary,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // A framework error must not take the process down silently. The message is
  // already free of user content — Flutter reports widget and render errors,
  // never payloads.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLog.error(
      'Flutter error: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
  };

  runApp(const ProviderScope(child: PinorpinorApp()));
}
