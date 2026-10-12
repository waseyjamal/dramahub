# Drama Hub — Vertical Drama Player ("Shorts") Feature Plan

> Status: **PLAN — waiting for owner approval. No code written yet.**
> Companion file: `SHORTS_CHECKLIST.md` (progress tracker; update after every step).
> Any new session: read this file + the checklist first, then continue from the first unchecked item.

---

## 0. Honest answer: is it possible?

**Yes, fully possible, with no paid backend.** The app already has what it needs:
`video_player` (ExoPlayer on Android, plays HLS and MP4), GetX, a Cloudflare CDN for JSON
(`cdn_base`), a URL-signing API, LevelPlay ads, and SharedPreferences.

What really decides "Instagram-level smooth":

| Factor | Share of the result | Who controls it |
|---|---|---|
| How the videos are encoded (resolution, bitrate, segment size, faststart) | ~50% | You (upload side) — see §7 |
| Preloading the next/previous video before the swipe | ~30% | Code |
| Not rebuilding/janking the UI, correct disposal (memory) | ~20% | Code |

Limits to know up front:
- Very cheap Android phones (2–3 GB RAM) can hold only ~2–3 hardware video decoders at once. We use a
  **window of 3 players** (prev / current / next), which is what Instagram/TikTok-style apps do.
- With no backend there are **no likes, comments, follower counts or server-side recommendations**.
  Everything personal (saved list, watch progress, "continue watching") stays **on the device**.
- Video files must be hosted somewhere. Cloudflare **R2** has free egress and is a good fit (10 GB
  storage free, then about $0.015/GB/month). Cloudflare Pages is **not** suitable for video (25 MB file limit).

---

## 1. What the current app looks like (summary of the investigation)

- Flutter 3.47.3, Dart ^3.9.2, state: **GetX**, routes in `lib/routes/app_pages.dart`.
- Data: static JSON on CDN — `$cdnBase/dramas.json`, `$cdnBase/episodes/{dramaId}.json`
  (`lib/services/data_service.dart`), with a 5-minute cache and a `data_version` cache-buster.
- Remote config: `AppConfigService` → `AppConfigModel` (`cdn_base`, `use_signed_urls`, `signing_api`…).
- Playback: `lib/screens/video_screen.dart` (1924 lines) + `lib/widgets/custom_video_player.dart`
  (1980 lines), landscape-style long-form player using `VideoPlayerController.networkUrl`.
- Signed URLs: `SigningService.instance.getStreamUrl(dramaId, episodeNumber, rawUrl)`, which falls back to the raw URL.
- Ads: `AdService.instance.showInterstitialForScreen(key)` / `showRewardedForScreen(...)`.
- Navigation: `MainScreen` with 5 bottom tabs (Home, Watchlist, Downloads, History, Profile) in an `IndexedStack`.
- Existing deps already cover the feature: `video_player`, `wakelock_plus`, `cached_network_image`,
  `share_plus`, `shared_preferences`, `connectivity_plus`, `firebase_analytics`, `firebase_crashlytics`.
  **No new package is required for v1.**

---

## 2. Golden rule: do not break the old system

All new code lives in **one isolated folder**:

```
lib/features/shorts/
  models/        short_series_model.dart, short_episode_model.dart, shorts_config_model.dart
  services/      shorts_data_service.dart, shorts_progress_store.dart, shorts_player_pool.dart
  controllers/   shorts_feed_controller.dart, shorts_series_controller.dart
  screens/       shorts_feed_screen.dart, shorts_series_screen.dart, shorts_saved_screen.dart
  widgets/       short_video_page.dart, short_overlay.dart, short_progress_bar.dart,
                 episode_picker_sheet.dart, shorts_entry_card.dart, ...
  shorts_routes.dart
```

New code may **read and call** old services (`AppConfigService`, `SigningService`, `AdService`,
`HistoryController` is NOT used). It does not **modify** them.

