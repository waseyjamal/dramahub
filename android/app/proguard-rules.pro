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

# Unity Ads (used by LevelPlay)
-keep class com.unity3d.ads.** { *; }
-keep class com.unity3d.services.** { *; }
-dontwarn com.unity3d.ads.**
-dontwarn com.unity3d.services.**

# Vungle/Liftoff (used by LevelPlay)
-keep class com.vungle.** { *; }
-dontwarn com.vungle.**

# ExoPlayer (used by video_player package)
-keep class com.google.android.exoplayer2.** { *; }
-keep interface com.google.android.exoplayer2.** { *; }
-keep class com.google.android.exoplayer2.ext.** { *; }
-dontwarn com.google.android.exoplayer2.**

# OkHttp / Network
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Meta Audience Network (Facebook Ads)
-dontwarn com.facebook.infer.annotation.**
-keep class com.facebook.infer.annotation.** { *; }
-dontwarn com.facebook.ads.**
-keep class com.facebook.ads.** { *; }

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

# Ogury
-dontwarn io.ogury.**
-keep class io.ogury.** { *; }

# Smaato
-dontwarn com.smaato.**
-keep class com.smaato.** { *; }

# StartIO
-dontwarn com.startapp.**
-keep class com.startapp.** { *; }

# ChartBoost
-dontwarn com.chartboost.**
-keep class com.chartboost.** { *; }

# DTExchange (Fyber)
-dontwarn com.fyber.**
-keep class com.fyber.** { *; }

# Verve
-dontwarn net.pubnative.**
-keep class net.pubnative.** { *; }

# volume_controller
-keep class com.androidquery.** { *; }
-dontwarn com.androidquery.**

# screen_brightness
-keep class com.aaassseee.screenbrightness.** { *; }
-dontwarn com.aaassseee.screenbrightness.**

# flutter_cache_manager / sqflite
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

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

# AppNext
-dontwarn com.appnext.**
-keep class com.appnext.** { *; }

# Digital Turbine (ex. AdColony)
-dontwarn com.adcolony.**
-keep class com.adcolony.** { *; }
-dontwarn com.digitalturbine.**
-keep class com.digitalturbine.** { *; }

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