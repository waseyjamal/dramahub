# Drama Hub — Shorts (Vertical Drama) Feature: Developer Handoff

> One document to hand to a developer or AI agent. It explains what Shorts is, how every part works
> (app, data, admin panel, CDN, signing, ads), where the code lives, how to add content, how to test,
> what is finished, and what is still open.
>
> Last updated: 2026-10-13 · App branch: `feature/shorts` (not merged, not committed yet)

---

## 0. Rules for anyone working on this (owner's rules — read first)

1. **Do not change the existing app.** Shorts is isolated in `lib/features/shorts/`. Any edit to an
   existing (non-Shorts) file must be explained to the owner and **approved first**.
2. **Nothing existing may break.** Home, Watchlist, History, Downloads, the normal player, ads and force
   update must behave exactly as before. When Shorts is disabled, the app must look like the old app.
3. **Do not run release builds on the owner's PC** (it ran out of memory). The owner builds. Use
   `flutter analyze` and `flutter test` to verify.
4. **Keep line endings** of existing files as they are (repos store LF).
5. **Docs/plans are saved in the project root.**
6. Always verify: analyze (0 issues) + tests pass + explain how to test on device.

---

## 1. What Shorts is

An Instagram-Reels / ReelShort / Kuku TV style **vertical drama player** inside the Drama Hub Flutter app:

- A **Shorts tab** with a full-screen vertical swipe feed (one episode per page, autoplay).
- Each video belongs to a **series** with many short episodes (1–3 min). "Watch full series" opens a
  series player that swipes through that series' episodes in order.
- **For You | Discover** text tabs at the top of the Shorts tab (the only overlay on the player).
  **Discover** = search, continue watching, My List row, genre chips, all-series poster grid.
- **My List**: saved series (on device only); full list via Discover → My List → See all.
- **Monetization:** first N episodes free, later episodes **locked** → user watches a **rewarded ad**
  to unlock the next X episodes. **Interstitial ads** every N episodes. All controllable from config.
- **No paid backend.** Data = static JSON on Cloudflare Pages. Videos = Cloudflare R2. Signed links =
  existing Deno signing function.

---

## 2. Architecture overview

```
 ┌───────────────────┐   commits JSON via GitHub API   ┌──────────────────────────────┐
 │ Admin panel (web) │ ──────────────────────────────▶ │ GitHub: waseyjamal/          │
 │ dramahub_admin    │                                  │         dramahub-data        │
 └───────────────────┘                                  └──────────────┬───────────────┘
                                                                       │ auto deploy
                                                                       ▼
 ┌───────────────────┐  GET shorts/*.json               ┌──────────────────────────────┐
 │  Flutter app      │ ◀─────────────────────────────── │ Cloudflare Pages             │
 │  (Shorts feature) │                                  │ https://dramahub-data.pages.dev
 │                   │  GET ?dramaId=shorts_<id>&ep=N   └──────────────────────────────┘
 │                   │ ───────────────▶ Deno signer ──▶ reads shorts/series/<id>.json,
 │                   │ ◀── signed URL (?dht=…&exp=…)     signs the R2 path (HMAC, 5 min)
 │                   │
 │                   │  GET signed video URL            ┌──────────────────────────────┐
 │                   │ ───────────────────────────────▶ │ Cloudflare R2 bucket         │
 └───────────────────┘                                  │ dramahub-videos              │
                                                        │ https://cdn.dramahubs.stream │
                                                        │ (unsigned requests → 403)    │
                                                        └──────────────────────────────┘
```

| Piece | Location |
|---|---|
| Flutter app | `C:\Projects\drama_hub` (GitHub `waseyjamal/dramahub`), branch `feature/shorts` |
| Data repo | `C:\Projects\dramahub_admin\dramahub-data` (GitHub `waseyjamal/dramahub-data`) |
| Data public URL | `https://dramahub-data.pages.dev` (Cloudflare Pages) |
| Admin panel | `C:\Projects\dramahub_admin` (Flutter web, deployed on Cloudflare) |
| Videos | Cloudflare R2 bucket `dramahub-videos`, rclone remote `r2dramahub:` |
| Video domain | `https://cdn.dramahubs.stream/<path>` (also `cdn2.dramahubs.stream`) |
| Signing (primary) | `https://high-crab-4265.waseyjamal000.deno.net` |
| Signing (fallback) | `https://gloomy-ibis-5535.waseyjamal00.deno.net` |
| Signing switch | `use_signed_urls`, `signing_api`, `signing_api_fallback` in main `app_config.json` |

