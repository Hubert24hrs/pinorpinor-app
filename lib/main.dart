import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/theme/app_colors.dart';
import 'core/utils/app_log.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-first. Landscape is allowed on tablets, where the layouts adapt to
  // the extra width; locking a 10-inch iPad to portrait would be worse than the
  // reflow. Phones stay upright because every screen here is a vertical list.
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