### The only touches to existing files (each needs separate approval when we get there)

| # | File | Change | Why | Risk |
|---|---|---|---|---|
| T1 | `lib/routes/app_pages.dart` | `...ShortsRoutes.pages` spread into the list (1 line + import) | register new screens | Very low |
| T2 | Entry point: **choose ONE** — (a) `main_screen.dart`: add a 6th "Shorts" tab, or (b) `home_screen.dart`: add a "Vertical Dramas" row/banner | let users reach the feature | Low |
| T3 | `analysis_options.yaml` / `pubspec.yaml` | **none planned**; only if a package becomes necessary | — | — |

Remote kill switch: the feature reads its **own** file `shorts/config.json`. If that file is missing or has
`"enabled": false`, the entry point hides itself, so the old app behaves exactly as before.
`AppConfigModel` stays unchanged.

---

## 3. Content model (static JSON on your existing CDN)

```
$cdnBase/shorts/config.json
$cdnBase/shorts/feed.json            ← ordered list for the swipe feed
$cdnBase/shorts/series/{seriesId}.json   ← full episode list of one vertical drama
```

`config.json`
```json
{ "enabled": true, "data_version": 1, "interstitial_every_n_swipes": 6,
  "free_episodes_default": 10, "use_signed_urls": false, "min_build": 17 }
```

`feed.json`, the "For You" style feed (usually Episode 1 of each series, or curated trailers):
```json
[ { "seriesId": "lost_heiress", "episodeNumber": 1 }, ... ]
```

`series/{seriesId}.json`
```json
{
  "id": "lost_heiress", "title": "The Lost Heiress", "description": "...",
  "poster": "https://.../poster.jpg", "genre": "Romance", "tags": ["CEO","Revenge"],
  "totalEpisodes": 80, "freeEpisodes": 10, "language": "Hindi",
  "episodes": [
    { "n": 1, "title": "Ep 1", "hls": "https://.../ep1/master.m3u8",
      "mp4": "https://.../ep1.mp4", "thumb": "https://.../ep1.jpg",
      "durationSec": 92, "locked": false }
  ]
}
```
- `hls` is preferred; `mp4` is the fallback. Both are optional, but at least one is required.
- Long episodes (10–45 min) work too. The player has a full seek bar; the "shorts" feel comes from the
  vertical swipe UI, not from a length limit.
- `locked: true`: unlock with a rewarded ad through the existing `AdService` (no payment backend).
- A generator script `tools/shorts_generator.dart` (new) builds these JSON files from a CSV, the same idea as
  the existing `tools/episode_generator.dart`.

---

## 4. User experience (v1 scope)

**Feed screen (full-screen vertical PageView)**
- Swipe up/down; autoplay on settle; video starts from a **poster frame** with no black flash.
- Tap = pause/play (animated icon). Long-press = 2× speed while held. Double-tap = save to "My List" (local heart burst animation).
- Thin progress bar at the bottom, drag-to-seek with a time bubble, plus a buffering shimmer line.
- Right rail: Save (local), Episodes, Share (`share_plus`), Mute.
- Bottom: series title, "Ep 3 / 80", 2-line expandable description, "Watch full series ›".
- End of episode: auto-advance to the **next episode of the same series** (inside the series screen) or to the next feed item (in the feed).
- Remembers mute state and the last position for each episode.

**Series screen (binge mode)**
- Same vertical player, but pages = episodes 1…N of one drama.
- Episode picker bottom sheet: grid 1–N, grouped 1-30 / 31-60…, with watched / current / locked states.
- Locked episode shows a blurred poster with "Watch an ad to unlock" (rewarded) → unlock is saved locally.

**Home entry + "Continue watching" (local)** — the last series and episode, so resume is one tap.

**My List (saved series)** — local only, opened from the feed's top bar.

Out of scope (needs a backend): likes count, comments, follow, server recommendations, payments, cross-device sync.

---

