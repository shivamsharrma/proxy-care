plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.proxycare.proxy_care_client"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The application ID and app name come from the product flavor.
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // App Links host (AndroidManifest intent filter). `.invalid` is a
        // reserved placeholder: no domain is owned yet. Override with
        // `-PappLinkHost=<domain>` once one is (docs/deep-linking.md).
        manifestPlaceholders["appLinkHost"] =
            (project.findProperty("appLinkHost") as String?) ?: "app-links.invalid"
    }

    // One flavor per app (APP_VARIANT): build with `--flavor user` or
    // `--flavor caretaker` plus the matching `--dart-define=APP_VARIANT=...`
    // (see the Makefile). The Kotlin namespace stays shared. The app name is
    // the `appName` manifest placeholder (android:label), set per flavor with
    // `[]=` so it merges with the defaultConfig placeholders.
    flavorDimensions += "app"
    productFlavors {
        create("user") {
            dimension = "app"
            applicationId = "com.proxycare.user"
            manifestPlaceholders["appName"] = "proxy-care"
        }
        create("caretaker") {
            dimension = "app"
            applicationId = "com.proxycare.caretaker"
            manifestPlaceholders["appName"] = "proxy-caretaker"
        }
    }

    buildTypes {
        release {
            // CI and local release builds are signed with the debug key, so no
            // credentials are needed. Store releases need an upload key
            // configured outside the repository (README, "Android
            // configuration"); never commit signing files.
            signingConfig = signingConfigs.getByName("debug")
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
