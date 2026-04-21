# DramaHub — Ad System Documentation

## Overview

DramaHub uses **Appodeal Mediation** as its ad network, connected to **Vungle** and **Unity Ads** as demand partners. All ad behavior is controlled remotely through a JSON config file hosted on GitHub. No app update is needed to change any ad setting.

---

## Ad Networks & Mediation

| Layer | Technology |
|---|---|
| Mediation | Appodeal |
| Network 1 | Vungle (Liftoff) |
| Network 2 | Unity Ads |
| SDK | stack_appodeal_flutter 3.12.0 |
| AdMob Stub | Required by Appodeal — not used for real ads |

---

## Ad Types Supported

| Type | Status |
|---|---|
| Interstitial | ✅ Active |
| Rewarded Video | ✅ Active |
| Native | ❌ Removed |
| App Open | ❌ Not supported in Appodeal 3.12.0 |
| Banner | ❌ Not used |

---

## Remote Control System

### Config File Location
```
https://raw.githubusercontent.com/waseyjamal/dramahub-data/main/ad_config.json
```

### How It Works
1. App fetches `ad_config.json` from GitHub on every startup
2. If fetch fails — app uses safe defaults (all ads OFF)
3. Admin updates the JSON file on GitHub
4. Changes reflect in user app within minutes — no app update needed

---

## ad_config.json Structure & Controls

```json
{
  "ads_enabled": false,
  "interstitial": {
    "enabled": true,
    "cooldown_seconds": 30,
    "max_per_session": 8,
    "screens": {
      "home_screen": true,
      "episodes_screen": true,
      "watchlist_screen": true,
      "history_screen": true,
      "download_screen": true,
      "upcoming_screen": true,
      "report_problem_screen": true,
      "suggest_drama_screen": true
    }
  },
  "rewarded": {
    "enabled": true,
    "screens": {
      "video_screen": true,
      "episodes_screen": false,
      "watchlist_screen": false
    }
  }
}
```

### Master Switch
| Field | Effect |
|---|---|
| `ads_enabled: false` | ALL ads OFF everywhere instantly |
| `ads_enabled: true` | Ads ON — each screen follows its own toggle |

### Interstitial Controls
| Field | Effect |
|---|---|
| `interstitial.enabled: false` | All interstitials OFF globally |
| `cooldown_seconds: 30` | Minimum gap between two interstitials |
| `max_per_session: 8` | Max interstitials shown per 4-hour session |

### Rewarded Controls
| Field | Effect |
|---|---|
| `rewarded.enabled: false` | All rewarded ads OFF globally |

---

## Per-Screen Ad Setup

### Home Screen
| Ad Type | Toggle in config | When it fires |
|---|---|---|
| Interstitial | `interstitial.screens.home_screen` | Once per session on app open. Resets when app fully closed and reopened |
| Rewarded | Not used | — |

**How admin controls it:**
- Turn ON: set `interstitial.screens.home_screen: true`
- Turn OFF: set `interstitial.screens.home_screen: false`

---

### Episodes Screen
| Ad Type | Toggle in config | When it fires |
|---|---|---|
| Interstitial | `interstitial.screens.episodes_screen` | When user opens any drama — fires after 1 second |
| Rewarded | `rewarded.screens.episodes_screen` | When user taps any episode to watch |

**How admin controls it:**
- Show interstitial only: `interstitial.screens.episodes_screen: true` + `rewarded.screens.episodes_screen: false`
- Show rewarded only: `interstitial.screens.episodes_screen: false` + `rewarded.screens.episodes_screen: true`
- Show both: enable both — interstitial on screen open, rewarded on episode tap
- Turn everything OFF: set both to `false`

**Important:** When coming from Watchlist → Episodes, interstitial is automatically skipped to avoid double ads after rewarded.

---

### Video Screen
| Ad Type | Toggle in config | When it fires |
|---|---|---|
| Interstitial | Not used | — |
| Rewarded | `rewarded.screens.video_screen` | When user taps Free Download button |

**How admin controls it:**
- Turn ON: set `rewarded.screens.video_screen: true` → user watches ad then goes to download screen
- Turn OFF: set `rewarded.screens.video_screen: false` → user taps button and goes directly to download screen with no ad

---

### Download Screen
| Ad Type | Toggle in config | When it fires |
|---|---|---|
| Interstitial | `interstitial.screens.download_screen` | When download screen opens — fires after 1 second |
| Rewarded | Not used | — |

**How admin controls it:**
- Turn ON: set `interstitial.screens.download_screen: true`
- Turn OFF: set `interstitial.screens.download_screen: false`

---

