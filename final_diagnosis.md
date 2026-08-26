# Drama Hub — Full Pre-Release Diagnosis Report
Generated: 2026-08-26

Scope: all 68 files under `lib/`, `pubspec.yaml`, and the Android project (`build.gradle.kts`, `AndroidManifest.xml`, `proguard-rules.pro`, `MainActivity.kt`). This codebase already carries visible marks of a prior cleanup pass (`// ✅` comments, `RepaintBoundary`/`memCacheWidth`/`itemExtent` used deliberately in several places, no bare `print()` or `TODO`/`FIXME` left) — findings below are what survived that pass, plus a few new items in recently-touched files.

## Executive Summary

**Health score: 74/100**
**Critical issues: 3** | **Warnings: 20** | **Minor/info: 12**

The app is close to release-ready. Firebase/Crashlytics/FCM wiring, GetX controller lifecycle, Android manifest permissions, version-number consistency, and image caching are all solid. The blockers are narrow but real: a security gap that leaves downloaded (offline) video unprotected from screen capture while streaming video is protected, a live Telegram bot token shipped in a plaintext public config file, and a stale-data bug in the newly added Category screen. Everything else is cleanup (dead code, duplicated logic, missing `const`, dead dependencies/ProGuard rules) that improves maintainability but won't block a release.

---

## Critical Issues (must fix before release)

1. **`lib/screens/category_screen.dart:26,41-42`** — `_dramas` is captured **once** in `initState()` from `HomeController.allDramas` into a plain non-reactive `List<DramaModel>`. If the user pulls-to-refresh on Home (which reassigns `HomeController.allDramas`) while `CategoryScreen` is still on the nav stack, the category list silently goes stale until the screen is destroyed and rebuilt.
   **Fix:** derive `_dramas` reactively — wrap the filtered list in `Obx(() => ...)` reading `homeController.allDramas` directly, or re-filter in `build()` instead of caching a snapshot in `initState`.

2. **`lib/screens/downloads_screen.dart:535-591` (`OfflinePlayerScreen` / `_OfflinePlayerScreenState`)** — offline/downloaded episode playback never calls `VideoService.enableSecureMode()`. Compare with `lib/controllers/video_controller.dart:67,73`, which correctly enables `FLAG_SECURE` for the live-streaming `VideoScreen`. As shipped, a user can screenshot or screen-record **downloaded premium episodes** even though the app explicitly protects the same content when streamed — this defeats the purpose of the whole signed-URL/secure-mode content-protection design for the offline path.
   **Fix:** call `VideoService.instance.enableSecureMode()` in `_OfflinePlayerScreenState.initState()`/`_initPlayer()` and `disableSecureMode()` in `dispose()`, mirroring `video_controller.dart`.

