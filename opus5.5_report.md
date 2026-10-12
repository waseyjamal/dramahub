# Drama Hub — Full Diagnosis Report (Opus 5.5)

**Date:** 2026-09-28
**App version:** 1.3.2 (build 15)
**Scope:** YouTube / Rumble / Odysee playback (main focus), the ad system (LevelPlay), and the rest of the app.
**Method:** Read the code line by line (video screen, video controller, ad service, ad config, native ad widget, Android manifest, MainActivity, gradle, ProGuard, data and signing services). Read the source of the installed plugins (`webview_flutter_android 4.12.0`, `unity_levelplay_mediation 9.2.0`). Ran `flutter analyze`. Fetched the live `ad_config.json`, `app_config.json` and all 49 episode files from the CDN, and probed the signing API and the CDN.

> **What was NOT done:** I did not run the app on a device. Anything that needs a real device is marked **[VERIFY ON DEVICE]** with the exact test to do.

---

## 1. Verdict: are YouTube / Rumble / Odysee "top 1%"?

**Short answer: they work, but they are not top 1% yet.** The basic setup is correct. Videos load and play, and the navigation lock-down is done properly. But there are 5 real problems that a top 1% OTT app would not have. All of them are fixable in about a day.

| Area | Status | Score |
|---|---|---|
| Embed HTML + Referer/origin (`baseUrl`) | ✅ Correct: prevents YouTube error 152/153 | 9/10 |
| Navigation lock-down (no escaping to youtube.com etc.) | ✅ Correct: main frame locked; `_blank` pop-ups are dropped | 9/10 |
| Autoplay after tapping the thumbnail | ❌ Blocked by Android WebView default | 4/10 |
| Fullscreen + rotation | ❌ Locked to portrait after the first custom-player fullscreen; back button breaks WebView fullscreen | 4/10 |
| Background audio (app minimised) | ❌ Only the custom player is paused; WebView players are not | 3/10 |
| Error handling / analytics for embeds | ⚠️ Errors inside the iframe are invisible; no `video_played` event | 5/10 |
| Odysee ID encoding | ⚠️ Fragile (`/` gets encoded); no live Odysee episodes to test with | 6/10 |
| **Overall embed players** | **Working, mid-tier** | **~6/10** |

Live content right now: **748 custom (MP4/HLS), 205 YouTube, 1 Rumble, 0 Odysee** episodes. Odysee has never been exercised with production data.

---

## 2. Video players: detailed findings

### V1. 🔴 Autoplay does not fire; the user has to tap twice (YouTube / Rumble / Odysee)
`lib/screens/video_screen.dart:175, 235, 294`

