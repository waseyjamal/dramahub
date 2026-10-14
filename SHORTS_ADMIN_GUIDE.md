# Shorts — Admin & Content Guide

Everything here is controlled by JSON on your CDN (`cdn_base`, currently `https://dramahub-data.pages.dev`).
**No app update needed** for any change below. Samples: `shorts_cdn/shorts/`.

```
$cdnBase/shorts/config.json          on/off switch + ad rules
$cdnBase/shorts/feed.json            what appears in the Shorts tab (in order)
$cdnBase/shorts/series/<id>.json     all episodes of one series
```

## 1. Turn the feature on/off
`config.json` → `"enabled": true`. When it's `false` or the file is missing, the app looks **exactly** like
before (Downloads stays in the bottom bar). When it's `true`, a **Shorts** tab appears in the second position and
Downloads moves into **Profile → Library → Downloads**.
Users who already have the app pick up the change the next time they open it.

## 2. Ads: how they work and what to set

Recommended combination (what ReelShort, Kuku TV and similar apps do), using **both** formats:

| Format | When | Why |
|---|---|---|
| **Interstitial** | Between episodes: every N episodes the user moves to | Steady revenue that doesn't interrupt a video mid-play |
| **Rewarded** | The user taps "Watch ad to unlock" on a locked episode | Highest eCPM. The user chooses to watch it, so it doesn't annoy |

`config.json → ads`:

| Key | Meaning | Default |
|---|---|---|
| `interstitial_enabled` | Interstitials in Shorts on/off | `true` |
| `interstitial_every_n_episodes` | Show one every N episodes | `4` |
| `interstitial_first_after` | No interstitial during the first N episodes of a session | `3` |
| `rewarded_unlock_enabled` | Lock episodes after the free ones. `false` = everything free | `true` |
| `unlock_episodes_per_ad` | Episodes unlocked per rewarded ad | `3` |
| `unlock_on_no_fill` | If no ad is available, unlock anyway (generous) | `false` |
| `free_episodes_default` | Free episodes per series (a series can override with `freeEpisodes`) | `10` |

**Required, one time, in your existing ad admin config:** Shorts uses your existing `AdService`, so the
existing **screen switches, cooldown and max-per-session also apply**. Add these screen keys:
- `interstitial.screens`: `"shorts_feed": true`
- `rewarded.screens`: `"shorts_unlock": true`

Without `shorts_unlock`, the rewarded ad never shows and locked episodes can't be unlocked unless
`unlock_on_no_fill` is `true`. Also note that the global rewarded `cooldown_seconds` limits how often someone can unlock.

Suggested starting values: free 10, unlock 3 per ad, interstitial every 4 after 3. Watch retention in Firebase
Analytics (`shorts_view`, `shorts_complete`, `shorts_unlock`) and adjust.

## 3. Add a new series
1. Encode and upload the videos to R2 (see §4).
2. Generate the series file:
   ```
   dart run tools/shorts_generator.dart --id my_drama --title "My Drama" --episodes 60 --free 10 \
     --description "..." --genre Romance --poster https://media.yourdomain.com/shorts/my_drama/poster.jpg \
     --hls "https://media.yourdomain.com/shorts/my_drama/ep{n}/master.m3u8" \
     --thumb "https://media.yourdomain.com/shorts/my_drama/ep{n}.jpg"
   ```
   Output: `shorts_cdn/shorts/series/my_drama.json` → upload to `$cdnBase/shorts/series/my_drama.json`.
3. Add an entry to `feed.json` (usually episode 1 as the hook):
   ```json
   { "id": "my_drama", "title": "My Drama", "description": "...", "poster": "...", "totalEpisodes": 60,
     "episode": { "n": 1, "hls": ".../ep1/master.m3u8", "thumb": ".../ep1.jpg" } }
   ```
4. Increase `data_version` in `config.json` so users get the new data right away instead of waiting for the 5-minute cache.

## 4. Video encoding (this is what makes it smooth)

| | Value |
|---|---|
| Format | HLS (`.m3u8`). MP4 with `+faststart` is the fallback |
| Resolution | 720×1280 (plus 540×960 and 360×640 variants) |
| Codec | H.264 Main, AAC 96k |
| Segment length | **2 seconds**, keyframe every 2 s |
| Poster/thumb | JPG 540×960, ≤ 60 KB |

```bash
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

# poster / thumb
ffmpeg -ss 0.5 -i in.mp4 -frames:v 1 -vf scale=540:960 -q:v 5 ep1.jpg
```
(`-g 48` assumes 24 fps; use `-g 60` for 30 fps.)

## 5. Cloudflare R2 setup
1. Cloudflare dashboard → R2 → create a bucket (e.g. `dramahub-media`).
2. Bucket → Settings → **connect a custom domain** (e.g. `media.yourdomain.com`). The default `r2.dev` URL is rate-limited and not meant for production.
3. Upload the folder structure: `shorts/<series>/ep<n>/master.m3u8`, `v0/…`, `v1/…`, `v2/…`, `ep<n>.jpg`, `poster.jpg`.
   Use `rclone` or `wrangler r2 object put` for bulk uploads.
4. Add a cache rule for the media domain: cache everything, edge TTL 1 month.
5. Cost: 10 GB of storage is free, then about $0.015/GB/month. **Egress (views) is free.**

## 6. Signed URLs (optional, later)
`"use_signed_urls": true` in the Shorts config **and** `use_signed_urls` in the main app config make the app call your
signing API with `dramaId = "shorts_<seriesId>"` and `ep = <n>`. Your signing server must support those IDs first.
Leave this `false` until it does. If signing fails, the app falls back to the raw URL.

## 7. Quick test without your own videos
Point an episode at a public HLS test stream such as
`https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8` (landscape, so the app letterboxes it).
