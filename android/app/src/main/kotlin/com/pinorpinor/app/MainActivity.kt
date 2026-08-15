package com.pinorpinor.app

import io.flutter.embedding.android.FlutterActivity

/**
 * The single Android entry point.
 *
 * The package declared here MUST match `namespace` in build.gradle.kts. The
 * manifest registers this activity as `.MainActivity` — a relative name that
 * Android resolves against the namespace — so if the two drift apart the build
 * still succeeds, the APK still installs, and the app throws
 * ClassNotFoundException the moment the launcher icon is tapped.
 *
 * That is exactly what happened once: the namespace was renamed from
 * `com.pinorpinor.pinorpinor_app` to `com.pinorpinor.app` without moving this
 * file. Nothing short of running it on a device catches it — Kotlin compiles,
 * the manifest merges, and Gradle reports success.
 */
class MainActivity : FlutterActivity()