Android WebView defaults to `mediaPlaybackRequiresUserGesture = true`. Tapping the Flutter thumbnail is a Flutter gesture, not a WebView gesture, so `autoplay=1` (and Rumble's `autoplay=2`) is ignored. The user taps the thumbnail, sees the player, and then has to tap **play again**.

**Fix:**
```dart
import 'package:webview_flutter_android/webview_flutter_android.dart';
...
if (webController.platform is AndroidWebViewController) {
  (webController.platform as AndroidWebViewController)
      .setMediaPlaybackRequiresUserGesture(false);
}
```
**[VERIFY ON DEVICE]** Tap the thumbnail on a YouTube episode. Does the video start on its own, or do you have to tap play inside the player?

### V2. 🔴 After one custom-player fullscreen, the whole app is locked to portrait
`lib/widgets/custom_video_player.dart:521-523` and `:587`

When you exit fullscreen on the custom player it calls `setPreferredOrientations([portraitUp])` and **never resets it**. Nothing else in the app resets it either (confirmed with grep). From then on, YouTube, Rumble and Odysee fullscreen **cannot rotate to landscape** for the rest of the session.

**Fix:** on exit, restore with `SystemChrome.setPreferredOrientations([])` (empty list = system default / sensor), or `DeviceOrientation.values`.

**[VERIFY ON DEVICE]** Play a custom episode, go fullscreen and exit. Then open a YouTube episode, tap fullscreen and rotate the phone. It will stay portrait.

### V3. 🔴 WebView fullscreen uses the plugin's default handler (back-button bug, no auto-landscape)
`webview_flutter_android 4.12.0 → android_webview_controller.dart:1283-1301`

You never call `setCustomWidgetCallbacks`, so the plugin pushes a plain `MaterialPageRoute`. Two problems:
1. It does not rotate to landscape or hide the system bars on its own.
2. Pressing Android **back** while in fullscreen pops that route without telling the WebView to exit fullscreen (`onCustomWidgetHidden` is never called). The player can end up in a stuck or black state.

**Fix:** register your own callbacks. On show, push a route wrapped in `PopScope` that calls `onCustomWidgetHidden()` on back, set landscape and `immersiveSticky`. On hide, pop it and restore the orientation.

### V4. 🔴 YouTube / Rumble / Odysee keep playing audio in the background
`lib/screens/video_screen.dart:72-78`

`didChangeAppLifecycleState` only pauses `_customPlayerController`. The WebView is never paused. Android WebView keeps HTML5 media running when the activity pauses unless the app pauses it. Background play of YouTube embeds also **violates YouTube's API Terms**.

**Fix (YouTube):** you already use `enablejsapi=1`, so on pause run:
```js
document.querySelector('iframe').contentWindow.postMessage('{"event":"command","func":"pauseVideo","args":""}','*');
```
**Rumble / Odysee:** the iframe is cross-origin with no public pause API. Blank the iframe on pause (`iframe.src='about:blank'`) and restore it on resume, or show the thumbnail again.

**[VERIFY ON DEVICE]** Play a YouTube episode and press Home. Is the audio still playing?

### V5. 🔴 Custom player: infinite spinner on failure, and the Retry button does nothing (748 episodes affected)
`lib/screens/video_screen.dart:116-119, 461-468, 691-697, 737`

- `_initializePlayer` sets `isPlayerInitialized = true` **before** loading.
- If `initialize()` fails (no network, 403, expired signature), `_handlePlayerError` sets `hasVideoError = true`, but the UI stays on `_HlsPlayer`. There `cpc == null` means a **spinner forever**. The error text only renders in `_ThumbnailPlayer`, which is never shown again.
- Retry (`onRetry: _initializePlayer`) returns immediately because `isPlayerInitialized.value` is still `true`.
- If both `mp4Url` and `streamUrl` are empty, it also returns with `isPlayerInitialized=true` and `hlsLoading=true`, which again means a spinner forever.

**Fix:** in `_handlePlayerError` set `controller.isPlayerInitialized.value = false`. That brings back the thumbnail, the error text and a working "tap to retry". Also guard `_onCustomPlayerUpdate` so `_handlePlayerError` runs only once per error (right now it runs on every listener tick).

### V6. 🟠 Errors inside the iframe are invisible, and embed plays are not tracked
- `onWebResourceError` only fires for the main frame, which is your local HTML. A deleted, private or region-blocked YouTube/Rumble/Odysee video shows the provider's own error page. The app never finds out.
- The `video_played` analytics event is only logged for the custom player (`video_screen.dart:452`). **YouTube, Rumble and Odysee plays are not counted** in Firebase.

**Fix:** log `video_played` with `player_type: youtube|rumble|odysee` when the embed loads. For YouTube you can listen for `onError` / `onStateChange` through the IFrame API with a `JavaScriptChannel`.

### V7. 🟠 Odysee ID encoding is fragile
`video_screen.dart:212` vs `video_controller.dart:285`

- Player: `Uri.encodeComponent(odyseeId)` encodes `@`, `:` **and `/`**. If the admin enters `@channel:x/video-name:y`, the embed URL becomes `…/embed/%40channel%3Ax%2Fvideo-name%3Ay`. Whether Odysee decodes `%2F` is up to their server, which is a risk.
- Download: `https://odysee.com/${odyseeId}` is **not** encoded, so the two paths are inconsistent.
- There are **0 Odysee episodes live**, so this has never been tested with production data.

**Fix:** encode each path segment on its own: `odyseeId.split('/').map(Uri.encodeComponent).join('/')`. Document the one accepted ID format in the admin panel (`name:claimId` or `@channel:x/name:y`).

### V8. 🟡 Rumble notes
- The only live Rumble episode is `boulevard` ep 2, `rumbleId=v7dn4gq`. From my machine, `rumble.com/embed/<any id>/` returns **HTTP 410** (even for a random ID), so Rumble blocks non-browser clients. I could not confirm it from outside. **[VERIFY ON DEVICE]**
- Remember: the Rumble **embed ID is different from the page ID** (`rumble.com/v7dn4gq-title.html` is not the same as `rumble.com/embed/vXXXXX/`). The admin must paste the ID from Rumble's *Embed* dialog. If `v7dn4gq` came from the page URL, it will show "Video not found".
- `sandbox` without `allow-popups` is a good choice, because it blocks Rumble pop-up ads.

### V9. 🟡 Smaller player issues
- `immersiveSticky` is enabled on a normal portrait, scrollable page for WebView players (`video_screen.dart:209/269/328`). The status bar disappears while browsing the episode list, and the custom player does not do this. It is inconsistent. Only use immersive in fullscreen.
- `dispose()` calls `_autoSaveProgress()` **after** `_customPlayerController.dispose()`, and the 10-second throttle can drop the last ≤10 s of progress. Save first with a `force` flag, then dispose.
- The episode-list tap calls `Get.delete<VideoController>(force: true)` while the current screen is still mounted and using that controller. It works today, but it is fragile. A cleaner approach is `Get.offNamed(..., preventDuplicates: false)` with a tag per episode.

### ✅ What is done right (keep it)
- `loadHtmlString(..., baseUrl: 'https://dramahubs.stream/')` gives YouTube a valid Referer/origin. This is exactly how to avoid the 2025 "Error 153 / video player configuration" problem.
- `onNavigationRequest` whitelists only the embed hosts for the main frame. Subframe navigation is left to the iframe, which is correct because the plugin only asks for main-frame requests.
- `setSupportMultipleWindows(true)` without an `onCreateWindow` handler means `target=_blank` links ("Watch on YouTube", logo) silently do nothing. Users can't leave the app.
- `FLAG_SECURE` on the video screen, with the flag cleared again in `onClose`.

---

## 3. Ads (LevelPlay): detailed findings

Live config (`ad_config.json`): interstitial on for continue_watching / episodes / video / upcoming / watchlist / history / suggest / report, **15-minute cooldown, max 3 per session**. Rewarded on **no** screens. Download rewarded **on**. Offline ads **on (rewarded)**. Native **on** for 5 screens.

### A1. 🔴 Rewarded callback fires TWICE when the user closes the ad early (or when show fails)
`lib/services/ad_service.dart:275-289, 295, 421-439, 489-505`

Path for a user who skips the rewarded ad:
1. `onClosed` → `rewardGranted == false` → **`onNotAvailable()` is called (1st time)**
2. The completer returns `false`, so `showRewardedForScreen` / `showRewardedForDownload` thinks nothing was shown, falls through, and calls **`onNotAvailable()` again (2nd time)**.

The same double call happens on `onShowFailed` and when `showAd()` throws.

**Impact today:** the download ad is enabled. A user who skips it gets the **VidBlaze share intent launched twice**. In-app MP4 download is protected by `isDownloading()`. If you ever enable rewarded on `episodes_screen`, a skip will **push two Video screens** (`Get.toNamed` twice), and the second `Get.delete<VideoController>` kills the first screen's controller.

**Also:** a skipped rewarded ad is not counted (`_rewardedShownCount` / `_lastRewardedTime` are not updated), so **cooldown and max-per-session don't apply to skipped ads**. The next tap shows another ad right away.

**Fix:** make `_tryShowRewarded` return a small result: `notShown | shownRewarded | shownNotRewarded`. Call the user callback exactly once, in one place, and count any *displayed* ad toward caps.

### A2. 🔴 Show timeouts are shorter than real ads, which releases the guard while the ad is still on screen
`ad_service.dart:237-244` (interstitial 30 s), `:301-308` (rewarded 60 s)

Video interstitials (30 s + end card) and rewarded ads (30 s + end card + user dwell) regularly go past these limits. When the timeout fires:
- `_adCurrentlyShowing = false` while the ad is still visible, so another ad can be triggered.
- For **offline ads (rewarded, live)**, `onComplete()` runs and **opens the offline player underneath the ad**. The episode starts playing behind it.
- For rewarded, the outer code calls `onNotAvailable`, and **later** `onClosed` / `onRewarded` fires again. That is another double navigation.

**Fix:** only time out if `onAdDisplayed` hasn't arrived within about 5 s. Once displayed, wait for `onAdClosed` with no timeout, or with a very long safety timeout such as 5 minutes.

### A3. 🟠 Ad objects are never disposed (native leak)
`ad_service.dart:96-97, 118-119`

Every reload creates a new `LevelPlayInterstitialAd` / `LevelPlayRewardedAd`. The plugin exposes `dispose()` (`level_play_interstitial_ad.dart:63`), but it is never called. Each load/show cycle leaks a native ad object. Call `await _interstitialAd?.dispose()` before replacing it, or better: **reuse one ad object** and just call `loadAd()` again, which the LevelPlay 8+/9 API supports.

### A4. 🟠 SDK version mismatch
- Flutter plugin `unity_levelplay_mediation 9.2.0` is compiled against **native `mediation-sdk:9.4.0`**.
- `build.gradle.kts` forces **`mediation-sdk:9.6.0`**.

Minor-version bridge drift can break things quietly (listener signatures, native ad API). Either upgrade the Flutter plugin to the version that ships with 9.6.x, or pin native to 9.4.0. Check every adapter (Unity 5.12.0, Chartboost 5.9.0, InMobi 5.9.0, Vungle 5.14.0) against the official **LevelPlay adapter compatibility table** for the chosen SDK version. I could not confirm that table offline.

### A5. 🟠 No privacy consent / regulation signals
There is no `setConsent` (GDPR), no CCPA `do_not_sell` metadata and no COPPA flag. For EEA/UK users many networks serve no ads or only low-paid non-personalised ads, and Google/Unity policies require consent collection there. Add Google UMP (or another consent tool) plus `LevelPlay.setConsent(...)` / `setMetaData(...)` **before** `LevelPlay.init`.

### A6. 🟡 Other ad items
- **Retry stops forever** after 4 attempts (10/30/60/120 s) until the app is resumed. On a flaky network the user can go a whole session with no fill. Keep a slow retry (every 5 min) running.
- **Interstitial fires 1 s after opening an episodes screen** (`episodes_controller.dart:51`). If the user taps an episode within that second, the interstitial appears **on top of the video screen** as it starts. Cancel the delayed call when the user navigates.
- **`every_nth_card` is unused.** Every screen has exactly one native slot. The config value does nothing.
- **Native `ad_unit_id` is empty** in the live config, so all native ads report under the default placement. You can't compare screens in the LevelPlay dashboard. Pass `screenKey` as the placement name.
- **App Open**: config says `enabled: true, provider: "yandex"`, but `showAppOpen()` is an empty no-op and Yandex was removed. Set it to `false` in the admin panel to avoid confusion.
- `AdService` is `Get.put` twice (`main.dart:43` and `initial_binding.dart:22`). GetX keeps the first one, so it's harmless, but remove the second.
- `InMobiAdActivity` is declared by hand in the manifest. The adapter's own manifest already merges it, so remove the manual one to avoid attribute conflicts on adapter updates.
- No **LevelPlay test suite / integration validation** in debug builds. Add `LevelPlay.launchTestSuite()` behind a hidden debug gesture so you can check every network's fill on a real device.

### ✅ Ads: what is done right
- The remote-config-driven design (per-screen switches, cooldowns, session caps, cache of the last good config) is solid and flexible.
- The 8 s startup grace period, the global `_adCurrentlyShowing` guard, and backoff retries are all good practice.
- The 15-minute interstitial cooldown with max 3 per session is user-friendly and keeps retention healthy.

---

## 4. Full-app findings (outside video and ads)

### S1. 🔴 CRITICAL SECURITY: Telegram bot token is publicly downloadable
`https://dramahub-data.pages.dev/app_config.json` contains `telegram_bot_token` (46 chars, confirmed present) and `telegram_chat_id`. Anyone can fetch it without auth. With that token they can call `getUpdates` to read every problem report and drama suggestion (with user contact details), spam your chat, or change the bot's settings.

**Action now:** revoke the token in @BotFather, then send form submissions through your Deno server (which already exists for signing) so the token lives only server-side.

### S2. 🔴 Signing API has no authentication
`https://high-crab-4265…deno.net/?dramaId=X&ep=N&type=download` returned a valid signed URL to a plain `curl` with no credentials. Your CDN correctly returns **403** for unsigned MP4s, which is good, but anyone who reads `episodes/*.json` can mint 6-hour download links for your whole catalogue.

**Fix:** you already sign in with Firebase anonymous auth. Send the Firebase ID token (or better, a **Firebase App Check** token) in the header and verify it in Deno. Add rate limiting per IP / per user.

### S3. 🟠 Async errors are not reported to Crashlytics
`main.dart:33` sets only `FlutterError.onError`. There is no `PlatformDispatcher.instance.onError` handler, so uncaught async errors (most errors in this codebase) never reach Crashlytics.
```dart
PlatformDispatcher.instance.onError = (e, s) {
  FirebaseCrashlytics.instance.recordError(e, s, fatal: true);
  return true;
};
```

### S4. 🟠 Startup can hang on a slow network
`main.dart:28` runs `await FirebaseAuth.instance.signInAnonymously()` with **no timeout**, before everything else. On a poor 2G/3G link the splash can sit there for tens of seconds. Add `.timeout(const Duration(seconds: 3))` or move it into `_initializeInBackground()`.

### S5. 🟠 Data fallback doesn't catch JSON errors (`flutter analyze` warnings)
`lib/services/data_service.dart:42, 47, 62, 97, 150, 176`: `return compute(...)` inside `try` **without `await`**. If `dramas.json` is ever malformed (a bad admin save), the parse exception skips the `catch`. The local-asset fallback never runs and the home screen fails. Change to `return await compute(...)`.

### S6. 🟠 Content / data problems found in live data
- **`askvetahturdu`** is listed in `dramas.json`, but `episodes/askvetahturdu.json` returns **404**. Users see an empty drama.
- **`sevdigim sensin`** has a **space** in its drama ID and in its HLS URL (`…/sevdigim sensin/ep-42/index.m3u8`). It works today because Dart encodes it, but spaces in IDs and URLs break sharing, caching keys and some CDNs. Rename it to `sevdigim-sensin`.

### S7. 🟡 Hygiene / polish
- **Launcher name is `drama_hub`** (`AndroidManifest.xml:12`, `android:label="drama_hub"`). Users see "drama_hub" under the icon. Change it to `Drama Hub`.
- **Line endings:** `git diff` shows around 5,500 changed lines, but only about 590 are real changes. The rest is CRLF/LF churn. Add a `.gitattributes` with `* text=auto eol=lf` and renormalise once, otherwise reviews and blame become useless.
- `forceUpdate: true` with `latestVersion: 15` in the live config. That's correct for build 15, but remember to bump both together on every release or every user gets a blocking dialog.
- The root-device warning shows on every cold start with no "don't show again". It annoys users with custom ROMs.
- Lint infos: missing braces (`video_controller.dart:84`, `video_screen.dart:147`, `signing_service.dart`), deprecated `cacheExtent` (`watchlist_screen.dart:120`).

---

## 5. Priority fix list

| # | Fix | Effort | Impact |
|---|---|---|---|
| 1 | **Revoke the Telegram bot token** and move it server-side (S1) | 1 h | Security: critical |
| 2 | Rewarded double callback + skipped ads not counted (A1) | 1–2 h | Bugs, ad caps |
| 3 | Ad show timeouts → wait for display, then close (A2) | 1 h | Offline player opening under the ad |
| 4 | Custom player infinite spinner / dead retry (V5) | 30 min | 748 episodes |
| 5 | Reset orientation after custom fullscreen (V2) | 5 min | All fullscreen |
| 6 | `setMediaPlaybackRequiresUserGesture(false)` (V1) | 10 min | One-tap play |
| 7 | Pause WebView players on background (V4) | 1 h | YouTube ToS + UX |
| 8 | Custom WebView fullscreen callbacks (V3) | 1–2 h | Fullscreen UX |
| 9 | Authenticate the signing API with App Check (S2) | 2–3 h | Content protection |
| 10 | `PlatformDispatcher.onError` + auth timeout (S3, S4) | 15 min | Stability visibility |
| 11 | `await compute` in data_service (S5) | 5 min | Resilience |
| 12 | Align LevelPlay SDK/adapters; dispose ad objects (A3, A4) | 1–2 h | Stability, memory |
| 13 | Consent (UMP + LevelPlay) (A5) | 2–3 h | Revenue in EEA, compliance |
| 14 | Embed analytics + Odysee encoding (V6, V7) | 1 h | Insight, robustness |
| 15 | Data fixes: askvetahturdu 404, ID with space, app label (S6, S7) | 15 min | Polish |

After fixes 2–8, the YouTube / Rumble / Odysee experience would honestly be in the **top tier**: one tap to play, proper landscape fullscreen, back button that behaves, no background audio, and working error recovery.

---

## 6. Device test checklist (run after fixes)
1. YouTube episode: one tap starts playback. Fullscreen rotates to landscape. Back exits fullscreen cleanly. Home button stops the audio.
2. Rumble (`boulevard` ep 2): plays, fullscreen works, no pop-ups.
3. Odysee: add one test episode with a `@channel:x/name:y` ID and check that it plays.
4. Custom episode in airplane mode: the error message appears and "tap to retry" works after reconnecting.
5. Custom fullscreen, exit, then a YouTube fullscreen: it can still rotate.
6. Download on a YouTube episode, then skip the rewarded ad: VidBlaze opens **once**.
7. Offline play with a long rewarded ad (wait more than 60 s on the end card): the player must **not** start under the ad.
8. LevelPlay test suite: every network initialises and fills on a real device.
