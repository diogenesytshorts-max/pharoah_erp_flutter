pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val propertiesFile = File(settingsDir, "local.properties")
        if (propertiesFile.exists()) {
            propertiesFile.inputStream().use { properties.load(it) }
        }
        val sdkPath = properties.getProperty("flutter.sdk")
        requireNotNull(sdkPath) {
            "Flutter SDK not found. Define 'flutter.sdk' in local.properties or environment."
        }
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    // 🔥 Stable version (Flutter compatible)
    id("com.android.application") version "8.1.0" apply false

    // 🔥 Stable Kotlin version
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false
}

include(":app")
