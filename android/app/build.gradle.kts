import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Load local.properties
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

android {
    namespace = "com.dramahub.drama_hub"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = localProperties.getProperty("RELEASE_KEY_ALIAS")
            keyPassword = localProperties.getProperty("RELEASE_KEY_PASSWORD")
            storeFile = localProperties.getProperty("RELEASE_STORE_FILE")?.let { file(it) }  // ✅ null-safe
            storePassword = localProperties.getProperty("RELEASE_STORE_PASSWORD")
        }
    }

    defaultConfig {
        applicationId = "com.dramahub.drama_hub"
        minSdk = flutter.minSdkVersion // ✅ Appodeal 4.1.0 requires Min SDK 23
        targetSdk = 36
        versionCode = 5
        versionName = "1.0.4"
        multiDexEnabled = true // ✅ Required for Appodeal
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")  // ✅ THIS was the missing line
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("com.android.installreferrer:installreferrer:2.2")

    implementation("com.appodeal.ads.sdk:core:4.1.0")
   
   
    // Appodeal
    implementation("com.appodeal.ads.sdk.adapters:applovin:13.5.1.0")
    implementation("com.appodeal.ads.sdk.adapters:applovin_max:13.5.1.1")
    implementation("com.appodeal.ads.sdk.adapters:bidmachine:3.6.1.0")
    implementation("com.appodeal.ads.sdk.adapters:bidon:0.13.0.0")
    implementation("com.appodeal.ads.sdk.adapters:bigo_ads:5.6.2.0")
    implementation("com.appodeal.ads.sdk.adapters:iab:1.8.1.0")
    implementation("com.appodeal.ads.sdk.adapters:level_play:9.1.0.0")
    implementation("com.appodeal.ads.sdk.adapters:mintegral:17.0.31.0")
    implementation("com.appodeal.ads.sdk.adapters:sentry_analytics:8.26.0.0")
    implementation("com.appodeal.ads.sdk.adapters:unity_ads:4.17.0.0")
    implementation("com.appodeal.ads.sdk.adapters:vungle:7.6.1.0")
}
