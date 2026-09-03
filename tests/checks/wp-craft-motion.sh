#!/usr/bin/env bash
# The motion engine is the one piece of shipped behaviour in an otherwise prose plugin, and
# it is the seam between the demo and the theme. Every assertion pins a promise the craft
# skill makes to a demo author: an attribute they were told to write must actually be read,
# and the accessibility floor must hold without them asking for it.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

m=starter-theme/__tailwind__/assets/js/src/motion.js
i=starter-theme/__tailwind__/assets/js/src/index.js
p=starter-theme/__tailwind__/package.json

[ -f "$m" ] || fail "$m is missing"

# --- Every documented attribute is actually read. ---------------------------
for a in data-motion data-motion-span data-motion-cue data-motion-rate \
         data-motion-stagger data-motion-count data-motion-dir data-motion-drift \
         data-motion-rail; do
  grep -Fq "$a" "$m" || fail "$m never reads the attribute: $a"
done

# --- Every documented device is implemented. Plain substring, because the
#     devices appear in three shapes: 'pin' in a comparison, "tilt" inside an
#     attribute selector, and count inside data-motion-count.
for d in reveal pin pan wipe kinetic parallax count drift tilt magnet spotlight; do
  grep -Fq "$d" "$m" || fail "$m does not implement the device: $d"
done

# --- The CSS seam. Bespoke effects are driven from this property. -----------
grep -Fq -- '--motion-p' "$m" || fail "$m does not publish --motion-p"

# --- Accessibility is not opt-in. -------------------------------------------
grep -Fq 'prefers-reduced-motion' "$m" || fail "$m does not honour prefers-reduced-motion"
grep -Fq '(hover: hover)' "$m" || fail "$m does not gate pointer devices to fine pointers"

# --- The performance floor from taste.md, enforced in code. -----------------
grep -Fq 'transition: all' "$m" && fail "$m uses transition: all, which taste.md forbids"
grep -Eq '\.style\.(top|left|width|height)[^a-zA-Z]' "$m" \
  && fail "$m animates a layout property; use transform/opacity/clip-path"

# --- Dual entry: inline in a demo, imported in the theme bundle. ------------
grep -Fq 'export function initMotion' "$m" || fail "$m does not export initMotion"
grep -Fq 'window.WPMotion' "$m" || fail "$m does not expose window.WPMotion for inline demo use"

# --- Theme wiring. Motion that is not enqueued is motion that died at conversion.
grep -Fq '"gsap"' "$p" || fail "$p does not depend on gsap"
grep -Fq 'ScrollTrigger' "$i" || fail "$i does not register ScrollTrigger"
grep -Fq 'initMotion' "$i" || fail "$i does not initialise motion"

echo PASS
