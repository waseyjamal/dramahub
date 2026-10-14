# Shorts — Upload & Management Guide (step by step)

How your system works, end to end:

```
 Your PC ──rclone──▶ R2 bucket ──▶ https://cdn.dramahubs.stream/shorts/...   (videos + posters)
 Your PC ──git push─▶ GitHub dramahub-data ──▶ https://dramahub-data.pages.dev/shorts/...  (JSON)
 App reads JSON from pages.dev → plays videos from cdn.dramahubs.stream
```
This is the same pipeline you already use for normal dramas. Shorts only adds a `shorts/` folder in both places.

---

## A. One-time setup

1. **Data repo** (done): `dramahub-data/shorts/` exists with:
   - `config.json`: the on/off switch and ad settings (`"enabled": false` for now)
   - `feed.json`: the list of series shown in the Shorts tab (empty `[]` for now)
   - `series/_example.json`: a template. It isn't listed in the feed, so the app never shows it.
2. **Ad config** (`ad_config.json`, through your admin panel), add:
   - under the interstitial `screens`: `"shorts_feed": true`
   - under the rewarded `screens`: `"shorts_unlock": true`
3. **App**: build and release the app version that contains Shorts.

---

## B. Prepare the videos

### HLS or MP4? Both work.
| | HLS (`index.m3u8`) | MP4 |
|---|---|---|
| Works in app | ✅ | ✅ |
| Start speed / smoothness | ⭐ Best (loads 2-sec pieces) | Good, **if faststart is on** |
| Long episodes (10+ min) | ⭐ Best | OK, but seeking is a little slower |
| Effort | Needs ffmpeg conversion | Upload almost as-is |

**Recommendation:** HLS for the best experience, which is what you already do for Off-Campus. MP4 is fine too, but it
**must** have "faststart". Otherwise the phone downloads the whole file before playing. Fix any MP4 like this
(it's fast, with no quality loss):
```
ffmpeg -i input.mp4 -c copy -movflags +faststart ep-1.mp4
```
If an episode has both `hls` and `mp4`, the app tries HLS first and falls back to MP4 automatically.

### HLS conversion (single quality, same as your current setup)
```
ffmpeg -i input.mp4 -vf scale=720:1280 -c:v libx264 -profile:v main -preset fast -b:v 1800k -maxrate 2000k -bufsize 3000k \
  -g 48 -keyint_min 48 -sc_threshold 0 -c:a aac -b:a 96k \
  -f hls -hls_time 2 -hls_playlist_type vod -hls_segment_filename "ep-1/seg_%03d.ts" ep-1/index.m3u8
```
(`-hls_time 2` gives a fast start in the swipe feed. Use `-g 60` if your video is 30 fps.)

### Poster (one per series, required)
A vertical JPG of about 540×960 and under 100 KB, named `poster.jpg`.
```
ffmpeg -ss 2 -i input.mp4 -frames:v 1 -vf scale=540:960 -q:v 5 poster.jpg
```

### Local folder layout before upload
```
lost_heiress/
  poster.jpg
  ep-1/index.m3u8 + seg_000.ts ...     ← HLS
  ep-2/index.m3u8 + ...
  (or, for MP4:  ep-1.mp4, ep-2.mp4 ...)
```
**Series id rules:** lowercase, no spaces, use `_` (e.g. `lost_heiress`). It must be the same in the R2 folder, the JSON file name and the feed.

---

## C. Upload to R2 (rclone)
```
rclone copy ./lost_heiress r2:<your-bucket>/shorts/lost_heiress --progress
```
Check that one URL opens in a browser:
`https://cdn.dramahubs.stream/shorts/lost_heiress/poster.jpg`

---

## D. Create the series JSON (generator, from the `drama_hub` folder)

HLS:
```
dart run tools/shorts_generator.dart --id lost_heiress --title "The Lost Heiress" --episodes 80 --free 10 ^
  --genre Romance --description "A poor girl discovers she is a billionaire's lost daughter." ^
  --poster "https://cdn.dramahubs.stream/shorts/lost_heiress/poster.jpg" ^
  --hls "https://cdn.dramahubs.stream/shorts/lost_heiress/ep-{n}/index.m3u8" ^
  --out ../dramahub_admin/dramahub-data/shorts/series
```
MP4: replace the `--hls` line with
`--mp4 "https://cdn.dramahubs.stream/shorts/lost_heiress/ep-{n}.mp4"`

`{n}` becomes 1, 2, 3, and so on. The file is written straight into the data repo as `shorts/series/lost_heiress.json`.
(The `^` line breaks are for Windows cmd. In Git Bash use `\`, or put everything on one line.)

---

## E. Show it in the Shorts tab — edit `dramahub-data/shorts/feed.json`
Add one entry per series. Episode 1 is the "hook" people see while swiping:
```json
[
  {
    "id": "lost_heiress",
    "title": "The Lost Heiress",
    "description": "A poor girl discovers she is a billionaire's lost daughter.",
    "poster": "https://cdn.dramahubs.stream/shorts/lost_heiress/poster.jpg",
    "totalEpisodes": 80,
    "episode": { "n": 1, "hls": "https://cdn.dramahubs.stream/shorts/lost_heiress/ep-1/index.m3u8" }
  }
]
```
The order in this list is the order in the app, so put your best series first.

---

## F. Publish
1. In `shorts/config.json`: increase `data_version` by 1 (and set `"enabled": true` the first time).
2. Push the data repo:
   ```
   cd C:\Projects\dramahub_admin\dramahub-data
   git add shorts && git commit -m "Shorts: add lost_heiress" && git push
   ```
3. Cloudflare Pages deploys within about a minute. Users see it on their next app open.

---

## G. Daily work: adding new episodes to an existing series
1. Convert the new episode → `rclone copy` → `shorts/lost_heiress/ep-81/`
2. Rerun the generator with `--episodes 81` (it rewrites the whole file, so the old episodes stay).
3. Change `totalEpisodes` to 81 in `feed.json`.
4. Increase `data_version` → push.

## H. Other controls (all in JSON, no app update)
| Want to… | Do this |
|---|---|
| Hide the whole Shorts tab | `config.json` → `"enabled": false` |
| Remove a series from the tab | Delete its entry from `feed.json` (users who saved it can still open it from My List) |
| Make a series fully free | Generator `--free 9999`, or set `"freeEpisodes": 9999` in its file |
| Lock or unlock one specific episode | In the series file, on that episode: `"locked": true` / `"locked": false` |
| Fewer or more ads | `config.json → ads` (see SHORTS_ADMIN_GUIDE.md §2) |
| Help low-end phones | `"max_players": 2` |

## I. Checklist when something doesn't play
- Does the URL open in a browser? (Check the m3u8 and the poster.)
- Is the series id spelled exactly the same in the R2 folder, the file name and `feed.json`?
- Is it MP4 without faststart? Fix it with the ffmpeg command in B.
- Did you forget to increase `data_version`? The app caches JSON for 5 minutes.
- Is the JSON valid? Paste it into jsonlint.com.
