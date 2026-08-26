# proguard-rules.pro
# ✅ Added Yandex Mobile Ads + Google AdMob rules at bottom

-keep class com.google.android.gms.common.** { *; }
# Keep Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep WebView
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepattributes JavascriptInterface
-keepattributes *Annotation*

# Keep Firebase Crashlytics
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**

# Keep Firebase Analytics
-keep class com.google.firebase.analytics.** { *; }
-dontwarn com.google.firebase.analytics.**

# Keep Firebase Cloud Messaging
-keep class com.google.firebase.messaging.** { *; }
-dontwarn com.google.firebase.messaging.**

# Keep Firebase Firestore
-keep class com.google.firebase.firestore.** { *; }
-dontwarn com.google.firebase.firestore.**

-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Appodeal — DISABLED (Appodeal removed)
#-keep class com.appodeal.** { *; }
#-keep class com.explorestack.** { *; }
#-dontwarn com.appodeal.**
#-dontwarn com.explorestack.**

# Media3 (used by video_player package — replaces legacy ExoPlayer2)
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# OkHttp / Network
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# CAS (Clever Ads Solutions) — DISABLED
#-dontwarn com.cleveradssolutions.**
#-keep class com.cleveradssolutions.** { *; }

# AppLovin
-dontwarn com.applovin.**
-keep class com.applovin.** { *; }

# IronSource / LevelPlay
-dontwarn com.ironsource.**
-keep class com.ironsource.** { *; }

# Mintegral
-dontwarn com.mbridge.**
-keep class com.mbridge.** { *; }

# InMobi
-dontwarn com.inmobi.**
-keep class com.inmobi.** { *; }

# BigoAds
-dontwarn sg.bigo.ads.**
-keep class sg.bigo.ads.** { *; }

# StartIO
-dontwarn com.startapp.**
-keep class com.startapp.** { *; }

# ChartBoost
-dontwarn com.chartboost.**
-keep class com.chartboost.** { *; }

# DTExchange (Fyber)
-dontwarn com.fyber.**
-keep class com.fyber.** { *; }

# volume_controller
-keep class com.androidquery.** { *; }
-dontwarn com.androidquery.**

# screen_brightness
-keep class com.aaassseee.screenbrightness.** { *; }
-dontwarn com.aaassseee.screenbrightness.**

# ── Yandex Mobile Ads SDK ────────────────────────────────────────────
-keep class com.yandex.mobile.ads.** { *; }
-dontwarn com.yandex.mobile.ads.**
-keep class com.yandex.ads.** { *; }
-dontwarn com.yandex.ads.**

# Google AdMob (required by Yandex mobileads-google adapter)
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
-keep class com.google.ads.** { *; }
-dontwarn com.google.ads.**

# VK Ads / myTarget (Yandex ecosystem adapter)
-keep class com.my.target.** { *; }
-dontwarn com.my.target.**

# Pangle (ByteDance)
-dontwarn com.bytedance.**
-keep class com.bytedance.** { *; }
-dontwarn com.pangle.**
-keep class com.pangle.** { *; }

# Start.io
-dontwarn com.startapp.**
-keep class com.startapp.** { *; }

# Tapjoy
-dontwarn com.tapjoy.**
-keep class com.tapjoy.** { *; }

# IronSource (via Yandex mediation)
-dontwarn com.ironsource.**
-keep class com.ironsource.** { *; }

# AppLovin (via Yandex mediation)
-dontwarn com.applovin.**
-keep class com.applovin.** { *; }