3. **Telegram bot token & chat ID shipped in plaintext via a public, unauthenticated remote config** — `lib/services/remote_config_service.dart:6-18`, `lib/services/telegram_service.dart:16-17`, `lib/config/app_config_model.dart:74-75`. The app fetches `app_config.json` from a public CDN URL (`https://dramahub-data.pages.dev/app_config.json`, with a `raw.githubusercontent.com` fallback) with no auth. That JSON embeds `telegram_bot_token`/`telegram_chat_id` in plaintext — anyone who fetches the same public URL (trivial, it's designed to be publicly fetchable by the app) obtains a live bot token usable via the Telegram Bot API to spam or otherwise abuse the admin's chat.
   **Fix:** never ship the raw bot token to clients. Proxy `sendMessage` calls through a small server-side function (same infra the project already uses for `signing_service.dart`) that holds the token server-side; have the app call that endpoint instead of Telegram's API directly.

---

## Warnings (should fix)

### Security
- **No integrity/signature check on remote config** (`lib/services/remote_config_service.dart:35-49`) — `app_config.json` is trusted as-is after a plain `http.get`. Anyone who can compromise the Cloudflare Pages/GitHub source or MITM the connection can serve a malicious config, e.g. flip `use_signed_urls` to `false` and force the app onto unsigned stream URLs, defeating `signing_service.dart` entirely. Add an HMAC/Ed25519 signature over the payload that the app verifies before applying security-relevant fields.
- **No certificate pinning anywhere** in the app (`http`/`dio` both use default `HttpClient`). Given the app talks to a URL-signing API and Firestore with a live auth bearer token, a MITM with a trusted-store CA (corporate proxy, malicious VPN, rooted device) can intercept/replay these calls. Add pinning at minimum for the signing API and Firestore endpoints.
- **`lib/screens/premium_screen.dart`** and **`lib/widgets/telegram_cta_button.dart`** launch Telegram/website URLs directly (`Uri.parse(...)` → `launchUrl(...)`) without the `AppUrls.isSafeUrl()` check that every other URL-launch site in the app uses (verified: `main.dart`, `home_controller.dart`, `upcoming_screen.dart`, `about_screen.dart`, `profile_screen.dart` all gate through `isSafeUrl`). Inconsistent hardening — route these two through the same check.
- **Root-detection is a cosmetic warning only** (`lib/security/root_checker.dart`, invoked from `main.dart:182`) — checks for `su` binaries at 8 known paths and, if found, only shows a warning dialog (`_showRootWarning()`); trivially bypassed (Magisk hide, renamed binaries) and doesn't gate any actual functionality. Acceptable as a soft nudge; don't treat it as real protection if that's the intent.

### Code Quality & Architecture
- **`lib/widgets/custom_video_player.dart`** — `_CustomVideoPlayerState` (~lines 46–1062) and `_FullscreenControlsState` (~lines 1133–1982) duplicate ~700 lines of near-identical logic (seek animation, brightness/volume drag, progress bar, speed sheet, hide-timer). Largest maintainability risk in the app — a fix applied to one path is easy to forget in the other. Extract a shared controller/mixin.
- **`lib/services/ad_service.dart`** — ~350 lines of commented-out `[LEVELPLAY]` code left in shipped source (mirrored by 10 commented mediation deps in `build.gradle.kts` and dead ProGuard rules, see Android section). If retired, delete; if returning, use a feature flag instead of block comments.
- **`lib/utils/app_snackbar.dart`** — `success/error/info/warning/copied` are five near-identical ~25-line blocks; collapse into one `_show({title, message, color, icon})` helper.
- **`lib/screens/episodes_screen.dart:241-259`, `lib/screens/upcoming_screen.dart:478-494`, `lib/services/telegram_service.dart:152-168`** — three independent hand-rolled month-name arrays for date formatting. Consolidate into one shared util.
- **`lib/screens/profile_screen.dart:338-354`** — `_TileData.badge` field is defined and rendered but never passed by any call site (dead feature, suppressed with `// ignore: unused_element_parameter`). Wire it up or remove it.
- **`lib/services/download_service.dart`** — `_buildPlaybackFileFromDramahub`, `_preparePlaybackFile`, `_obfuscateFile`, `_appendHmac`, `_verifyHmac` all open `RandomAccessFile` handles without `try/finally`. On a mid-method exception (e.g. disk-full `FileSystemException`, which the code's own comments anticipate), the handle is never closed — leaks file descriptors under repeated failure. Wrap each open/close pair in `try { } finally { await raf.close(); }`.
- **`lib/screens/upcoming_screen.dart:325-332`** — `canLaunchUrl(url).then(...)` has no `.catchError`; every other URL-launch site in the app wraps in try/catch. `canLaunchUrl` can throw `PlatformException` on some OEM ROMs.
- **`lib/widgets/yandex_banner_ad_widget.dart:17-24`** — `_adUnitIds` maps both `'download_screen'` and `'upcoming_screen'` to the **same** ad unit ID (`R-M-19564249-13`), while every other screen has a distinct sequential ID. Looks like a copy-paste bug that will corrupt per-screen ad revenue attribution in the Yandex dashboard.
- **`lib/services/analytics_writer_service.dart`** — a full 165-line Firestore REST client (anonymous-auth bearer tokens, atomic increments) exists but has **zero call sites** anywhere in `lib/`. Either dead code, or a feature that was meant to be wired into `EpisodesController._navigateToVideo` and isn't — confirm with the team, then delete or wire it in.
- **`.gitignore:66-67`** — corrupted trailing content (`drama_hub.iml* . h p r o f`) that doesn't cleanly ignore either `.iml` files or `*.hprof` heap dumps as apparently intended. Low risk today but could let a large heap-dump file get committed accidentally.

### UI/UX
- **`lib/screens/latest_episodes_screen.dart:42-57`, `lib/screens/new_dramas_screen.dart:42-59`** — both show the same "nothing here yet" empty state regardless of *why* the list is empty. Since they read straight from `HomeController`'s already-loaded lists, a user who lands here while Home failed to load sees a misleading empty state instead of a connectivity/error message.
- **`lib/screens/home_screen.dart`** search overlay has no tap-outside-to-dismiss-keyboard handler, unlike `CategoryScreen` which wraps its body in a `GestureDetector` for exactly this. Minor inconsistency.

### Firebase & Analytics
- Firestore writes in `analytics_writer_service.dart:63-83` use a live anonymous-auth ID token with no client-side rate limiting; if this service is ever wired in, confirm Firestore Security Rules restrict the anonymous role to the intended `analytics/*` paths and to increments only (the REST payload is fully client-constructed, so rules are the only backstop).

---

## Performance Issues

Overall good — the codebase already shows deliberate optimization: merged `Obx` blocks in `drama_card.dart`, scoped `Obx` in `continue_watching_card.dart`, `RepaintBoundary` around each home section, `memCacheWidth`/`memCacheHeight` on nearly every `CachedNetworkImage`, and `itemExtent` on `latest_episodes_row.dart`'s horizontal list.

- **`lib/screens/downloads_screen.dart:34,45`** — `_EmptyState()` and `_StorageSummary(service: service)` are `StatelessWidget`s instantiated without `const` and without declaring `const` constructors. Free win.
- **`coming_soon_row.dart`, `new_dramas_row.dart`** — horizontal `ListView.builder`s with fixed-width (130px) cards don't set `itemExtent`, unlike `latest_episodes_row.dart` which does (`itemExtent: 142.0` would let Flutter skip per-child size measurement).
- **`lib/screens/home_screen.dart:63-77`** — the hero-slider `Timer.periodic(4s)` keeps firing (as a no-op) even when `heroSliderDramas.length <= 1`. Not a leak (cancelled in `dispose`), just a small amount of wasted wakeups — pause the timer when there's nothing to rotate.

---

## Security Issues

See **Critical Issues #2 and #3** and the **Security** subsection under **Warnings** above for the full list (offline-playback FLAG_SECURE gap, plaintext Telegram bot token, unsigned remote config, no certificate pinning, inconsistent `isSafeUrl` usage, cosmetic root check). Positive findings, verified correct:

- No hardcoded generic API keys/secrets found in `lib/` beyond the Firebase client key in `firebase_options.dart:56`, which is expected/standard for Firebase apps (not a secret by design — verify it has Android package+SHA-1 restrictions in Google Cloud Console).
- Bearer tokens for Firestore writes are live Firebase Auth ID tokens (`signInAnonymously()` + `getIdToken()`), not static secrets — correct pattern.
- `flutter_secure_storage` is used appropriately for the local XOR obfuscation key (`download_service.dart`) that protects cached video segments; everything else (watchlist, history, progress, cooldown timestamps) uses plain `SharedPreferences`, which is appropriate since none of it is sensitive/PII.
- `android:allowBackup="false"` is set, correctly preventing `adb backup` exfiltration of the secure-storage key or cached media.
- No plaintext `http://` API traffic detected — the only `http://` string in the project is in the manifest's `<queries>` intent-filter (needed for `url_launcher` to resolve `http` links), not an actual insecure call.

---

## Code Quality Issues

See **Warnings → Code Quality & Architecture** above for the full list. Summary of themes: significant logic duplication in the video player and snackbar utilities, dead/orphaned code (`AnalyticsWriterService`, commented-out LevelPlay integration, unused `badge` field), an unguarded file-handle leak path in `download_service.dart`, a copy-paste ad-unit-ID bug, and SharedPreferences key fragmentation — `StorageKeys` exists specifically to centralize keys but is bypassed by raw string keys in `video_screen.dart` (`'progress_${...}'`, `'playback_speed'` — duplicating existing unused constants), `download_service.dart`, and the report/suggest cooldown screens. Low risk today; centralize to avoid future key collisions.

Also minor: several `if (kDebugMode) debugPrint(...)` statements are written as brace-less single-line-ifs spanning multiple physical lines (e.g. `video_screen.dart:81-84`) — works but fragile under future edits; `video_screen.dart:67,73` wraps `VideoService` calls in a redundant outer `.catchError((_) {})` on top of the service's own internal catch; `home_controller.dart:401`'s `_updateDialogShown` flag would reset if `HomeController` were ever deleted/recreated (currently unreachable — nothing calls `Get.delete<HomeController>()`); `premium_screen.dart` hardcodes Telegram deep links instead of sourcing them from `AppConfigService`/`AppUrls`; `privacy_policy_screen.dart:51` hardcodes "Last updated: February 2026" with no single source of truth.

---

## Android Configuration

**SDK versions** (`android/app/build.gradle.kts:41-48`): `minSdk = 24`, `compileSdk` resolves via Flutter to 36, `targetSdk = 36`. ✅ Meets the release checklist requirement.

**Build hygiene:** Release build correctly minified/shrunk (`isMinifyEnabled = true`, `isShrinkResources = true`) with both the default optimize rules and a large custom `proguard-rules.pro`. Good.

**ProGuard rule cleanup needed** — the ruleset keeps ~60 blanket `-keep class X.** { *; }` blocks, several of which are for SDKs **no longer present as Gradle dependencies**:
- `com.unity3d.ads.**`/`com.unity3d.services.**` — LevelPlay/Unity Ads mediation is commented out in `build.gradle.kts`.
- `com.facebook.ads.**` (Meta Audience Network) — no such Gradle dependency present.
- `io.ogury.**`, `com.smaato.**`, `net.pubnative.**` (Verve), `com.appnext.**`, `com.adcolony.**`/`com.digitalturbine.**` — none present as dependencies.
These are harmless but a maintenance trap (implies integrations that don't exist) and slightly bloat the shrunk output. Remove them; note `com.cleveradssolutions.**` (CAS) is *already* correctly commented out elsewhere in the same file, showing the pattern is known, just not applied consistently.

Additionally, `-keep class com.google.android.exoplayer2.** { *; }` targets the **legacy** ExoPlayer2 package, while the `video_player` plugin at its current version likely uses **media3** (`androidx.media3.**`), which has no explicit keep rule of its own. Verify a release-mode (minified) build actually plays video (a classic R8-breaks-playback failure mode); add `-keep class androidx.media3.** { *; }` if needed and drop the legacy exoplayer2 rule if it's a no-op.

**AndroidManifest permissions audit** — clean and minimal, no unused or missing permissions found:

| Permission | Used by | Status |
|---|---|---|
| `INTERNET` | networking/streaming | required ✅ |
| `POST_NOTIFICATIONS` | `firebase_messaging` (FCM) | required ✅ |
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_DATA_SYNC` | `background_downloader` | required ✅ |
| `WRITE_EXTERNAL_STORAGE` (maxSdk 28) / `READ_EXTERNAL_STORAGE` (maxSdk 32) | legacy pre-scoped-storage support | correctly capped ✅ |
| `com.google.android.gms.permission.AD_ID` | ad mediation attribution | required ✅ |
| `CAMERA`, `RECORD_AUDIO`, `ACCESS_FINE_LOCATION`, etc. | — | not declared, not used — clean |

**Third-party attack surface:** `android/build.gradle.kts` declares 6 third-party Maven repos (Chartboost, IronSource, Pangle, Tapjoy, Mintegral, Huawei) to resolve 11 ad-mediation networks pulled in transitively via Yandex mediation. No version-conflict evidence found, but worth a periodic supply-chain review of which of these 11 networks are actually delivering fill in production — drop unused ones to shrink both APK size and attack surface.

**Version drift risk:** `versionCode`/`versionName` are hardcoded explicitly in `build.gradle.kts` (`13` / `"1.2.1"`) rather than left to the Flutter Gradle plugin's normal auto-derivation from `pubspec.yaml`. They match today, but this is a two-places-to-update problem going forward — consider removing the hardcoded values so they're derived from `pubspec.yaml` automatically.

---

## Dependencies Audit

- **Unused dependencies:** `dio: ^5.9.2` (pubspec.yaml:58) — zero `package:dio` imports anywhere; all networking uses `package:http`. `flutter_cache_manager: ^3.4.1` (pubspec.yaml:52) — zero direct imports; `cached_network_image` already bundles its own use of it. Remove both (`flutter pub remove dio flutter_cache_manager`), or actually adopt `dio` for the endpoints that need the certificate-pinning interceptor noted under Security.
- **`unity_levelplay_mediation`** is commented out in pubspec.yaml, consistent with the Dart-side `[LEVELPLAY]` comments in `ad_service.dart` and the Gradle-side comments — intentionally parked, not a bug. (But see the dead ProGuard rules note above — the *rules* for it are still live even though code and dependency are both inactive.)
- **No version-range conflicts detected** — all first-party packages use `^` caret constraints with recent-looking versions; nothing pinned to `any` or an exact version that would block resolution. Firebase plugin versions (`firebase_core: ^4.4.0`, `firebase_messaging: ^16.1.1`, `firebase_analytics: ^12.1.2`, `firebase_crashlytics: ^5.0.7`, `firebase_auth: ^6.4.0`) look like consistent FlutterFire release-train versions, but run `flutter pub outdated` before release to confirm against the latest compatible set (not verifiable offline).
- **No missing packages found** — every `package:` import in `lib/` has a matching `pubspec.yaml` entry (aside from the two unused deps above); `flutter_secure_storage`, `crypto`, `connectivity_plus`, `package_info_plus`, `wakelock_plus`, `screen_brightness`, `volume_controller` are all present and consistent with their usage.

---

## Release Readiness Checklist

- [x] targetSdk = 36
- [x] No debug prints without kDebugMode guard *(grep clean — no bare `print()` calls found)*
- [ ] All screens have error states *(latest_episodes_screen.dart / new_dramas_screen.dart show a generic empty state instead of distinguishing "empty" from "failed to load")*
- [x] All screens have loading states
- [ ] No hardcoded secrets *(Telegram bot token shipped in plaintext via public remote config — see Critical #3)*
- [ ] ProGuard rules complete *(dead rules for removed ad SDKs should be cleaned up; verify/add an explicit `androidx.media3.**` keep rule)*
- [x] Firebase configured correctly *(Crashlytics, FCM, Analytics all verified wired correctly)*
- [x] Version code and name correct *(pubspec.yaml `1.2.1+13` matches `build.gradle.kts` `versionCode 13` / `versionName "1.2.1"`)*
- [x] Splash screen configured *(`flutter_native_splash.yaml` present, `FlutterNativeSplash.preserve()/remove()` correctly bracket startup — recommend re-running `dart run flutter_native_splash:create` if branding changed recently, since it doesn't regenerate automatically on build)*
- [x] App icon configured *(all 5 density buckets present)*

---

## Final Verdict

**Not release ready — 3 must-fix items, all narrow and fast to resolve.**

1. Fix the `category_screen.dart` stale-data bug (state management).
2. Add `enableSecureMode()`/`disableSecureMode()` to `OfflinePlayerScreen` so downloaded premium content gets the same screen-capture protection as streamed content.
3. Stop shipping the Telegram bot token in the public remote config — proxy bot messages through a server-side endpoint instead.

None of these require architectural rework — each is a localized fix. Once addressed, the app is in good shape for release: architecture, Firebase integration, permissions, and version hygiene are all solid, and the remaining warnings (code duplication, dead code, missing cert pinning, ProGuard cleanup, unused dependencies) are worth scheduling as fast-follow work but are not release blockers.