---

## 3. Data format (dramahub-data/shorts/)

```
shorts/
  config.json            # on/off, ads, limits
  feed.json              # list of series shown in the Shorts tab (1 entry per series)
  series/<seriesId>.json # full series with all episodes
  series/_example.json   # template
```

### 3.1 `shorts/config.json`
```json
{
  "enabled": true,
  "data_version": 5,
  "min_build": 0,
  "use_signed_urls": false,
  "free_episodes_default": 10,
  "max_players": 3,
  "ads": {
    "interstitial_enabled": true,
    "interstitial_every_n_episodes": 4,
    "interstitial_first_after": 3,
    "interstitial_screen_key": "shorts_feed",
    "rewarded_unlock_enabled": true,
    "unlock_episodes_per_ad": 3,
    "unlock_on_no_fill": true,
    "rewarded_screen_key": "shorts_unlock"
  }
}
```
| Key | Meaning |
|---|---|
| `enabled` | Master switch. `false` (or file missing/404) → no Shorts tab, app = old app |
| `data_version` | Increase on every change → app drops its 5-minute cache immediately. Admin auto-increments |
| `min_build` | Shorts only shown if app build number ≥ this (`Constants.currentBuildVersion`) |
| `use_signed_urls` | **No longer used by the app.** Shorts now follow the global `use_signed_urls` in `app_config.json` (same as normal episodes). Kept for compatibility |
| `free_episodes_default` | Free episodes per series if the series doesn't set `freeEpisodes` |
| `max_players` | Max video players alive at once (2–3). Lower = less RAM |
| `ads.interstitial_*` | Show interstitial every N episodes, first one after N episodes |
| `ads.rewarded_unlock_enabled` | `false` → nothing is locked at all |
| `ads.unlock_episodes_per_ad` | Episodes unlocked per rewarded ad |
| `ads.unlock_on_no_fill` | If no ad is available, unlock anyway (don't block the user) |
| `ads.*_screen_key` | Keys in the main `ad_config.json` screen toggles (`shorts_feed`, `shorts_unlock`) — ads also need those toggles ON in Admin → Ads |

### 3.2 `shorts/series/<id>.json`
```json
{
  "id": "s_randhawa",
  "title": "S Randhawa",
  "description": "…",
  "genre": "attitude",
  "tags": [],
  "poster": "https://cdn.dramahubs.stream/shorts/s_randhawa/poster.jpg",
  "freeEpisodes": 10,
  "totalEpisodes": 1,
  "episodes": [
    { "n": 1, "title": "Episode 1",
      "mp4": "https://cdn.dramahubs.stream/shorts/s_randhawa/sr-1.mp4",
      "hls": "(optional) …/ep-1/index.m3u8",
      "thumb": "(optional) image url",
      "duration": 0,
      "locked": null }
  ],
  "_admin": { "type": "mp4", "pattern": "https://cdn.dramahubs.stream/shorts/s_randhawa/sr-{n}.mp4", "thumbPattern": "" }
}
```
- `id`: lowercase letters/numbers/underscore. Used in URLs and signing (`shorts_<id>`).
- Episode `n` must be unique. `hls` is tried first, then `mp4`.
- `locked`: `true`/`false` overrides the free-episode rule for that one episode; `null` = use the rule.
- `_admin`: only used by the admin panel to generate new episodes from `{n}` patterns. App ignores it.

### 3.3 `shorts/feed.json`
Array, one entry per series, in display order. Built by the admin from the series file:
```json
[{ "id": "s_randhawa", "title": "S Randhawa", "description": "…", "poster": "…",
   "totalEpisodes": 1, "episode": { "n": 1, "mp4": "…", "thumb": "…" } }]
```
`episode` = the episode the feed plays for that series (episode 1).

Feed entries also carry `genre` and `tags` (used by Discover's genre chips and search). The admin
writes them on every series save, and on opening the Shorts page it re-syncs any older feed entries
from their series files (`_resyncFeed()` in `shorts_controller.dart`).

---

## 4. Video hosting & upload (R2)

Folder per series: `dramahub-videos/shorts/<seriesId>/` → `https://cdn.dramahubs.stream/shorts/<seriesId>/…`

### MP4 (simplest)
```bash
# Re-encode to H.264 + faststart (AV1 / HEVC sources may not play on many phones)
ffmpeg -i "in.mp4" -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 96k -movflags +faststart "upload\ep-1.mp4"
# If the source is already H.264, just add faststart (fast, no quality loss):
ffmpeg -i "in.mp4" -c copy -movflags +faststart "upload\ep-1.mp4"
# Poster (vertical 540x960)
ffmpeg -ss 3 -i "in.mp4" -frames:v 1 -vf scale=540:960 -q:v 5 "upload\poster.jpg"
# Upload
rclone copy "upload" r2dramahub:dramahub-videos/shorts/<seriesId>/ --progress
```
Notes:
- ffmpeg does **not** create folders — create `upload` first.
- **File names must match the admin URL pattern exactly** (`ep-{n}.mp4` vs `sr-{n}.mp4`). This was the cause of one failed test.
- Videos are vertical 9:16, ideally 720×1280, 1–3 min.
- HLS is supported (`…/ep-{n}/index.m3u8`); see `SHORTS_UPLOAD_GUIDE.md`. With signed URLs, HLS
  segment requests must also pass the CDN token check — MP4 is the tested path.

### Checking a link
Unsigned requests to `cdn.dramahubs.stream` **always return 403** (even for files that exist). To check
a file, get a signed URL first:
```
https://high-crab-4265.waseyjamal000.deno.net/?dramaId=shorts_s_randhawa&ep=1&type=stream
```
Open the returned `url` in a browser → should play (HTTP 200/206).

---

## 5. Signing (Deno)

Normal episodes and Shorts both use the existing Deno function. App call:
```
GET <signing_api>?dramaId=shorts_<seriesId>&ep=<n>&type=stream
→ { "url": "https://cdn.dramahubs.stream/shorts/<id>/sr-1.mp4?dht=<hmac>&exp=<ms>", "signed": true }
```
The Deno `getEpisodeUrl` was extended with a Shorts branch (deployed on the **primary** only):
```ts
if (dramaId.startsWith('shorts_')) {
  const seriesId = dramaId.slice('shorts_'.length);
  const res = await fetch(`${CDN_BASE}/shorts/series/${seriesId}.json`);
  if (!res.ok) return null;
  const series = await res.json();
  const ep = (series.episodes || []).find((e: { n: number }) => e.n === epNumber);
  if (!ep) return null;
  return ep.hls || ep.mp4 || null;
}
// …normal drama lookup unchanged…
```
- Token = HMAC-SHA256(`SESSION_SECRET`, `<r2Path>:<exp>`), base64url. Stream TTL 5 min.
- ⚠ **TODO:** deploy the same change to the **fallback** signer (`gloomy-ibis…`); it currently returns
  "Episode not found" for Shorts.
- App logic (`shorts_player_factory.dart`): Shorts always call `SigningService.getStreamUrl`; the
  service itself checks global `use_signed_urls` and falls back to the raw URL on any failure.
- Limitation: a link expires 5 min after it's created; a video paused longer may fail on resume (same as normal episodes). Only the primary source is signed; the HLS→MP4 fallback URL is unsigned.

---

## 6. Admin panel (dramahub_admin)

Pushed to `main` (commit `846dff7`). Owner builds `flutter build web` and deploys on Cloudflare.

- **Shorts page** (bottom nav "Shorts"): `lib/views/pages/shorts_manager_page.dart`, logic in
  `lib/controllers/shorts_controller.dart`.
  - **Series tab:** add series (title → auto id, description, genre, tags, poster, free episodes,
    video type HLS/MP4, URL pattern with `{n}`, thumb pattern, episode count, show in app);
    ⋮ menu: add new episodes (up to N, existing untouched), edit episode, show/hide in app,
    reorder, open ep 1 link, delete.
  - **Settings tab:** writes `shorts/config.json`, auto-increments `data_version`.
  - ⚠ The MP4 option keeps the auto-filled `ep-{n}` pattern — replace it with your real file pattern.
- **Ad Manager fix:** `ad_controller.dart` now keeps `shorts_feed` (interstitial) and `shorts_unlock`
  (rewarded) screen keys — previously they were deleted on every save.
- Other edits: `github_service.dart` (+`listDirectory`), `main_layout.dart` (nav item), `bindings.dart`.
- Plan doc: `dramahub_admin/SHORTS_ADMIN_PANEL_PLAN.md`. Owner guide: `SHORTS_ADMIN_GUIDE.md` (app root).

---

## 7. App code map (`lib/features/shorts/`)

| File | Responsibility |
|---|---|
| `models/shorts_config_model.dart` | `ShortsConfig`, `ShortsAdsConfig` parsing with safe defaults |
| `models/short_series_model.dart` | `ShortEpisode` (n, title, hls, mp4, thumb, duration, locked), `ShortSeries`, `ShortFeedEntry`, `ShortItem` (series+episode, key `id#n`) |
| `services/shorts_data_service.dart` | HTTP fetch of `$cdnBase/shorts/config.json`, `feed.json`, `series/<id>.json`; 5-min cache; stale data when offline; cache bust on `data_version`; config 404 → disabled |
| `services/shorts_repository.dart` | Singleton. `init()`, `config` (Rx), `loadFeed()`, `loadSeries()` (memory cache 5 min), `min_build` check |
| `services/shorts_local_store.dart` | SharedPreferences: saved list (`shorts_saved`), muted, unlocked-up-to (`shorts_unlocked_<id>`), furthest watched (`shorts_watched_<id>`), resume positions (`shorts_pos_<id#n>`), last watched |
| `services/shorts_rules.dart` | `ShortsRules.isLocked` (unlock progress → explicit `locked` → free count); `ShortsAdCadence` (interstitial timing) |
| `services/shorts_feed_ranker.dart` | Per-user For You order: first 3 unseen keep admin order (featured), other unseen shuffled, seen next, started last; new seed on every open / pull-to-refresh |
| `services/shorts_player_pool.dart` | Keeps players only for current page ±1 (max 2–3), disposes others → low RAM, instant swipe |
| `services/shorts_player_factory.dart` | Creates `VideoPlayerController`: HLS first, MP4 fallback, 20 s init timeout, signing |
| `controllers/shorts_playback_controller.dart` | Single `_sync()` decides what plays: app active/visible/route current; release/restore players when another screen opens; unlock via `AdService.showRewardedForScreen`; interstitial via `showInterstitialForScreen`; last-watched only saved in series mode |
| `widgets/shorts_player_view.dart` | The page-view player shell |
| `widgets/short_video_page.dart` | One page: video, gestures (tap pause, double-tap ❤ save, hold 2× speed), overlay, lock screen |
| `widgets/short_progress_bar.dart` | Draggable seek bar |
| `widgets/episode_picker_sheet.dart` | Episode grid bottom sheet (lock icons) |
| `widgets/shorts_state_views.dart` | `ShortsLoadingView`, `ShortsMessageView` (error/empty + retry) |
| `screens/shorts_feed_screen.dart` | Shorts tab: For You feed + Discover page, top `For You \| Discover` switcher. Players are released while Discover shows; Android back on Discover returns to For You |
| `screens/shorts_series_screen.dart` | Full series player (`/shorts/series`, args `ShortsSeriesArgs(seriesId, episode)`) |
| `widgets/shorts_discover_view.dart` | **Discover**: search, continue-watching row (progress bar), My List row (See all), genre chips, 3-column poster grid, pull-to-refresh; tap resumes at furthest episode |
| `screens/shorts_my_list_screen.dart` | Saved series grid (long-press removes) |
| `shorts_routes.dart` | Routes `/shorts/series`, `/shorts/my-list`; `openSeries()` |

### Existing files changed (approved by owner)
| File | Change |
|---|---|
| `lib/routes/app_pages.dart` | `...ShortsRoutes.pages` added |
| `lib/screens/main_screen.dart` | Tabs are id-based. Shorts ON → Home · Shorts · Watchlist · History · Profile. OFF → original bar unchanged |
| `lib/screens/profile_screen.dart` | Downloads moved into Profile → Library (because Shorts takes its tab slot) |

### Other files
- Tests: `test/features/shorts/` (data service, models/rules, player pool) — **28 tests passing**.
- `tools/shorts_generator.dart` — CLI to generate series JSON (admin panel replaces it).
- `shorts_cdn/shorts/` — sample JSON (demo series).
- Docs (root): `SHORTS_FEATURE_PLAN.md`, `SHORTS_CHECKLIST.md` (progress log), `SHORTS_ADMIN_GUIDE.md`,
  `SHORTS_UPLOAD_GUIDE.md`, `SHORTS_TEST_S_RANDHAWA.md`, this file.

### For You feed behaviour
- Order is per user (`ShortsFeedRanker`); series scrolled past are stored in `shorts_seen` (max 2000) and move back.
- The player gets 20 items at a time; the next 20 are appended when the user is 5 from the end.
- Pull down on the first video → refresh + new order (keeps current videos if offline).
- After the last video: "You're all caught up" page with **Discover** and **Start over** (video paused there).
- Posters must not be on `cdn.dramahubs.stream` (unsigned images get 403) — use jsDelivr `dramahub-images`.
- Audio continuing after a **hot restart** is a debug-only `video_player` limitation (native players survive the Dart restart); not a release bug.

### Performance design ("top 1% smooth")
- Max 2–3 decoders alive (pool ±1); everything else disposed.
- Players released when another route covers the feed and when the app goes to background; restored on return.
- Only one `_sync()` path controls play/pause → no double-play or audio leaks.
- Next episode preloaded while the current one plays. Posters use `memCacheWidth` to save RAM.
- Judge smoothness only in `--release` builds.

---

## 8. How to add a new series (end to end)

1. Prepare videos (H.264 + faststart) and `poster.jpg` → `rclone copy` to `dramahub-videos/shorts/<id>/`.
2. Admin → Shorts → Series → **Add series**. Set the type (MP4/HLS) and a URL pattern that matches the real file names. Set genre. Save.
3. ⋮ → **Open episode 1 link** (expect 403 if signed-only — use the signer URL from §4 to check instead).
4. Make sure Shorts Settings has **Shorts enabled** ON, and Admin → Ads has **Shorts Feed** / **Shorts Unlock** ON.
5. Check `https://dramahub-data.pages.dev/shorts/feed.json` lists the series.
6. App picks it up within 5 minutes (or immediately thanks to the `data_version` bump; restart app to be sure).

Adding more episodes later: upload `ep-N.mp4` → Admin ⋮ → **Add new episodes** → enter N.

---

## 9. Testing

```bash
cd C:\Projects\drama_hub
git checkout feature/shorts
flutter analyze            # expect: No issues found
flutter test test/features/shorts
flutter run --release      # owner runs on a device
```
Device checklist:
- [ ] Shorts OFF in config → app identical to old app (old bottom bar, Downloads tab as before)
- [ ] Shorts ON → 5 tabs; Downloads in Profile → Library opens old downloads
- [ ] Feed autoplays, swipe is instant, no audio from off-screen videos
- [ ] Tap pause · double-tap ❤ · hold 2× · drag seek bar
- [ ] Watch full series → episodes in order, episode picker, lock icons
- [ ] Locked episode → rewarded ad → next N unlocked; no fill + `unlock_on_no_fill` → unlocked
- [ ] Interstitial after configured episodes
- [ ] For You | Discover switch: video pauses on Discover, resumes on For You; back button on Discover → For You
- [ ] Discover: search, genre chips, continue watching, My List + See all, grid, tap resumes
- [ ] My List save/remove
- [ ] Background/foreground, open another screen and back → video resumes, no leaks
- [ ] Offline → cached feed or error with retry
- [ ] Normal episodes, ads, force update still work

### Troubleshooting
| Symptom | Cause / fix |
|---|---|
| No Shorts tab | `config.json` 404 or `enabled:false`, or `min_build` > app build. Restart app |
| "Couldn't load" in Shorts | `feed.json` 404 → check Cloudflare Pages deployments of dramahub-data |
| "Couldn't play" + log `Response code: 403` | URL not signed (signer down / series not found by signer) **or** file name doesn't match the URL in the series JSON |
| Log shows URL without `?dht=` | Signing not applied: global `use_signed_urls` false, or both signers failed |
| Plays on some phones only | Video is AV1/HEVC → re-encode to H.264 |
| Slow start | No faststart, or very large file |

---

## 10. Status

**Done**
- App feature, routes, tabs, For You | Discover, signing integration, tests (28 pass), analyze 0 issues.
- Data structure pushed to dramahub-data; admin Shorts page + Ad Manager fix pushed and deployed.
- Deno primary signer supports Shorts (verified: signed URL returns 206).
- First test series `s_randhawa` live.

**Open / next**
1. Deploy Deno Shorts change to the **fallback** signer.
2. ~~Admin: genre/tags in feed~~ — done (needs admin rebuild + deploy).
3. Admin: when MP4 is chosen, auto-switch the pattern to `…/<id>/ep-{n}.mp4` and add a "Test link" button that checks via the signer — avoids wrong patterns.
4. Owner device test of the latest code (Discover redesign not yet tested on device).
5. Version bump to build 17 (needs owner approval), set `min_build` accordingly.
6. Commit `feature/shorts`, review, merge to `master`.
7. Optional later: HLS with signed segments, server-side unlock validation (currently client-side), analytics.
