import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is read from android/key.properties, which is gitignored and
// never committed. When the file is absent — a fresh clone, or CI without
// secrets — the release build falls back to debug signing so `flutter build`
// still succeeds locally, and the upload key stays the operator's alone.
// docs/DEPLOYMENT.md walks through generating and storing it.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.pinorpinor.app"

    // Flutter's default, currently 36. Every dependency compiles against 36 or
    // lower — see the note on `flutter_secure_storage` in pubspec.yaml for why
    // that pin matters: SDK 37 ships only as the minor-versioned `android-37.0`
    // platform, which AGP 8.11 cannot resolve.
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // Required by flutter_local_notifications, which uses java.time to
        // schedule notifications. Without it the build fails at
        // :app:checkDebugAarMetadata. Desugaring backports those APIs to the
        // minSdk below rather than raising it, so no device is excluded.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.pinorpinor.app"
        // flutter_secure_storage requires 21+; image_picker and the Play policy
        // floor push this higher. The Flutter default tracks the current
        // requirement, so it is used rather than pinned.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resourceConfigurations += listOf("en")
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Produces an installable artifact for local testing only.
                // A build signed this way cannot be uploaded to Play.
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }

        debug {
            // Lets a debug build sit beside a release install on the same device.
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }

    // The .aab Play expects. Splitting by ABI and density is what keeps the
    // download small on the low-end Android hardware much of the audience uses.
    bundle {
        language { enableSplit = false }
        density { enableSplit = true }
        abi { enableSplit = true }
    }
}

dependencies {
    // The desugaring runtime that `isCoreLibraryDesugaringEnabled` above needs.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
