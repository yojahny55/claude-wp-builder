---
name: wp-cinematic-encode
description: Encode source videos for cinematic scroll-scrub (all-keyframe MP4) and mobile autoplay-loop (9:16 portrait crop). Thin wrapper over the kit's `scripts/encode-keyframe.sh` and `scripts/encode-mobile-portrait.sh`. Drops encoded files into `<theme>/assets/videos/` and updates the matching ACF row if `--scene=N` is provided.
arguments:
  - name: <input>
    description: Path to source MP4 (any resolution/bitrate)
    required: true
  - name: --scene
    description: Scene number to bind output to (1-N). If omitted, files land in assets/videos/ without ACF wiring.
    required: false
  - name: --desktop-only
    description: Only generate desktop all-keyframe variant
    required: false
  - name: --mobile-only
    description: Only generate 9:16 portrait variant
    required: false
  - name: --poster
    description: Also extract a poster frame (default frame 30) for reduced-motion fallback
    required: false
---

# /wp-cinematic-encode

## What it does

| Variant | Output | Used for | Encoding |
|---|---|---|---|
| Desktop | `assets/videos/scene-N.mp4` | scroll-scrub (currentTime driven by ScrollTrigger) | `-g 1 -bframes 0 -crf 23 -preset slow` — every frame is a keyframe so `video.currentTime = x` lands instantly. File is ~2-3× larger than streaming MP4; that's the price of frame-perfect scrub. |
| Mobile | `assets/videos/scene-N.mobile.mp4` | autoplay + muted + loop + playsinline | `-vf "crop=ih*9/16:ih,scale=720:1280"` center crop to 9:16, `-crf 26`, standard GOP, `-movflags +faststart`. |
| Poster | `assets/posters/scene-N.jpg` | `prefers-reduced-motion` fallback, slow-connection placeholder | `-vf "select=eq(n\,30)"` single frame, JPEG q=85. |

## Pipeline

1. Verify `ffmpeg` and `ffprobe` available (`bash -c 'command -v ffmpeg && command -v ffprobe'`).
2. Resolve kit path; locate `scripts/encode-keyframe.sh` and `scripts/encode-mobile-portrait.sh`.
3. Run scripts in parallel via Bash background jobs (encode is CPU-bound, parallel saves wall time):
   ```bash
   bash -c '<kit>/scripts/encode-keyframe.sh <input> <theme>/assets/videos/scene-<N>.mp4 &
            <kit>/scripts/encode-mobile-portrait.sh <input> <theme>/assets/videos/scene-<N>.mobile.mp4 &
            wait'
   ```
4. If `--poster`, extract frame 30 to `assets/posters/scene-<N>.jpg`.
5. Verify outputs:
   - Desktop: `ffprobe -show_frames -select_streams v:0 -read_intervals %+#10 -print_format csv | grep -c 'I'` ≥ 10 (sanity check that all-keyframe took).
   - Mobile: confirm aspect ratio = 9:16 via `ffprobe -show_entries stream=width,height`.
6. If `--scene=N` is set AND a WordPress install is reachable:
   - Run `wp media import <each output>` to add to Media Library.
   - Run `wp eval` to update the matching `cinematic_scenes` row's `video_desktop` / `video_mobile` / `poster` ACF fields to the new attachment IDs.
7. Print before/after sizes and bitrate stats.

## Failure handling

| Symptom | Cause | Fix |
|---|---|---|
| `ffmpeg: command not found` | not installed | `sudo dnf install ffmpeg` (Fedora) / `apt install ffmpeg` (Debian) |
| Scrub stutters after encode | GOP didn't apply (some codecs ignore `-g 1` without `-bf 0`) | rerun script — the kit script chains both; if still stuttering try `-x264-params "keyint=1:min-keyint=1"` |
| Mobile video portrait looks zoomed wrong | source is already 9:16 or 1:1 — center-crop math overshoots | pass `--mobile-only --keep-source-aspect` (skips crop, only re-encodes for `+faststart`) |
| WP-CLI media import fails with `Could not load image type` | MP4 mime not allowed | run `wp option update upload_filetypes "$(wp option get upload_filetypes) mp4"` |

## Cost notes

All-keyframe MP4 produces files 2-3× larger than streaming. For a 9-scene reel that means ~50-80 MB total over the wire. Acceptable for desktop hero pages; **always** ensure the mobile autoplay path uses the smaller standard-GOP file, never the desktop all-keyframe one.
