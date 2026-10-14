# Shorts Feature — Progress Checklist

> Source of truth for progress. Plan: `SHORTS_FEATURE_PLAN.md`. Admin/content: `SHORTS_ADMIN_GUIDE.md`.
> Rules: only edit existing files with the owner's approval · verify (analyze + test) after every item ·
> tick `[x]` only when verified · add a one-line note under "Log".
> New session? Read these files, run `git status` on branch `feature/shorts`, continue at the first `[ ]`.

## Owner decisions (2026-10-13)
- Entry: Shorts gets the 2nd bottom tab; **Downloads moves into Profile → Library** (only while Shorts is enabled; with Shorts off the bar is unchanged)
- Ads: both formats, fully remote-controlled (interstitial every N episodes + rewarded unlock), see admin guide §2
- Hosting: Cloudflare R2
- Packages: no new package (see "Package review" below)

## P0 — Safety & baseline
- [x] Owner approved plan + decisions
- [x] Owner committed previous work
- [x] Branch `feature/shorts` created
- [x] Baseline `flutter analyze` → **0 issues**

## P1 — Data layer
- [x] `models/shorts_config_model.dart` (safe defaults, clamping, disabled when missing)
- [x] `models/short_series_model.dart` (defensive parsing, dedupe/sort, feed entries)
- [x] `services/shorts_data_service.dart` (CDN fetch, 5-min cache, stale-on-offline, data_version bust, 404 → disabled)
- [x] `services/shorts_repository.dart` (config Rx, enabled + min_build check, series memory cache)
- [x] `services/shorts_local_store.dart` (My List, continue watching, positions capped at 300, unlocks, mute)
- [x] `services/shorts_rules.dart` (lock rules, ad cadence)
- [x] Unit tests (models, rules, cadence, data service with mock HTTP)

## P2 — Player engine
- [x] `services/shorts_player_pool.dart` (window ±1, max 2–3, current-first preload, leak-safe, retry, clear)
- [x] `services/shorts_player_factory.dart` (HLS → MP4 fallback, 20 s init timeout, optional signing)
- [x] `controllers/shorts_playback_controller.dart` (single `_sync` play/pause authority, progress save, end detect, ads, unlock, wakelock, Crashlytics, Analytics, release/restore)
- [x] Pool unit tests (window, order, leak on rapid swipe, ≤3 alive over 30 swipes, locked, errors, clear)

## P3 — Feed UI
- [x] `widgets/shorts_player_view.dart` (vertical PageView, snappy physics, implicit pre-build, lifecycle + route awareness)
- [x] `widgets/short_video_page.dart` (poster→video, cover/contain, tap pause, double-tap heart, long-press 2×, rail, expandable text, end card, locked/error layers)
- [x] `widgets/short_progress_bar.dart` (ticker-interpolated smooth bar, drag-to-seek with time bubble)
- [x] `widgets/shorts_state_views.dart` (shimmer loading, error/empty)
- [x] `screens/shorts_feed_screen.dart` (lazy: loads only when the tab is first opened; frees decoders while hidden)

## P4 — Series / binge mode
- [x] `screens/shorts_series_screen.dart` (auto-next, top bar EP x/y)
- [x] `widgets/episode_picker_sheet.dart` (ranges of 30, watched/current/locked)
- [x] Locked episode + rewarded unlock

## P5 — Local features
- [x] Continue-watching chip (feed top bar)
- [x] `screens/shorts_my_list_screen.dart`
- [x] Share via share_plus

## P6 — Integration (approved by owner)
- [x] `lib/routes/app_pages.dart`: `...ShortsRoutes.pages` (+1 import)
- [x] `lib/screens/main_screen.dart`: id-based tabs, Shorts tab when enabled, Downloads tab when disabled
- [x] `lib/screens/profile_screen.dart`: "Library → Downloads" tile
- [ ] **Device regression** of old screens (owner runs; steps in "Manual test script" below)

## P7 — Ads & analytics
- [x] Interstitial cadence + rewarded unlock wired to existing AdService (no AdService change)
- [x] Analytics: `shorts_view`, `shorts_complete`, `shorts_unlock`
- [ ] Owner adds `shorts_feed` (interstitial) + `shorts_unlock` (rewarded) to remote ad config screens

## P8 — Hardening
- [x] Lifecycle pause/resume, route-cover pause, tab-hidden release
- [x] Error card + retry, HLS→MP4 fallback, offline stale cache
- [x] Low-RAM mode via `max_players: 2` (remote)
- [x] Crashlytics non-fatal logging (once per player)

## P9 — Performance & QA
- [ ] Full `flutter analyze` 0 issues · all tests pass · `flutter build apk --release` ✔ (see Log)
- [ ] Device: profile-mode swipe has no jank (`flutter run --profile`)
- [ ] Device: 100-swipe memory steady
- [ ] Device matrix: low / mid / high Android

## P10 — Content tooling
- [x] `tools/shorts_generator.dart` (tested: generated demo series)
- [x] Sample CDN files: `shorts_cdn/shorts/{config,feed}.json`, `series/demo_series.json`
- [x] `SHORTS_ADMIN_GUIDE.md` (ads, R2, encoding, adding series)
- [ ] Encode + upload first real series to R2

## P11 — Release
- [ ] Version bump (owner approval): `pubspec.yaml` version + `Constants.currentBuildVersion`
- [ ] Merge `feature/shorts` → master
- [ ] Ship APK with `enabled:false`, then flip to `true`

---
## Package review (top-1% check)
- `video_player` 2.11: ExoPlayer/Media3 on Android, adaptive HLS, hardware decode, so it's the right engine. Alternatives were considered:
  `media_kit` (+~20 MB APK, software-leaning, no benefit for this use) and `better_player_plus` (fork maintenance risk). **Keep.**
- Smoothness comes from the pool preloading the next video (ExoPlayer buffers on `initialize`), and that's already implemented.
- **Possible later upgrade** (only if testing shows a slow first frame on slow networks): a disk pre-cache of the first
  segments. It's not needed now.

## Manual test script (owner, on device)
1. Put `shorts_cdn/shorts/*` on the CDN with `"enabled": true` (use the test stream from guide §7 if no videos yet).
2. Open the app → Shorts tab appears second, Downloads is in Profile → Library.
3. Swipe 20+ times up/down: the next video starts instantly, there's no audio overlap, and the progress bar is smooth.
4. Tap = pause, double-tap = heart and saved, long-press = 2×, drag the bar = seek.
5. Switch to Home → Shorts audio stops at once. Open an old drama episode → it plays normally. Come back → Shorts resumes.
6. Background the app → it pauses; reopen → it resumes.
7. "Watch full series" → binge screen, episodes auto-advance, the picker works, a locked episode shows the unlock button.
8. Airplane mode → the error card with Retry appears; turn the network on → Retry works.
9. Set `"enabled": false` → restart → the old bottom bar is back, exactly as before.

---
## Log
- 2026-10-12 — Investigated app, wrote plan + checklist.
- 2026-10-13 — Owner decisions recorded. Built P1–P8 + P10 under `lib/features/shorts/`. Integration edits in 3 files.
  Analyzer on new/changed files: 0 issues. Shorts unit tests: 28/28 pass.
- 2026-10-13 — Full analyze 0 issues, all tests 28/28 pass. Release APK build NOT verified: stopped by Claude Code because PC ran low on memory. Rerun `flutter build apk --release` with other apps closed.
