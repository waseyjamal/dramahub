# Shorts Feature — Progress Checklist

> Source of truth for progress. Plan: `SHORTS_FEATURE_PLAN.md`.
> Rules: never edit existing files without owner approval · verify (analyze + test) after every item ·
> tick `[x]` only when verified · write a one-line note under "Log" at the bottom.
> New session? Read both files, run `git status`, continue at the first `[ ]`.

## P0 — Safety & baseline
- [ ] Owner approved plan + answered §9 decisions
- [ ] Back up / commit current uncommitted work (with approval)
- [ ] Create branch `feature/shorts`
- [ ] Baseline `flutter analyze` → record issue count here: ___
- [ ] Baseline `flutter test` and `flutter build apk --release` succeed

## P1 — Data layer (`lib/features/shorts/models`, `services`)
- [ ] `ShortsConfigModel` (+ safe defaults, enabled=false when missing)
- [ ] `ShortSeriesModel`, `ShortEpisodeModel` (defensive `fromJson`)
- [ ] `ShortsDataService`: fetch config/feed/series from `$cdnBase/shorts/…`, cache, data_version bust, timeout
- [ ] Bundled sample JSON in `assets/shorts_sample/` for dev fallback (only if approved; adds asset line to pubspec)
- [ ] Unit tests: parsing (good / missing / wrong types), fallback behaviour
- [ ] Verify: analyze clean, tests pass

## P2 — Player engine
- [ ] `ShortsPlayerPool` (window ±1, max 3, cancellable init, dispose outside window)
- [ ] URL resolver (HLS → MP4 fallback, optional signing + 4-min cache)
- [ ] Unit tests for window math (forward, back, jump, rapid swipes)
- [ ] Verify

## P3 — Feed UI
- [ ] `ShortsFeedScreen` (PageView, immersive, snap physics)
- [ ] `ShortVideoPage` (poster → first-frame fade, cover/contain fit)
- [ ] Overlay: title, ep label, expandable description, right rail
- [ ] Progress bar with drag-to-seek + buffering indicator
- [ ] Gestures: tap pause, long-press 2×, double-tap save + heart animation
- [ ] Widget test with fake data
- [ ] Verify

## P4 — Series / binge mode
- [ ] `ShortsSeriesScreen` (episodes as pages, auto-next)
- [ ] Episode picker bottom sheet (ranges, watched/current/locked)
- [ ] Locked episode UI + rewarded unlock (stored locally)
- [ ] Verify

## P5 — Local features
- [ ] `ShortsProgressStore` (position per episode, last series/ep, unlocked set, mute)
- [ ] Continue-watching card widget
- [ ] My List (saved series) screen
- [ ] Share via `share_plus`
- [ ] Verify

## P6 — Integration (⚠ touches old files — approval required for each)
- [ ] T1 approved → add `ShortsRoutes.pages` to `app_pages.dart`
- [ ] T2 approved → entry point (tab or home row), hidden when `enabled=false`
- [ ] Full regression of old screens
- [ ] Verify

## P7 — Ads & analytics
- [ ] Confirm how `AdService` resolves `screenKey`; add `shorts_feed` to remote ad config if needed
- [ ] Interstitial every N swipes (pause video during ad)
- [ ] Analytics events (view, swipe, complete, unlock, series_open)
- [ ] Verify

## P8 — Hardening
- [ ] App lifecycle pause/resume, RouteAware pause, tab-visibility pause
- [ ] Offline banner + auto-retry; error card with retry
- [ ] Low-RAM mode (pool size 2)
- [ ] Crashlytics non-fatal logging
- [ ] Verify

## P9 — Performance & QA
- [ ] Profile mode: no janky frames on swipe
- [ ] 100-swipe memory test steady
- [ ] Device matrix (low / mid / high Android)
- [ ] Old-app regression pass
- [ ] Release build succeeds

## P10 — Content tooling
- [ ] `tools/shorts_generator.dart` (CSV → JSON)
- [ ] Sample `shorts/` JSON for CDN
- [ ] Encoding guide confirmed with real test video

## P11 — Release
- [ ] Version bump (approval)
- [ ] Upload JSON with `enabled:false`, release APK, then flip `enabled:true`

---
## Log
- 2026-10-12 — Investigated app, wrote plan + checklist. Waiting for owner approval.
