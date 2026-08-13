# R8 rules for the Pinorpinor release build.
#
# Flutter's own engine classes are kept by the plugin's bundled configuration;
# what follows covers the plugins this app uses that reflect over their own
# types, plus a rule that removes logging from the shipped binary.

# ── Flutter engine ────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── flutter_local_notifications ───────────────────────────────────────────
# Scheduled notifications are restored after a reboot by deserialising their
# payload with Gson, which needs the model classes and their generic signatures.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn com.dexterous.**

# ── image_picker / flutter_image_compress ─────────────────────────────────
-dontwarn com.google.android.gms.**

# ── Strip logging from the release binary ─────────────────────────────────
# Nothing in this app logs user content, but removing the calls entirely means
# a future mistake cannot leak through logcat on a shipped build either.
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
}

# ── Keep line numbers for readable crash reports ──────────────────────────
# Without this a stack trace from the field is unusable. The source file name
# itself is hidden, so it reveals nothing about the project layout.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
