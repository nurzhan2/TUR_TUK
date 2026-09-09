plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.turtuk.client_app"
    compileSdk = flutter.compileSdkVersion
    // ndkVersion ЯВНО пустой, а не просто опущен: если её не задать вовсе,
    // AGP подставляет свой умолчательный NDK (тот же 28.2.13676358), и
    // Flutter Gradle-плагин (FlutterPluginUtils.forceNdkDownload) видит
    // непустую версию и зовёт sdkmanager --install ndk;... на этапе
    // конфигурации — даже если ни один таск сборки NDK не использует.
    // Пустая строка делает getConfiguredNdkVersion() blank, и плагин
    // сам уходит в синтетический CMake-фолбэк вместо скачивания
    // (см. FlutterPluginUtils.kt: maybeHandleToolNdkProvisioning
    // возвращает false при пустой ndkVersion). Проект без нативного
    // (JNI) кода, реальный NDK ему не нужен, а качать тулчейны в эту
    // сессию запрещено.
    ndkVersion = ""

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.turtuk.client_app"
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
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
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
