# Drama Hub — Ads System Diagnosis Report
Generated: 2026-08-26

## Executive Summary

**Overall ads health score: 62/100**
**Estimated network-level fill rate ceiling: ~85-90%** (theoretical, based on mediation breadth)
**Estimated real-world realized fill rate: ~60-70%** (after accounting for client-side reliability bugs below)
**Estimated revenue efficiency: ~55%** of what this mediation stack should be producing

The app has a genuinely strong mediation waterfall (13 demand partners behind Yandex Ads) and sensible ad-trigger placement at natural break points (screen opens, episode transitions, tab switches, video completion). However, three structural issues cap real-world revenue well below what the network breadth suggests:

1. **Fail-closed remote config**: every ad format defaults to `enabled: false` when the 3-second remote config fetch is slow or fails — meaning a slow/flaky network connection on cold start (very common in the app's target markets: RU/CIS, South/Southeast Asia, per the mediation partners chosen) results in **zero ads for the entire session**, not degraded ads.
2. **No load-retry/backoff**: if an interstitial/rewarded/app-open ad fails to *load* (not just fails to *show*), it is never retried until the app is backgrounded and resumed. One transient network blip permanently empties that ad slot for the rest of the session.
3. **A rewarded-ad race bug** that can silently strand the UI (see Issues Found, Critical #1).

LevelPlay/IronSource is fully commented out but still referenced as the default `priority_1` provider for every ad type in the remote config's fallback schema — meaning on config-fetch failure, priority 1 is dead code and priority 2 (Yandex) is also disabled by default. Net effect: no ads at all until remote config successfully loads.

This is a "good bones, weak reliability layer" system — fixing the preload/retry/fallback layer (Section 8 below) is the single highest-leverage change available.

---

## Ad Architecture Analysis

**Pattern**: `AdService` (GetX singleton, `lib/services/ad_service.dart`) is a thin waterfall orchestrator sitting above per-network services. Today only one real network service exists — `YandexService` (`lib/services/yandex_service.dart`) — since LevelPlay/Unity mediation was fully commented out (marked "restore by uncommenting all `[LEVELPLAY]` blocks").

**Initialization order** (`lib/main.dart`):
1. `YandexAds.initialize()` (Yandex SDK core) — called synchronously before anything else touches ads. Correct.
2. `Get.put(YandexService(), permanent: true)` registered before `Future.wait`.
3. Inside `Future.wait([...])`: `AppConfigService.loadConfig()`, `AdConfigService.instance.initialize()` (remote ad config fetch, 3s timeout), and `YandexService.instance.initEarly()` (also 3s timeout) all run **in parallel**.
4. `AdService` itself is registered later, in `InitialBinding` (`lib/bindings/initial_binding.dart:23`), not in `main.dart`. It has no meaningful `onInit()` work beyond recording `_appStartTime`/`_sessionStartTime`, so the registration-order gap is harmless — but note `AdService` reads `AdConfigService.instance.config` lazily on every call via a getter, so it is not sensitive to init timing itself.

**Waterfall model**: Every ad type (`interstitial`, `rewarded`, `download`, `offline`) has an independent `priority1`/`priority1Enabled`/`priority2`/`priority2Enabled` pair driven entirely by remote config. `AdService._tryShowInterstitial`/`_tryShowRewarded` dispatch by provider string (`'levelplay'` or `'yandex'`); the `'levelplay'` branch is fully commented out, so any config that routes to `levelplay` silently falls through to `return false`. This is intentional per the code comments (kill-switch for a mediation SDK that was removed), but it means the *default* fallback config (used whenever remote fetch fails) is effectively non-functional for ads (see Configuration Audit).

**Caching strategy**: single ad instance per format (interstitial/rewarded/app-open), preloaded at startup, reloaded once after each show/show-failure. This is the standard "single ad slot" pattern used by most mid-market apps — see Section 8 for where it falls short of top-1% behavior.

**Error handling**: every load call is wrapped in try/catch + `.catchError`, and every show path has `onAdFailedToShow` handling that resets state and reloads. Genuinely solid *within a single load-fail path* — the gap is the complete absence of retry scheduling.

---

## Yandex Integration

- **SDK init correctness**: `YandexAds.initialize()` is called once, synchronously, before Firebase-driven UI or ad loads — correct order per Yandex's docs.
- **Ad unit IDs**: distinct real IDs for interstitial (`R-M-19564249-1`), rewarded (`R-M-19564249-2`), app open (`R-M-19564249-8`), and five screen-specific banners (`R-M-19564249-9` through `-13`). **Bug**: `download_screen` and `upcoming_screen` banners both use `R-M-19564249-13` (see Configuration Audit — duplicate ad unit ID).
- **Debug/demo swap**: `kDebugMode` correctly swaps every real ad unit ID for Yandex's official demo IDs (`demo-interstitial-yandex`, etc.) — good practice, prevents accidental test-ad-unit-ID review-rejection risk and accidental invalid-traffic on real IDs during development.
- **Ad request lifecycle**: load → ready flag flips → show on demand → `destroy()` on the used instance → immediately reload. Consistent across interstitial/rewarded/app-open. `onClose()` on the service destroys any live ad objects — no leak there.
- **App Open handling** is the most complex piece: it tracks `_navigationOccurred`, `_returnedFromBackground`, `_hasShownThisSession`, a 5-second post-ad-close cooldown, and a configurable cooldown between app-open impressions, plus a 60-second "stuck lock" safety timer in case `onAdDismissed` never fires. This is notably more mature than the interstitial/rewarded paths and reads as a deliberate fix for a prior stuck-app-open bug (comment: "✅ FIX 4").

---

## Mediation Networks Analysis

Configured in `android/app/build.gradle.kts` as Yandex mediation adapters:

| Network | Status | Estimated Fill Rate Contribution | Notes |
|---|---|---|---|
| Yandex Ads (house/direct) | Active | 15–25% (strong in RU/CIS, weaker elsewhere) | Base network; all 3 formats route through it directly |
| Google AdMob | Active (adapter present, manifest App ID configured) | 40–60% (highest single-network fill globally) | Correctly declared in `AndroidManifest.xml` (`com.google.android.gms.ads.APPLICATION_ID`) |
| Mintegral | Active | 10–20% (Asia/South Asia) | No manifest entries required via mediation passthrough |
| VK Ads (myTarget) | Active | 10–20% (RU/CIS) | Yandex-ecosystem partner, typically best Yandex-side fill |
| AppLovin | Active | 10–20% (global, premium demand) | Config is server-side in Yandex console |
| BIGO Ads | Active | 5–15% (Southeast Asia) | — |
| Chartboost | Active | 5–10% (gaming-skewed; lower relevance for a drama-streaming app) | — |
| InMobi | Active | 10–15% (global) | Manifest activity correctly declared (`InMobiAdActivity`) |
| IronSource | Active (as a demand adapter via Yandex, distinct from the removed LevelPlay Unity SDK) | 5–15% | Do not confuse with the commented-out LevelPlay/Unity mediation stack — this is a separate integration path |
| Pangle (ByteDance) | Active | 10–20% (Asia) | — |
| Start.io | Active | 5–10% (performance/CPI-leaning) | — |
| Tapjoy | Active | 5–10% (rewarded/offerwall niche) | Best paired with the rewarded format specifically |
| Liftoff/Vungle | Active | 10–15% (video/rewarded) | — |
| UnityAds | Active | 5–15% | Via Yandex mediation, not the removed LevelPlay SDK |

**13 demand partners behind Yandex's own network is a genuinely strong waterfall** — comparable to what top-decile monetized apps run. The caveat is that actual **fill rate, eCPM floors, and waterfall order are configured server-side in the Yandex Ads console**, which is invisible from the codebase. This report can confirm the *client-side plumbing* is present and correctly declared; it cannot confirm the *console-side waterfall configuration* is optimal.

## Fill Rate Calculation

Aggregate fill rate for a mediation waterfall is `1 − ∏(1 − fill_i)` across all networks queried, not additive. Using the midpoint of each estimate above:

- Combined theoretical network-level fill (assuming console-side waterfall is reasonably configured): **~85–90%**
- This is discounted by client-side reliability issues that prevent an otherwise-available ad from ever being requested or shown:
  - Fail-closed remote config defaults (Configuration Audit): during any session where the 3s config fetch is slow/fails, effective fill = **0%** for that session, regardless of network-level fill. Given a 3-second cap and this app's likely target markets (network variability in RU/CIS and South/Southeast Asia), this plausibly affects a non-trivial single-digit-to-low-double-digit percentage of sessions.
  - No load-retry after a failed preload (Section 8): any transient failure permanently empties a slot for the rest of a session.
- **Estimated real-world realized fill rate: ~60–70%**, i.e., roughly 20–25 points below the network-level ceiling, purely due to client-side reliability gaps rather than actual demand-side fill.

---

## Ad Trigger Points Audit

| Screen / Action | Format | Trigger | Assessment |
|---|---|---|---|
| Home screen open | Interstitial (`home_screen`) | 2s delay after `initState` | ✅ Reasonable — gives the UI a beat to render first |
| "Continue watching" tap | Interstitial (`continue_watching`) | `home_controller.dart:363`, on tap | ✅ Natural break point |
| Episodes screen open | Interstitial (`episodes_screen`) | 1s delay, skippable via `skipAd`/`autoPlayEpisode` args | ✅ Correctly suppressed when auto-playing (avoids double-ad on deep link) |
| Episode → next episode | Rewarded (`episodes_screen`) | `goToNextEpisode()` / episode-list tap in video screen | ✅ Rewarded (not interstitial) is the right format for a user-driven continue action |
| Video ends | Interstitial (`video_screen`) | On playback completion | ✅ Best possible placement — natural content break, doesn't interrupt viewing |
| Offline playback (mature downloads) | Rewarded or Interstitial (configurable `offline_ads.ad_type`) | On opening a download older than `maturity_minutes` | ✅ Clever monetization of otherwise ad-free offline viewing, gated by content "maturity" to avoid nagging on fresh downloads |
| Download start (streamed & YouTube) | Rewarded (`download` config) | `goToDownload()` / `goToYoutubeDownload()` | ✅ Rewarded before a value-exchange (download) is a standard, user-tolerated pattern |
| Watchlist tab switch | Interstitial (`watchlist_screen`) | 1s delay on tab tap | ✅ |
| History tab switch | Interstitial (`history_screen`) | 1s delay on tab tap | ✅ |
| Watchlist card tap | Rewarded (`watchlist_screen`) | On tap, before navigating to episodes | ⚠️ Borderline — stacking a rewarded gate on watchlist taps *and* an interstitial on the watchlist tab switch risks feeling ad-heavy in a single navigation flow (tab → list → card, potentially 2 ad opportunities back to back) |
| Download screen open | Interstitial (`download_screen`) | 1s delay | ✅ |
| Suggest drama / Report problem submit | Interstitial | On submit | ✅ Low-frequency, tolerable placement |

**Configured but never triggered** (present as keys in the remote config schema's default `screens` maps for both interstitial and rewarded, but no call site anywhere in `lib/`):
- `profile_screen`
- `premium_screen`
- `rate_app_screen`

These are dead config — remote config can toggle them on, but nothing will ever show because no screen calls `showInterstitialForScreen('profile_screen')` etc. This is either an unfinished feature or a missed monetization surface (profile/rate-app screens are typically low-friction interstitial placements).

**Over-aggressive placement risk**: none of the individual placements look abusive in isolation, but the watchlist tab-switch + watchlist-card-tap combination (both above) is worth a second look — a user browsing their watchlist could hit two separate ad decision points within a few seconds.

---

## Revenue Optimization Recommendations

1. **Fix the preload/reliability layer first** (Section 8) — this is worth more than any placement or format change, since a broken preload pipeline zeroes out revenue regardless of how well-placed the triggers are.
2. **Wire up `profile_screen`, `premium_screen`, `rate_app_screen`** interstitial/rewarded placements, or remove them from the config schema if intentionally unused — dead config is a maintenance trap for whoever edits the remote JSON next.
3. **Add a native/in-feed ad format for list screens.** `NativeAdConfig` (`every_nth_card`) exists in the model but `YandexBannerAdWidget` never uses `everyNthCard` — it renders a single static banner per screen, not a recurring in-feed unit. True native-in-feed ads (inserted every Nth grid item on Home/Watchlist/History) typically carry meaningfully higher eCPM than a single banner and are a real gap given the model already has the config field for it.
4. **Fix the duplicate banner ad unit ID** (`download_screen` and `upcoming_screen` both map to `R-M-19564249-13`) — this conflates reporting/optimization for two different screens under Yandex's dashboard and may suppress independent eCPM-floor tuning per screen.
5. **Reconsider the 3-second remote-config timeout.** Either raise it, or — better — persist the last successfully-fetched config to local storage (`shared_preferences`) and fall back to *that* instead of the current hardcoded all-disabled `AdConfigModel.defaults()`. This alone likely recovers a meaningful share of the "0% fill this session" cases described above.
6. **Add a periodic re-check/retry timer** for ad loads that fail (see Section 8) instead of relying solely on background/foreground cycling to recover.
7. **Consider tightening the watchlist double ad-touchpoint** (tab switch + card tap) via frequency capping shared across both triggers, or drop one of them.
8. **Clean up dead `app_config.json` ad fields** (`interstitialEnabled`, `rewardedEnabled`, `maxInterstitialPerSession`, `interstitialCooldownSeconds`) — see Configuration Audit; leaving them in place risks a future editor assuming they do something.

---

## Configuration Audit

**`assets/data/app_config.json`**: contains `interstitialEnabled`, `rewardedEnabled`, `maxInterstitialPerSession: 5`, `interstitialCooldownSeconds: 60`. **None of these four fields are referenced anywhere in `lib/`** — they are fully superseded by the remote `ad_config.json` fetched through `AdConfigService`, which has its own (different!) defaults — `max_per_session: 3`, `cooldown_seconds: 30`. This is dead, misleading configuration: editing `app_config.json`'s ad fields has zero effect on actual ad behavior.

**Ad unit ID audit**:
- Interstitial / Rewarded / App Open: three distinct real IDs (`-1`, `-2`, `-8`). No duplication.
- Banners: `download_screen` and `upcoming_screen` **share `R-M-19564249-13`** — duplicate, should be split into two distinct ad units for independent reporting/eCPM tuning.
- `NativeAdConfig` carries its own `adUnitId` field that is **never populated or read** by `YandexBannerAdWidget` (the widget uses its own hardcoded `_adUnitIds` map instead) — dead field in the model.

**Remote ad config fail-safe behavior**: every top-level ad-format `enabled` flag defaults to `false` in `AdConfigModel.defaults()` (`interstitial`, `rewarded`, `download`, `offline_ads`, `app_open`, `native` are all `enabled: false` by default; only `ads_enabled` itself defaults `true`). Combined with `priority_1` defaulting to `'levelplay'` (dead code) and `priority_2` (`'yandex'`) defaulting `priority_2_enabled: false`, the practical effect is: **on any remote-config fetch failure or 3-second timeout, the app shows zero ads of any format for the entire session.** This is a safe *design* (never show something broken) but an expensive *default* (silently zero revenue rather than degrade gracefully) — see Recommendation #5.

---

## Issues Found

### Critical
1. **Rewarded-ad re-entrancy bug returns a false "success" without granting reward or resuming the UI.** In `YandexService.showRewardedFallback()` (`lib/services/yandex_service.dart:208-210`):
   ```dart
   if (_rewardedShowing) {
     return true;
   }
   ```
   If `showRewardedFallback` is called while a rewarded ad is already mid-show (e.g., a double-tap on "next episode" or "download", or two trigger paths firing close together), it returns `true` immediately **without calling `onRewarded` or `onNotAvailable`**. The caller (`AdService._tryShowRewarded` → `showRewardedForScreen`/`showRewardedForDownload`) treats `true` as "ad shown," increments the session counter and cooldown timer, and returns — but since neither callback fires, the pending user action (episode navigation, download start) **never happens**, and any loading flag the caller set (e.g., `isDownloadLoading.value = true` in `video_controller.dart`) can be left stuck `true` since the `finally` block runs, but the promised navigation/download itself silently never occurs on this reentrant path. Recommend either queuing the second request behind the in-flight completer, or returning `false` so the caller's `onNotAvailable` fallback path runs instead.

2. **No retry/backoff on ad *load* failure** — see Section 8 for full detail. A single transient load failure permanently empties that ad slot until the app is backgrounded and foregrounded again.

3. **Fail-closed default ad config zeroes all formats on remote-config fetch failure** — see Configuration Audit. Not a code bug per se, but a design choice with an expensive failure mode that silently costs 100% of a session's ad revenue.

### Warning
4. **Duplicate banner ad unit ID** shared between `download_screen` and `upcoming_screen` (`R-M-19564249-13`).
5. **Dead ad config in `app_config.json`** (`interstitialEnabled`, `rewardedEnabled`, `maxInterstitialPerSession`, `interstitialCooldownSeconds`) — unused, misleading.
6. **`profile_screen` / `premium_screen` / `rate_app_screen`** are present in the remote config's screen-toggle schema but have no corresponding call site — dead config / missed placement.
7. **`NativeAdConfig.everyNthCard` and `NativeAdConfig.adUnitId` are unused** by the only consumer (`YandexBannerAdWidget`), which hardcodes its own per-screen ID map and renders a single static banner rather than a recurring in-feed unit. The model promises capability the UI doesn't implement.
8. **Watchlist screen has two independent ad touchpoints** (tab-switch interstitial + card-tap rewarded) that could stack within one short user flow.

### Info
9. LevelPlay/Unity mediation is fully commented out but still the hardcoded `priority_1` default for every ad format — harmless today (falls through safely to `return false`), but a latent trap if someone re-enables `priority_1_enabled` remotely without realizing the provider is dead code.
10. Yandex's IronSource mediation *adapter* (`mobileads-ironsource`) is a separate integration from the removed LevelPlay/Unity IronSource SDK — worth a one-line comment in `build.gradle.kts` to avoid future confusion about "isn't IronSource already removed?"

**No dispose/memory-leak issues found** — `YandexService.onClose()` destroys all three ad instances; `YandexBannerAdWidget.dispose()` correctly cancels both stream subscriptions and destroys its banner. **No thread-safety issues found** — all ad code runs on the Dart UI isolate via standard async/await; no shared mutable state is touched from a background isolate.

---

## Preload & Caching Strategy — CRITICAL Analysis (Top Priority)

Rated against the top-1% standard specified in the brief:

| Top-1% standard | This app | Verdict |
|---|---|---|
| Preload next ad immediately after current ad is shown | ✅ `onAdDismissed`/`onAdFailedToShow` call `_loadInterstitial()`/`_loadRewarded()` again immediately | **Pass** |
| Maintain a ready ad in memory at all times | ⚠️ Only true *if* every load attempt succeeds. One failed load with no retry leaves the slot empty for the rest of the session | **Partial fail** |
| 3-layer fallback: preloaded → reload → skip | ❌ Only 2 layers exist: preloaded → skip. There is no "try a fresh load and wait briefly" step when a trigger fires and the ad isn't ready — `showInterstitialFallback`/`showRewardedFallback` return `false` immediately if not ready, with no on-demand reload attempt | **Fail** |
| Never show a loading spinner before an ad | ✅ Confirmed — every path either shows instantly or silently calls `onNotAvailable`/falls through; no blocking spinner anywhere in the ad code | **Pass** |
| Preload on app launch before user reaches any screen | ✅ `YandexService.initEarly()` runs inside `main()`'s `Future.wait`, before `runApp()` | **Pass** |
| Auto-reload on ad expiry | ❌ No expiry tracking at all. Yandex/AdMob-backed ads typically expire ~1 hour after load; there is no timestamp check before `show()`, so an expired ad's failure is only discovered at show-time (via `onAdFailedToShow`), costing that impression entirely, with no pre-emptive refresh | **Fail** |
| Retry mechanism with backoff | ❌ None exists anywhere in `ad_service.dart` or `yandex_service.dart`. The only "retry" is the reload-after-show(-failure) path; a load-time failure (`.catchError` in `_loadInterstitial`/`_loadRewarded`/`_loadAppOpen`) sets the ready flag to `false` and does nothing else | **Fail** |
| Multiple ad formats preloaded simultaneously | ✅ Interstitial, rewarded, and app-open are all kicked off together in `initEarly()` — not sequential | **Pass** |

### Rating: **4/10 against top-1% standard**

Half the checklist passes (initial preload timing, parallel format loading, no spinners, immediate reload-after-show) — the architecture's *shape* is right. But every failure-recovery mechanism is missing: no retry backoff, no expiry handling, and no reload-and-wait-briefly fallback at request time. This is exactly the gap the brief flagged as top priority, and it's also where the "fail-closed remote config" issue compounds the damage — a session can go from "network hiccup during splash" to "zero ads all session" with no self-healing in between.

### Exact code-level fixes

**1. Add retry-with-backoff to every load path.** Example for interstitial in `lib/services/yandex_service.dart` (apply the same pattern to `_loadRewarded` and `_loadAppOpen`):

```dart
int _interstitialRetryAttempt = 0;
Timer? _interstitialRetryTimer;
static const List<int> _retryBackoffSeconds = [10, 30, 60, 120];

void _loadInterstitial() {
  if (!_initialized) return;
  _interstitialRetryTimer?.cancel();
  try {
    final loader = InterstitialAdLoader();
    loader.loadAd(
      adRequest: AdRequest(
        adUnitId: kDebugMode ? 'demo-interstitial-yandex' : _interstitialAdUnitId,
      ),
    ).then((ad) {
      _interstitialAd = ad;
      _interstitialReady = true;
      _interstitialRetryAttempt = 0; // reset backoff on success
      if (kDebugMode) debugPrint('✅ Yandex Interstitial loaded');
    }).catchError((e) {
      _interstitialReady = false;
      _scheduleInterstitialRetry();
      if (kDebugMode) debugPrint('❌ Yandex Interstitial load failed: $e');
    });
  } catch (e) {
    _interstitialReady = false;
    _scheduleInterstitialRetry();
    if (kDebugMode) debugPrint('❌ Yandex Interstitial load error: $e');
  }
}

void _scheduleInterstitialRetry() {
  final delay = _retryBackoffSeconds[
      _interstitialRetryAttempt.clamp(0, _retryBackoffSeconds.length - 1)];
  _interstitialRetryAttempt++;
  _interstitialRetryTimer = Timer(Duration(seconds: delay), _loadInterstitial);
}
```
Cancel `_interstitialRetryTimer` in `onClose()` alongside the existing `destroy()` calls.

**2. Add expiry tracking so a stale ad is refreshed before it's ever attempted.**
```dart
DateTime? _interstitialLoadedAt;
static const Duration _adMaxAge = Duration(minutes: 55);

bool get _interstitialExpired =>
    _interstitialLoadedAt != null &&
    DateTime.now().difference(_interstitialLoadedAt!) > _adMaxAge;
```
Set `_interstitialLoadedAt = DateTime.now();` in the `.then((ad) { ... })` success branch. Then in `showInterstitialFallback()`, add at the top:
```dart
if (_interstitialExpired) {
  _interstitialReady = false;
  _loadInterstitial();
}
```

**3. Add a genuine 3rd fallback layer (preloaded → short reload-and-wait → skip)** in `AdService._tryShowInterstitial`/`_tryShowRewarded` — if the primary provider isn't ready, trigger a fresh load and give it a short (e.g., 2–3s) window to complete before giving up, instead of failing instantly:
```dart
Future<bool> _tryShowInterstitial(String provider) async {
  if (provider == 'yandex' && _cfg.config.adNetworks.yandexEnabled) {
    final shown = await YandexService.instance.showInterstitialFallback();
    if (shown) return true;
    // Layer 3: one short reload-and-wait before giving up
    return YandexService.instance.reloadAndWaitInterstitial(
      const Duration(seconds: 3),
    );
  }
  return false;
}
```
with a corresponding `reloadAndWaitInterstitial(Duration timeout)` in `YandexService` that calls `_loadInterstitial()` and awaits the ready flag (or a completer resolved in the load's `.then`) up to `timeout`.

**4. Fix the fail-closed remote config** by caching the last good config to `SharedPreferences` and falling back to *that* (not the hardcoded all-`enabled: false` defaults) when a fetch fails — directly addresses the "0% fill this session" failure mode described in Fill Rate Calculation and Configuration Audit.

**5. Fix the rewarded re-entrancy bug** (Critical Issue #1) — replace the bare `return true;` with either awaiting the existing completer or returning `false` so the caller's `onNotAvailable` path fires and the UI doesn't stall.

---

## Final Verdict

**Needs fixes before this qualifies as a top-tier monetization setup.** The mediation breadth and ad-trigger placement are already solid — this is not a "rebuild it" situation. But the preload/reliability layer (Section 8) and the fail-closed remote config default (Configuration Audit) are actively costing measurable revenue today, silently, with no visibility into how often they trigger. Prioritize, in order: (1) the rewarded re-entrancy bug, (2) retry-with-backoff on ad load failure, (3) caching the last-good remote config instead of failing to an all-disabled default, (4) ad expiry handling. These four changes directly target the gap between the ~85–90% theoretical fill this mediation stack should achieve and the ~60–70% it likely realizes today.
