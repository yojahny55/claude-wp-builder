#!/usr/bin/env bash
#
# wp-cinematic-encode.sh
#
# Thin runner that drives the cinematic-scroll-kit ffmpeg scripts and
# (optionally) imports the outputs into a WordPress install via wp-cli.
#
# Usage:
#   wp-cinematic-encode.sh <input.mp4> --theme=<theme-dir> [--scene=N] [--desktop-only] [--mobile-only] [--poster] [--kit=<kit-dir>]
#
# Examples:
#   wp-cinematic-encode.sh raw.mp4 --theme=wp-content/themes/kairos-systemic --scene=3 --poster
#   wp-cinematic-encode.sh raw.mp4 --theme=. --kit=~/.skills/yojahny55/cinematic-scroll-kit

set -euo pipefail

INPUT=""
THEME=""
SCENE=""
KIT_DIR=""
DESKTOP_ONLY=0
MOBILE_ONLY=0
POSTER=0
KEEP_SOURCE_ASPECT=0

err()  { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; }
info() { printf '\033[36m→ %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m✓ %s\033[0m\n' "$*"; }

# ---- parse args ----------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --theme=*)               THEME="${1#*=}"; shift ;;
    --scene=*)               SCENE="${1#*=}"; shift ;;
    --kit=*)                 KIT_DIR="${1#*=}"; shift ;;
    --desktop-only)          DESKTOP_ONLY=1; shift ;;
    --mobile-only)           MOBILE_ONLY=1; shift ;;
    --poster)                POSTER=1; shift ;;
    --keep-source-aspect)    KEEP_SOURCE_ASPECT=1; shift ;;
    -h|--help)
      sed -n '3,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    -*) err "Unknown flag: $1"; exit 2 ;;
    *)  INPUT="$1"; shift ;;
  esac
done

[[ -z "$INPUT" ]] && { err "Missing <input.mp4>"; exit 2; }
[[ -z "$THEME" ]] && { err "Missing --theme=<theme-dir>"; exit 2; }
[[ ! -f "$INPUT" ]] && { err "Input not found: $INPUT"; exit 1; }
[[ ! -d "$THEME" ]] && { err "Theme dir not found: $THEME"; exit 1; }

# ---- locate ffmpeg -------------------------------------------------------
command -v ffmpeg >/dev/null || { err "ffmpeg not installed. (Fedora: sudo dnf install ffmpeg)"; exit 1; }
command -v ffprobe >/dev/null || { err "ffprobe not installed."; exit 1; }

# ---- locate kit ----------------------------------------------------------
if [[ -z "$KIT_DIR" ]]; then
  for candidate in \
    "$HOME/.skills/yojahny55/cinematic-scroll-kit" \
    "$(pwd)/.cinematic-kit" \
    "$THEME/assets/cinematic-kit"; do
    if [[ -d "$candidate/scripts" ]]; then KIT_DIR="$candidate"; break; fi
  done
fi
[[ -z "$KIT_DIR" || ! -d "$KIT_DIR/scripts" ]] && {
  err "cinematic-scroll-kit not found. Install with: npx skills add yojahny55/cinematic-scroll-kit -g -y"
  exit 1
}
info "Kit:   $KIT_DIR"
info "Theme: $THEME"
info "Input: $INPUT"

# ---- target paths --------------------------------------------------------
OUT_DIR="$THEME/assets/videos"
POSTER_DIR="$THEME/assets/posters"
mkdir -p "$OUT_DIR" "$POSTER_DIR"

base="scene"
[[ -n "$SCENE" ]] && base="scene-$SCENE"
OUT_DESKTOP="$OUT_DIR/${base}.mp4"
OUT_MOBILE="$OUT_DIR/${base}.mobile.mp4"
OUT_POSTER="$POSTER_DIR/${base}.jpg"

# ---- encode (parallel) ---------------------------------------------------
pids=()

if [[ $MOBILE_ONLY -eq 0 ]]; then
  info "Encoding desktop (all-keyframe): $OUT_DESKTOP"
  bash "$KIT_DIR/scripts/encode-keyframe.sh" "$INPUT" "$OUT_DESKTOP" >/tmp/wp-cine-desktop.log 2>&1 &
  pids+=($!)