## 5. Playback engine design (the "top 1% smooth" part)

### 5.1 Player pool — `ShortsPlayerPool`
- Keeps at most **3 live `VideoPlayerController`s**: index i-1, i, i+1. (Configurable: 2 on low-RAM devices.)
- On page change to i: play i, pause i±1 at position 0 (pre-initialized, so the first frame is ready),
  **dispose anything outside [i-1, i+1]**, then start initializing i+1 (and i-1 if missing).
- Preloading priority: **next first**, because users mostly swipe forward.
- Each controller is created with `VideoPlayerOptions(mixWithOthers: false)`. Video is `setLooping(false)` in series mode and loops in the feed for very short clips.
- Initialization is cancellable: if the user swipes past before init finishes, the result is disposed immediately (this prevents decoder leaks, the #1 crash cause in reels apps).
- URL resolution: `SigningService` is used only when `shorts/config.json` → `use_signed_urls` is true. The signed URL is cached per episode for 4 minutes (the signature lives 5 minutes).

### 5.2 Rendering
- `PageView.builder` with `allowImplicitScrolling: true`, `physics: const PageScrollPhysics()` + a custom spring tuned to match Instagram's snap.
- Each page: `Stack[ poster (CachedNetworkImage, BoxFit.cover) → AnimatedOpacity(VideoPlayer, shown on first frame) → overlay ]`.
- `FittedBox(fit: BoxFit.cover)` for 9:16 on any screen; letterbox (`contain`) when the video is not vertical.
- Overlay widgets listen to **narrow `ValueListenable`s** (position, isBuffering, isPlaying) with
  `RepaintBoundary`, so the progress bar never rebuilds the video layer.
- Only the **current** page's controller ticks UI listeners.

### 5.3 Lifecycle and safety
- `WidgetsBindingObserver`: pause on background, resume on foreground (only if it was playing).
- Pause when another route is pushed (`RouteAware`) and when the Shorts tab is not visible.
- `WakelockPlus` on while playing, off on leave.
- Immersive mode (`SystemUiMode.immersiveSticky`) inside the feed; the system UI is restored on exit.
- Connectivity: show an offline banner and retry automatically when the network returns (`connectivity_plus`).
- Errors: HLS fails → try MP4 → otherwise show a "Tap to retry" card. The swipe never blocks.
- Crashlytics non-fatal logging for player errors and Analytics events (`shorts_view`, `shorts_swipe`,
  `shorts_complete`, `shorts_unlock`, `shorts_series_open`).

### 5.4 Ads (uses existing AdService, no changes to it)
- Interstitial: `AdService.instance.showInterstitialForScreen('shorts_feed')` after every N swipes
  (N from `shorts/config.json`), only on a swipe boundary and never mid-video. The current video is paused while the ad shows.
- Rewarded: `showRewardedForScreen(...)` to unlock locked episodes.
- **To verify in Phase 1:** how `AdService` looks up `screenKey` in the remote ad config. If an unknown key is
  ignored, we add `shorts_feed` to your **remote ad config JSON** (a server-side edit, not an app code edit).

---

## 6. Phases

| Phase | Deliverable | Touches old code? |
|---|---|---|
| **P0 Safety** | Commit/back up current uncommitted work, create branch `feature/shorts`, run baseline `flutter analyze` + build | No |
| **P1 Data layer** | Models, `ShortsDataService` (fetch + cache + version bust + bundled sample fallback), unit tests | No |
| **P2 Player pool** | `ShortsPlayerPool` + unit tests for window/dispose logic | No |
| **P3 Feed UI** | Feed screen, page, overlay, progress bar, gestures | No |
| **P4 Series mode** | Series screen, episode picker, auto-next, locked/unlock | No |
| **P5 Local features** | Progress store, continue watching, My List, mute memory, share | No |
| **P6 Integration** | Route registration (T1) + entry point (T2) **after approval** | **Yes, minimal** |
| **P7 Ads + analytics** | Interstitial cadence, rewarded unlock, events | No (calls only) |
| **P8 Hardening** | Offline, errors, lifecycle, low-RAM mode, Crashlytics | No |
| **P9 Perf & QA** | Profile-mode testing, memory test (100 swipes), device matrix, regression of old screens | No |
| **P10 Content tooling** | `tools/shorts_generator.dart`, encoding guide, sample JSON | No |
| **P11 Release** | Version bump (needs approval), release build, staged rollout via `enabled` flag | Yes (version only) |

---

## 7. Video preparation guide (most important for smoothness)

Use **HLS** for the best start time and adaptive quality:
```
ffmpeg -i in.mp4 -filter_complex \
 "[0:v]split=3[a][b][c];[a]scale=720:1280[v720];[b]scale=540:960[v540];[c]scale=360:640[v360]" \
 -map "[v720]" -c:v:0 libx264 -b:v:0 2000k -maxrate:v:0 2200k -bufsize:v:0 3000k \
 -map "[v540]" -c:v:1 libx264 -b:v:1 1100k -maxrate:v:1 1200k -bufsize:v:1 1800k \
 -map "[v360]" -c:v:2 libx264 -b:v:2 600k  -maxrate:v:2 700k  -bufsize:v:2 1000k \
 -map a:0 -map a:0 -map a:0 -c:a aac -b:a 96k -ac 2 \
 -preset slow -profile:v main -g 48 -keyint_min 48 -sc_threshold 0 \
 -f hls -hls_time 2 -hls_playlist_type vod -hls_flags independent_segments \
 -master_pl_name master.m3u8 -var_stream_map "v:0,a:0 v:1,a:1 v:2,a:2" \
 -hls_segment_filename "v%v/seg_%03d.ts" "v%v/index.m3u8"
```
- **2-second segments** give a fast first frame. Keyframes are every 2 s at 24 fps (`-g 48`).
- Put the **lowest** variant first in `master.m3u8` if you want the fastest start on slow networks.
- MP4 fallback: `-movflags +faststart` (mandatory, or playback waits for the whole file).
- Poster: extract the first frame as a JPG ≤ 60 KB, 540×960 (`ffmpeg -ss 0.5 -i in.mp4 -frames:v 1 -vf scale=540:960 -q:v 5 poster.jpg`).
- Host on Cloudflare R2 + custom domain (CDN cached). Set `Cache-Control: public, max-age=31536000` on segments.

---

## 8. Testing and verification strategy (every phase)

1. `flutter analyze` must report **0 new issues** (compare against the P0 baseline).
2. `flutter test`: unit tests for model parsing (bad/missing fields), data service fallback, the pool window
   math (swipe forward/back/jump), and the progress store.
3. Widget test: feed renders with fake data, and page change triggers the pool correctly (fake controller interface).
4. `flutter build apk --release` must succeed.
5. Manual device test (you run it; I'll give exact steps): feed swipe 100×, memory steady
   (DevTools / `adb shell dumpsys meminfo`), no frame > 16 ms in profile mode on swipe, background/foreground,
   airplane mode, rotate lock, ad cadence, locked-episode unlock.
6. **Regression of the old app** after P6: Home, Episodes, old VideoScreen playback, Downloads, History, Watchlist, Profile, and ads still work.

---

## 9. Open decisions for you (answer before P6, not needed to start P0–P5)

1. **Entry point:** a 6th bottom tab "Shorts" (most visible; recommended, as in Kuku TV and ReelShort) **or** a row/banner on Home only?
2. **Locked episodes via rewarded ads:** yes or no? How many free episodes by default?
3. **Video hosting:** Cloudflare R2 (recommended) or something you already use? Will these use the signing API?
4. **Uncommitted changes:** your working tree has many modified files. May I commit them as-is on `master`
   (or a backup branch) before creating `feature/shorts`? I will not touch them otherwise.
