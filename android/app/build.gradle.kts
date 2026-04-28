plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.rawat.pharoah_erp"
    // UPDATED: Required by latest AndroidX activity libraries
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.rawat.pharoah_erp"
        minSdk = 24 
        // UPDATED: Aligned with compileSdk
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}

// THE CURE FOR lStar ERROR:
// Forcing 1.15.0-alpha01 or higher is needed for SDK 36 compatibility
configurations.all {
    resolutionStrategy {
        force("androidx.core:core:1.15.0-alpha01")
        force("androidx.core:core-ktx:1.15.0-alpha01")
        force("androidx.annotation:annotation:1.9.1")
    }
}

flutter {
    source = "../.."
}
