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

# REMOVED: -keep class com.get.** (GetX is Dart/Flutter, not Java — this rule was wrong and useless)

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

# Appodeal
-keep class com.appodeal.** { *; }
-keep class com.explorestack.** { *; }
-dontwarn com.appodeal.**
-dontwarn com.explorestack.**

# Unity Ads (used by Appodeal internally)
-keep class com.unity3d.ads.** { *; }
-keep class com.unity3d.services.** { *; }
-dontwarn com.unity3d.ads.**
-dontwarn com.unity3d.services.**

# Vungle (used by Appodeal internally)
-keep class com.vungle.** { *; }
-dontwarn com.vungle.**

# ExoPlayer / Better Player Plus
-keep class com.google.android.exoplayer2.** { *; }
-keep interface com.google.android.exoplayer2.** { *; }
-keep class com.google.android.exoplayer2.ext.** { *; }
-dontwarn com.google.android.exoplayer2.**

# OkHttp / Network (used by http package)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Meta Audience Network (Facebook Ads) - R8 missing class fix
-dontwarn com.facebook.infer.annotation.**
-keep class com.facebook.infer.annotation.** { *; }
-dontwarn com.facebook.ads.**
-keep class com.facebook.ads.** { *; }

# CAS (Clever Ads Solutions)
-dontwarn com.cleveradssolutions.**
-keep class com.cleveradssolutions.** { *; }

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