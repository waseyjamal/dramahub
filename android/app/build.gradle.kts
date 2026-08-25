import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

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

    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = localProperties.getProperty("RELEASE_KEY_ALIAS")
            keyPassword = localProperties.getProperty("RELEASE_KEY_PASSWORD")
            storeFile = localProperties.getProperty("RELEASE_STORE_FILE")?.let { file(it) }
            storePassword = localProperties.getProperty("RELEASE_STORE_PASSWORD")
        }
    }

    defaultConfig {
        applicationId = "com.dramahub.drama_hub"
        minSdk = 24
        targetSdk = 36
        versionCode = 13
        versionName = "1.2.1"
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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

    // ── LevelPlay mediation ───────────────────────────────────────────────────────
    // COMMENTED OUT — to restore, uncomment all lines below and
    // uncomment unity_levelplay_mediation in pubspec.yaml
    // Also restore com.ironsource.sdk.applicationId in AndroidManifest.xml
    // Also uncomment all LevelPlay code in lib/services/ad_service.dart
    //
    // implementation("com.unity3d.ads-mediation:mediation-sdk:9.4.3")
    // implementation("com.unity3d.ads-mediation:unityads-adapter:5.9.0")
    // implementation("com.unity3d.ads:unity-ads:4.18.1")
    // implementation("com.unity3d.ads-mediation:chartboost-adapter:5.6.0")
    // implementation("com.chartboost:chartboost-sdk:9.12.1")
    // implementation("com.unity3d.ads-mediation:inmobi-adapter:5.7.0")
    // implementation("com.inmobi.monetization:inmobi-ads-kotlin:11.3.0")
    // implementation("com.unity3d.ads-mediation:vungle-adapter:5.10.0")
    // implementation("com.vungle:vungle-ads:7.7.4")
    // ─────────────────────────────────────────────────────────────────────────────

    // ── Yandex Easy Monetization ──────────────────────────────────────────────────

    // Core Yandex SDK
    implementation("com.yandex.android:mobileads:8.2.0")

    // Google AdMob — highest fill rate globally (REQUIRED by Yandex setup)
    implementation("com.yandex.ads.mediation:mobileads-google:25.2.0.1")

    // Mintegral — strong Asian/South Asian market fill
    implementation("com.yandex.ads.mediation:mobileads-mintegral:17.0.41.2")

    // VK Ads (myTarget) — Yandex ecosystem, best Yandex fill rates
    implementation("com.yandex.ads.mediation:mobileads-mytarget:5.45.3.3")

    // AppLovin — global premium fill
    implementation("com.yandex.ads.mediation:mobileads-applovin:13.5.1.2")

    // BIGO Ads — Southeast Asian fill
    implementation("com.yandex.ads.mediation:mobileads-bigoads:5.7.0.2")

    // Chartboost — gaming/interstitial fill
    implementation("com.yandex.ads.mediation:mobileads-chartboost:9.3.1.30")


    // InMobi — global fill
    implementation("com.yandex.ads.mediation:mobileads-inmobi:11.0.0.2")

    // IronSource — demand source via Yandex mediation
    implementation("com.yandex.ads.mediation:mobileads-ironsource:9.2.0.2")

    // Pangle (ByteDance) — Asian market fill
    implementation("com.yandex.ads.mediation:mobileads-pangle:8.0.0.5.1")

    // Start.io — performance fill
    implementation("com.yandex.ads.mediation:mobileads-startapp:5.2.2.1")

    // Tapjoy — rewarded/offerwall fill
    implementation("com.yandex.ads.mediation:mobileads-tapjoy:14.3.1.11")

    // Liftoff (ex. Vungle) — video/rewarded fill
    implementation("com.yandex.ads.mediation:mobileads-vungle:7.7.0.2")

    // UnityAds — via Yandex mediation
    implementation("com.yandex.ads.mediation:mobileads-unityads:4.17.0.2")
}