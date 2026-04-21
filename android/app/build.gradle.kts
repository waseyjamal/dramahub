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
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
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
        targetSdk = 35
        versionCode = 4
        versionName = "1.0.3"
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
    // Multidex support
    implementation("androidx.multidex:multidex:2.0.1")

      implementation("com.appodeal.ads.sdk:core:4.1.0")
    // Bidon
    
    implementation("org.bidon:applovin-adapter:13.5.1.0")
    implementation("org.bidon:bidmachine-adapter:3.6.1.0")
    implementation("org.bidon:bigoads-adapter:5.6.2.0")
    implementation("org.bidon:chartboost-adapter:9.10.2.0")
    implementation("org.bidon:inmobi-adapter:11.1.0.0")
    
    implementation("org.bidon:meta-adapter:6.20.0.0")
    implementation("org.bidon:mintegral-adapter:17.0.31.0")
    
    implementation("org.bidon:unityads-adapter:4.17.0.0")
    implementation("org.bidon:vungle-adapter:7.6.1.0")
    
    // BidMachine
   
    implementation("io.bidmachine:ads.networks.meta_audience:6.20.0.0")
    implementation("io.bidmachine:ads.networks.mintegral:17.0.31.0")
    implementation("io.bidmachine:ads.networks.vungle:7.6.1.0")
    // Appodeal
    implementation("com.appodeal.ads.sdk.adapters:admob:24.7.0.0")
    
    implementation("com.appodeal.ads.sdk.adapters:applovin:13.5.1.0")
    implementation("com.appodeal.ads.sdk.adapters:bidmachine:3.6.1.0")
    implementation("com.appodeal.ads.sdk.adapters:bidon:0.13.0.0")
    implementation("com.appodeal.ads.sdk.adapters:bigo_ads:5.6.2.0")
    implementation("com.appodeal.ads.sdk.adapters:chartboost:9.10.2.0")
    
    implementation("com.appodeal.ads.sdk.adapters:inmobi:11.1.0.0")
    implementation("com.appodeal.ads.sdk.adapters:ironsource:9.1.0.0")
    implementation("com.appodeal.ads.sdk.adapters:meta:6.20.0.0")
    implementation("com.appodeal.ads.sdk.adapters:mintegral:17.0.31.0")
    implementation("com.appodeal.ads.sdk.adapters:sentry_analytics:8.26.0.0")
    
    implementation("com.appodeal.ads.sdk.adapters:unity_ads:4.17.0.0")
    implementation("com.appodeal.ads.sdk.adapters:vungle:7.6.1.0")
    
}
