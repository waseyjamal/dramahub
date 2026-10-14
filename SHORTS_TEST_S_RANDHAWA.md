# Test guide: S Randhawa (1 episode) — copy & paste

Your file: `sr-1.mp4`. Change `E:\SRandhawa\` below to the real folder on your PC.

| Thing | Value |
|---|---|
| Series ID | `s_randhawa` |
| R2 folder | `dramahub-videos/shorts/s_randhawa/` |
| Video link | `https://cdn.dramahubs.stream/shorts/s_randhawa/sr-1.mp4` |
| Poster link | `https://cdn.dramahubs.stream/shorts/s_randhawa/poster.jpg` |

---

## Step 1: Make the MP4 "fast start" (required for MP4, takes about 10 seconds)
```
ffmpeg -i "E:\SRandhawa\sr-1.mp4" -c copy -movflags +faststart "E:\SRandhawa\upload\sr-1.mp4"
```
(Create the `E:\SRandhawa\upload` folder first. The quality stays the same.)

## Step 2: Make a poster (vertical image)
```
ffmpeg -ss 3 -i "E:\SRandhawa\sr-1.mp4" -frames:v 1 -vf scale=540:960 -q:v 5 "E:\SRandhawa\upload\poster.jpg"
```
(Or use your own vertical image. Just name it `poster.jpg` and put it in the `upload` folder.)

## Step 3: Upload to R2
```
rclone copy "E:\SRandhawa\upload" r2dramahub:dramahub-videos/shorts/s_randhawa/ --progress
```

## Step 4: Check that the links open in your browser
- https://cdn.dramahubs.stream/shorts/s_randhawa/sr-1.mp4 → the video should play
- https://cdn.dramahubs.stream/shorts/s_randhawa/poster.jpg → the image should show

If they don't open, stop here. The upload path or the file name is wrong.

---

## Step 5: Admin panel → Shorts tab → Series → **Add series**
| Field | Type this |
|---|---|
| Title | `S Randhawa` |
| ID | `s_randhawa` (fills in by itself; check it) |
| Description | anything |
| Poster URL | `https://cdn.dramahubs.stream/shorts/s_randhawa/poster.jpg` |
| Free episodes | `10` |
| Video type | **MP4** |
| Episode URL pattern | `https://cdn.dramahubs.stream/shorts/s_randhawa/sr-{n}.mp4` |
| Thumbnail pattern | leave empty |
| Number of episodes uploaded | `1` |
| Show in app right away | ✅ |

Click **Save**. Then use the ⋮ menu → **Open episode 1 link**. The video should open.

> ⚠ The admin auto-fills the pattern as `.../ep-{n}/index.m3u8` (HLS). After choosing MP4, **replace it** with the
> `sr-{n}.mp4` pattern above, because your file is named `sr-1`, not `ep-1`.

## Step 6: Admin panel → Shorts → **Settings**
- Turn **Shorts enabled** ON
- Click **Save settings**

## Step 7: Admin panel → **Ads**
- Interstitial screens: turn ON **Shorts Feed**
- Rewarded screens: turn ON **Shorts Unlock**
- Save

---

## Step 8: Check the data is live
Open in your browser:
- https://dramahub-data.pages.dev/shorts/config.json → should show `"enabled": true`
- https://dramahub-data.pages.dev/shorts/feed.json → should show `s_randhawa`

⚠ If you get a **404**, Cloudflare Pages isn't deploying the `shorts` folder (this was happening earlier).
Check Cloudflare → Workers & Pages → `dramahub-data` → Deployments. The app can't see Shorts until these links work.

## Step 9: Run the app with Shorts on your phone
Connect the phone with USB debugging, then:
```
cd C:\Projects\drama_hub
git checkout feature/shorts
flutter run
```
(Use `flutter run --release` to judge real smoothness. Debug mode is always slower.)

## Step 10: Test in the app
1. Close and reopen the app once, so it reads the new config.
2. The bottom bar should show **Home · Shorts · Watchlist · History · Profile**.
3. Tap **Shorts** and S Randhawa episode 1 should play.
4. Try: tap = pause, double-tap = ❤ save, hold = 2× speed, drag the bottom bar = seek.
5. Tap **Watch full series** → series screen → **Episodes** shows episode 1.
6. Profile → Library → **Downloads** still opens your old downloads.

---

## Later: adding episode 2
```
ffmpeg -i "E:\SRandhawa\sr-2.mp4" -c copy -movflags +faststart "E:\SRandhawa\upload\sr-2.mp4"
rclone copy "E:\SRandhawa\upload\sr-2.mp4" r2dramahub:dramahub-videos/shorts/s_randhawa/ --progress
```
Admin → Shorts → S Randhawa ⋮ → **Add new episodes** → type `2` → Add. Done.

## If something fails
| Problem | Fix |
|---|---|
| No Shorts tab | Check Step 8 links; check that Shorts enabled is ON; restart the app |
| Shorts tab but "Couldn't load" | `feed.json` link is 404 → Cloudflare Pages issue (Step 8) |
| Black screen / "Couldn't play" | The video link doesn't open in the browser, or you skipped Step 1 |
| Video takes long to start | You skipped Step 1 (faststart), or the file is very large |


ffmpeg -i "E:\SRandhawa\sr-1.mp4" -c copy -movflags +faststart "E:\SRandhawa\upload\sr-1.mp4"