### Watchlist Screen
| Ad Type | Toggle in config | When it fires |
|---|---|---|
| Interstitial | `interstitial.screens.watchlist_screen` | When user opens watchlist tab — fires after 1 second |
| Rewarded | `rewarded.screens.watchlist_screen` | When user taps any drama from watchlist |

**How admin controls it:**
- Show interstitial on tab open only: `interstitial.screens.watchlist_screen: true` + `rewarded.screens.watchlist_screen: false`
- Show rewarded on drama tap only: `interstitial.screens.watchlist_screen: false` + `rewarded.screens.watchlist_screen: true`
- Never enable both at same time — user will see double ads

**Important:** When rewarded plays from watchlist drama tap — episodes screen interstitial is automatically skipped.

---

### History Screen
| Ad Type | Toggle in config | When it fires |
|---|---|---|
| Interstitial | `interstitial.screens.history_screen` | When user opens history tab — fires after 1 second |
| Rewarded | Not used | — |

**How admin controls it:**
- Turn ON: set `interstitial.screens.history_screen: true`
- Turn OFF: set `interstitial.screens.history_screen: false`

---

### Upcoming Screen
| Ad Type | Toggle in config | When it fires |
|---|---|---|
| Interstitial | `interstitial.screens.upcoming_screen` | When upcoming screen opens — fires after 1 second |
| Rewarded | Not used | — |

**How admin controls it:**
- Turn ON: set `interstitial.screens.upcoming_screen: true`
- Turn OFF: set `interstitial.screens.upcoming_screen: false`

---

### Report Problem Screen
| Ad Type | Toggle in config | When it fires |
|---|---|---|
| Interstitial | `interstitial.screens.report_problem_screen` | When screen opens — fires after 1 second |
| Rewarded | Not used | — |

**How admin controls it:**
- Turn ON: set `interstitial.screens.report_problem_screen: true`
- Turn OFF: set `interstitial.screens.report_problem_screen: false`

---

### Suggest Drama Screen
| Ad Type | Toggle in config | When it fires |
|---|---|---|
| Interstitial | `interstitial.screens.suggest_drama_screen` | When screen opens — fires after 1 second |
| Rewarded | Not used | — |

**How admin controls it:**
- Turn ON: set `interstitial.screens.suggest_drama_screen: true`
- Turn OFF: set `interstitial.screens.suggest_drama_screen: false`

---

## Key Files in Codebase

| File | Purpose |
|---|---|
| `lib/services/ad_service.dart` | Core ad logic — interstitial, rewarded, session management |
| `lib/services/ad_config_service.dart` | Fetches and caches config from GitHub |
| `lib/models/ad_config_model.dart` | Data model for ad config JSON |
| `lib/bindings/initial_binding.dart` | Registers AdService at app startup |

---

## Session & Cooldown Logic

| Rule | Value | Controlled by |
|---|---|---|
| Max interstitials per session | 8 | `max_per_session` in config |
| Cooldown between interstitials | 30 seconds | `cooldown_seconds` in config |
| Session duration | 4 hours | Hardcoded in AdService |
| Home ad per session | 1 time only | `_homeAdShownThisSession` flag in AdService |

---

## How to Go Live

1. Open `ad_config.json` on GitHub repo `waseyjamal/dramahub-data`
2. Change `"ads_enabled": false` to `"ads_enabled": true`
3. Save and commit
4. Ads start showing in user app within minutes

---

## How to Disable All Ads Instantly

1. Open `ad_config.json` on GitHub
2. Change `"ads_enabled": true` to `"ads_enabled": false`
3. Save and commit
4. All ads stop immediately in user app — no app update needed

---

## Play Store Update Process

Since app is already live on Play Store, follow these steps to publish the update:

### Step 1 — Update version in `android/app/build.gradle.kts`
```kotlin
versionCode = 4        // increase by 1 from previous
versionName = "1.0.3"  // update version name
```

### Step 2 — Build release AAB
```
flutter clean
flutter pub get
flutter build appbundle --release
```
Output file location:
```
build/app/outputs/bundle/release/app-release.aab
```

### Step 3 — Upload to Play Store
1. Go to [play.google.com/console](https://play.google.com/console)
2. Select your app **DramaHub**
3. Left menu → **Production**
4. Click **Create new release**
5. Upload `app-release.aab`
6. Fill in release notes — example: "Performance improvements and stability fixes"
7. Click **Save** then **Review release**
8. Click **Start rollout to Production**

### Step 4 — Wait for review
- Usually takes **a few hours to 1-2 days**
- You will get email when approved
- Existing users get update automatically

---

## Important Notes

- Appodeal is set to **test mode** in debug builds automatically
- Appodeal is set to **live mode** in release builds automatically
- Always test with `flutter run` (debug) before building release
- Release build uses real ads — do not test on personal device after going live
