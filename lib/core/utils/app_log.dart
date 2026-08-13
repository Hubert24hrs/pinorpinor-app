import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Logging that goes quiet in release builds.
///
/// Production logs must never carry passwords, OTPs, session cookies, private
/// messages or payment references, so nothing here accepts a payload — callers
/// pass a short human message and, at most, an error object. [error] is the one
/// level that survives a release build, because a crash with no breadcrumb is
/// worse than a redacted one.
class AppLog {
  const AppLog._();

  static const _name = 'pinorpinor';

  static void debug(String message) {
    if (!kDebugMode) return;
    developer.log(message, name: _name, level: 500);
  }

  static void info(String message) {
    if (!kDebugMode) return;
    developer.log(message, name: _name, level: 800);
  }

  static void warn(String message) {
    if (kReleaseMode) return;
    developer.log(message, name: _name, level: 900);
  }

  /// Kept in release builds so crash reporting has something to attach to.
  /// The message must already be free of user content.
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: _name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
