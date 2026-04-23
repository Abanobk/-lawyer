plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// White-label: pass from CI, e.g. `flutter build apk -- -POFFICE_CODE=myoffice -PAPP_LABEL=مكتب+العلا`
// ملاحظة: لا نغيّر applicationId لكل مكتب حتى يبقى تكامل Google (Firebase) أبسط (App واحد فقط).
val appLabelProp = (project.findProperty("APP_LABEL") as String?)?.trim().orEmpty()

android {
    namespace = "com.easytecheg.lawyer.lawyer_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.easytecheg.lawyer.lawyer_app"
        manifestPlaceholders["applicationLabel"] =
            if (appLabelProp.isNotEmpty()) appLabelProp else "مكتب المحاماة"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
