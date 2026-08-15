import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Android wiring that no other check catches.
///
/// These are not unit tests of Dart logic — they read the real Gradle and
/// manifest files. They exist because this class of mistake compiles cleanly,
/// merges cleanly, and produces an APK that installs and then dies on the first
/// tap. `flutter analyze`, `flutter test` and `flutter build` all report
/// success. Only a device disagrees.
///
/// This has already happened once: the namespace was renamed from
/// `com.pinorpinor.pinorpinor_app` to `com.pinorpinor.app` and MainActivity.kt
/// was left behind, so the manifest's `.MainActivity` resolved to a class that
/// did not exist.
void main() {
  final gradle = File('android/app/build.gradle.kts');
  final manifest = File('android/app/src/main/AndroidManifest.xml');

  String? readValue(String source, String key) {
    final match = RegExp('$key\\s*=\\s*"([^"]+)"').firstMatch(source);
    return match?.group(1);
  }

  group('Android entry point', () {
    test('MainActivity lives in the package the namespace declares', () {
      final namespace = readValue(gradle.readAsStringSync(), 'namespace');
      expect(namespace, isNotNull, reason: 'namespace missing from Gradle');

      // The manifest names the activity relatively, so Android resolves it
      // against the namespace.
      expect(
        manifest.readAsStringSync(),
        contains('android:name=".MainActivity"'),
        reason: 'this test assumes the relative form',
      );

      final expected = File(
        'android/app/src/main/kotlin/${namespace!.replaceAll('.', '/')}/MainActivity.kt',
      );
      expect(
        expected.existsSync(),
        isTrue,
        reason:
            'namespace is "$namespace", so Android will look for '
            '$namespace.MainActivity. Expected ${expected.path}. '
            'Renaming the namespace means moving this file and changing its '
            'package declaration — the build will not tell you.',
      );

      expect(
        expected.readAsStringSync(),
        contains('package $namespace'),
        reason: 'the file is in the right folder but declares another package',
      );
    });

    test('no orphaned MainActivity is left behind after a rename', () {
      final kotlinRoot = Directory('android/app/src/main/kotlin');
      final activities = kotlinRoot
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('MainActivity.kt'))
          .toList();

      expect(
        activities,
        hasLength(1),
        reason:
            'exactly one MainActivity should exist; a leftover copy in the old '
            'package silently shadows nothing but confuses the next reader',
      );
    });
  });

  group('Android manifest', () {
    late String source;

    setUpAll(() => source = manifest.readAsStringSync());

    test('declares no location permission', () {
      // The backend stores a city and never sends coordinates to a client, so
      // asking for location would be requesting data the app cannot use — and
      // it is the permission most likely to fail a store review.
      expect(source, isNot(contains('ACCESS_FINE_LOCATION')));
      expect(source, isNot(contains('ACCESS_COARSE_LOCATION')));
      expect(source, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
    });

    test('refuses cleartext traffic', () {
      expect(source, contains('android:usesCleartextTraffic="false"'));
      expect(source, contains('android:networkSecurityConfig'));
    });

    test('registers both deep-link forms', () {
      expect(source, contains('android:scheme="pinorpinor"'));
      expect(source, contains('android:host="pinorpinor.com"'));
      expect(source, contains('android:autoVerify="true"'));
    });

    test('can resolve WhatsApp on Android 11+', () {
      // Without this <queries> entry `canLaunchUrl` reports false even when
      // WhatsApp is installed, and the contact handoff silently does nothing.
      expect(source, contains('com.whatsapp'));
    });
  });

  group('Gradle', () {
    late String source;

    setUpAll(() => source = gradle.readAsStringSync());

    test('applicationId matches the namespace', () {
      expect(
        readValue(source, 'applicationId'),
        readValue(source, 'namespace'),
      );
    });

    test('core library desugaring stays on', () {
      // flutter_local_notifications uses java.time; without desugaring the
      // build fails at checkDebugAarMetadata.
      expect(source, contains('isCoreLibraryDesugaringEnabled = true'));
      expect(source, contains('coreLibraryDesugaring('));
    });

    test('release signing falls back rather than failing the build', () {
      // key.properties is gitignored and absent on a fresh clone. The fallback
      // is what keeps `flutter build` working locally; the comment beside it is
      // what stops someone shipping a debug-signed bundle by accident.
      expect(source, contains('key.properties'));
      expect(source, contains('hasReleaseKeystore'));
    });
  });
}
