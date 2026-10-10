import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter passes --dart-define(-from-file) values as base64 "KEY=value" entries.
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.map { String(Base64.getDecoder().decode(it)) }
        ?.mapNotNull { entry ->
            entry.split("=", limit = 2).takeIf { it.size == 2 }?.let { it[0] to it[1] }
        }
        ?.toMap()
        ?: emptyMap()

// `flutter build --target-platform` only limits Flutter's own libraries; plugin
// native libraries (ML Kit's barcode scanner, ~4-6 MB per ABI) still ship for
// every ABI. Package only the ABIs the build targets.
val targetAbis: List<String> =
    (project.findProperty("target-platform") as String?)
        ?.split(",")
        ?.mapNotNull {
            mapOf(
                "android-arm" to "armeabi-v7a",
                "android-arm64" to "arm64-v8a",
                "android-x64" to "x86_64",
            )[it.trim()]
        }
        ?: emptyList()

// Release signing. CI writes android/key.properties from GitHub secrets
// (docs/DEPLOYMENT.md). Every release MUST be signed with the same key, or
// Android refuses to install it over the previous version.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) FileInputStream(file).use { load(it) }
}

android {
    namespace = "org.iftarramadhan.iftar_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "org.iftarramadhan.iftar_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Plain HTTP only when the build targets an http:// backend
        // (e.g. --dart-define-from-file=config/local.json). Production is HTTPS-only.
        manifestPlaceholders["usesCleartextTraffic"] =
            (dartDefines["API_URL"]?.startsWith("http://") == true).toString()
    }

    // Not ndk.abiFilters: the Flutter Gradle plugin resets those to every ABI.
    if (targetAbis.isNotEmpty()) {
        packaging {
            jniLibs {
                excludes += (listOf("armeabi-v7a", "arm64-v8a", "x86_64", "x86") - targetAbis)
                    .map { "lib/$it/**" }
            }
        }
    }

    signingConfigs {
        if (keystoreProperties.containsKey("storeFile")) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            // Debug talks to local backends (emulator 10.0.2.2, LAN IPs).
            manifestPlaceholders["usesCleartextTraffic"] = "true"
        }
        release {
            // The release key when key.properties exists, else the debug key so
            // local `flutter run --release` keeps working.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
