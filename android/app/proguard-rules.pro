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