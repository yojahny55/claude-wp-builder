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
d=commands/wp-demo.md

[ -f "$m" ] || fail "$m is missing"

# --- motion.js uses `export`, so inlining it into a plain <script> is a
#     SyntaxError that silently disables all motion. The inlining instruction
#     must say type="module".
grep -Fq 'type="module"' "$d" || fail "$d does not require type=\"module\" when inlining motion.js"

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

# --- v2 engine fixes. -------------------------------------------------------
grep -Fq 'data-motion-peak' "$m" || fail "$m does not read data-motion-peak"
# Anchored to the pin branch's own guard, not a bare '> 2': that fragment is also
# satisfied by parseCue's unrelated 'n.length > 2', so it stayed green when a copy
# had its threshold mutated from 2.0 to 5.0. This exact clause is unique to the
# pin-budget warning and breaks if the threshold or the peak guard moves.
grep -Fq "span > 2 && !el.hasAttribute('data-motion-peak')" "$m" \
  || fail "$m does not gate the pin-budget warning on span > 2.0 without data-motion-peak"
grep -Fq 'line-height:1.1' "$m" || fail "$m kinetic mask does not reserve line-height headroom"
grep -Fq 'padding-block' "$m" || fail "$m kinetic mask does not pad the block edges"
grep -Fq 'H1' "$m" || fail "$m does not refuse kinetic on an h1"

# --- The second reveal path. Two engines driving one element is a race, so the
#     JS guard and the CSS feature query must test the SAME condition.
mc=starter-theme/__tailwind__/assets/css/src/tailwindcss/utilities/motion.css
[ -f "$mc" ] || fail "$mc is missing; the CSS reveal path has no home"
grep -Fq '@supports (animation-timeline: view())' "$mc" \
  || fail "$mc does not gate the CSS reveal on the feature query"
# Anchored with the trailing semicolon: the file's own header comment restates
# "animation-fill-mode: both," (with a comma) in prose, and a bare substring
# match without the semicolon is satisfied by that sentence even with the real
# declaration deleted — proved by mutation, not assumed.
grep -Fq 'animation-fill-mode: both;' "$mc" \
  || fail "$mc omits animation-fill-mode: both, so reveal snaps back on scroll up"
grep -Fq 'prefers-reduced-motion' "$mc" || fail "$mc does not honour reduced motion"
grep -Fq 'translate:' "$mc" || fail "$mc does not use translate, which parallax cannot collide with"
grep -Fq 'transform:' "$mc" && fail "$mc writes transform, which collides with the parallax device"

grep -Fq "CSS.supports('animation-timeline', 'view()')" "$m" \
  || fail "$m does not test the same feature query the stylesheet gates on"
# Not 'skip': that word already appears 4 times in $m for unrelated reasons
# (the kinetic branch's child-markup skip, the two catch-block "skipping it"
# warnings), so a bare 'skip' alternative passes whether or not the reveal
# branch says anything about yielding to CSS — proved by mutation, not assumed.
grep -Eqi 'does not wire|handled by css' "$m" \
  || fail "$m does not say it yields reveal to the CSS path"

grep -Fq './utilities/motion.css' starter-theme/__tailwind__/assets/css/src/tailwindcss/main.css \
  || fail "main.css does not import the motion stylesheet, so the theme ships without it"
# NOTE: not "$d" — the device loop above (`for d in reveal pin pan ...`) reassigns
# that variable and leaves it as "spotlight" for the rest of the script, so a
# reference to "$d" here would silently grep a nonexistent file named spotlight.
grep -Fq 'motion.css' commands/wp-demo.md \
  || fail "commands/wp-demo.md does not inline the motion stylesheet into the demo"

echo PASS