fi

if [[ $DESKTOP_ONLY -eq 0 ]]; then
  info "Encoding mobile (9:16 portrait): $OUT_MOBILE"
  if [[ $KEEP_SOURCE_ASPECT -eq 1 ]]; then
    ffmpeg -y -i "$INPUT" -c:v libx264 -crf 26 -preset slow -movflags +faststart -an "$OUT_MOBILE" >/tmp/wp-cine-mobile.log 2>&1 &
  else
    bash "$KIT_DIR/scripts/encode-mobile-portrait.sh" "$INPUT" "$OUT_MOBILE" >/tmp/wp-cine-mobile.log 2>&1 &
  fi
  pids+=($!)
fi

if [[ $POSTER -eq 1 ]]; then
  info "Extracting poster frame: $OUT_POSTER"
  ffmpeg -y -i "$INPUT" -vf "select=eq(n\,30)" -frames:v 1 -q:v 5 "$OUT_POSTER" >/tmp/wp-cine-poster.log 2>&1 &
  pids+=($!)
fi

fail=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then fail=1; fi
done
[[ $fail -ne 0 ]] && { err "One or more encodes failed. Check /tmp/wp-cine-*.log"; exit 1; }

# ---- verify --------------------------------------------------------------
if [[ -f "$OUT_DESKTOP" ]]; then
  ikeys=$(ffprobe -loglevel error -select_streams v:0 -show_frames -read_intervals %+#10 -print_format csv "$OUT_DESKTOP" | grep -c ',I,' || true)
  if [[ "$ikeys" -lt 10 ]]; then
    err "All-keyframe verification failed for $OUT_DESKTOP (only $ikeys I-frames in first 10). Re-encode required."
  else
    ok "Desktop verified: ${ikeys} I-frames in first 10 — scrub-ready."
  fi
fi
if [[ -f "$OUT_MOBILE" ]]; then
  dims=$(ffprobe -loglevel error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$OUT_MOBILE")
  ok "Mobile encoded: ${dims}"
fi

# ---- WordPress import (optional) -----------------------------------------
if [[ -n "$SCENE" ]] && command -v wp >/dev/null && wp core is-installed --path="$THEME/../../.." >/dev/null 2>&1; then
  WP_PATH="$(cd "$THEME/../../.." && pwd)"
  info "Importing to Media Library at $WP_PATH"
  desktop_id=""; mobile_id=""; poster_id=""
  [[ -f "$OUT_DESKTOP" ]] && desktop_id=$(wp --path="$WP_PATH" media import "$OUT_DESKTOP" --porcelain 2>/dev/null || true)
  [[ -f "$OUT_MOBILE"  ]] && mobile_id=$(wp --path="$WP_PATH"  media import "$OUT_MOBILE"  --porcelain 2>/dev/null || true)
  [[ -f "$OUT_POSTER"  ]] && poster_id=$(wp --path="$WP_PATH"  media import "$OUT_POSTER"  --porcelain 2>/dev/null || true)

  if [[ -n "$desktop_id$mobile_id$poster_id" ]]; then
    # Update the matching ACF row on the home page.
    wp --path="$WP_PATH" eval "
      \$home = (int) get_option('page_on_front');
      if (\$home && function_exists('have_rows')) {
        \$idx = max(1, (int) '$SCENE');
        \$row = [];
        if ('$desktop_id') \$row['video_desktop'] = (int) '$desktop_id';
        if ('$mobile_id')  \$row['video_mobile']  = (int) '$mobile_id';
        if ('$poster_id')  \$row['poster']        = (int) '$poster_id';
        if (\$row) { update_row('cinematic_scenes', \$idx, \$row, \$home); echo \"Row \$idx updated.\n\"; }
      } else { echo \"No home page set or ACF unavailable; skipped ACF wiring.\n\"; }
    "
    wp --path="$WP_PATH" cache flush >/dev/null 2>&1 || true
    ok "ACF row $SCENE updated."
  fi
fi

ok "Done."
