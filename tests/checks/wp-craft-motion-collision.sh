#!/usr/bin/env bash
# No direct child of a `data-motion="reveal"` section may carry its own CSS
# animation. The device does gsap.set(kids, {opacity, y}) on exactly those
# elements, so a second writer on the same element is a race — and the demo
# wins it (motion.js inlined, runs before the start keyframe applies) while the
# theme loses it (initMotion at DOMContentLoaded, by which point it has). The
# element animates in the demo and freezes at the keyframe's start value in the
# theme: measured as a conversion block stuck at scale(0.88) on 16 pages, with
# /wp-demo-verify passing that same demo 66/66.
#
# Deeper descendants are fine; reveal never touches them.
set -euo pipefail

root=skills/wp-demo-craft/compositions
test -d "$root" || { echo "FAIL: $root missing"; exit 1; }

# The rule has to be written down too, or the next composition re-learns it.
grep -q 'Never animate a transform property on a direct child' \
  skills/wp-demo-craft/references/devices.md \
  || { echo "FAIL: devices.md no longer states the collision rule"; exit 1; }

bad=0
for d in "$root"/*/; do
  name=$(basename "$d")
  html="$d/section.html"
  css="$d/section.css"
  [ -f "$html" ] && [ -f "$css" ] || continue
  grep -q 'data-motion="reveal"' "$html" || continue

  # Direct children of the section root: the elements at one indent level.
  kids=$(awk 'NR > 1 && /^  <[a-z]/ && match($0, /class="[^"]+"/) {
      c = substr($0, RSTART + 7, RLENGTH - 8); split(c, a, " "); print a[1]
    }' "$html" | sort -u)

  for k in $kids; do
    # Every declaration block whose selector list mentions this class alone,
    # then look for an animation inside it.
    hit=$(awk -v cls="$k" '
      $0 ~ "(^|,)[[:space:]]*\\." cls "[[:space:],{]" { inblock = 1 }
      inblock && /animation(-name)?[[:space:]]*:/ && !/animation[[:space:]]*:[[:space:]]*none/ { print; found = 1 }
      /}/ { inblock = 0 }
      END { exit(found ? 0 : 1) }
    ' "$css") && {
      echo "FAIL: $name — direct child .$k of a reveal root carries an animation:"
      echo "        $hit"
      bad=1
    }
  done
done

[ "$bad" -eq 0 ] || exit 1
echo PASS
