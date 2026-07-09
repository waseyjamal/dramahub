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
        versionCode = 11
        versionName = "1.1.0"
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
    implementation("com.unity3d.ads-mediation:mediation-sdk:9.4.3")

    // UnityAds
    implementation("com.unity3d.ads-mediation:unityads-adapter:5.9.0")
    implementation("com.unity3d.ads:unity-ads:4.18.1")

    // Chartboost
    implementation("com.unity3d.ads-mediation:chartboost-adapter:5.6.0")
    implementation("com.chartboost:chartboost-sdk:9.12.1")

    // InMobi
    implementation("com.unity3d.ads-mediation:inmobi-adapter:5.7.0")
    implementation("com.inmobi.monetization:inmobi-ads-kotlin:11.3.0")

    // Liftoff (Vungle)
    implementation("com.unity3d.ads-mediation:vungle-adapter:5.10.0")
    implementation("com.vungle:vungle-ads:7.7.4")
}
