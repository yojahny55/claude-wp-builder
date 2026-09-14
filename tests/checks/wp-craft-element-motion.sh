#!/usr/bin/env bash
set -euo pipefail

# Element motion: the half of "motion" that costs nothing and was rationed anyway.
#
# The device kit gives a section ONE device, and rich motion is many elements arriving
# on their own timelines inside one section. The attribute contract cannot express that;
# per-element scroll-driven CSS does it trivially. Until compositions carried it, a build
# that composed faithfully got one `reveal` per section and read as static -- while the
# scroll budget it was supposedly respecting sat a quarter unspent, because that budget
# meters page length and never metered animation at all.

fail() { echo "FAIL: $*"; exit 1; }

dev=skills/wp-demo-craft/references/devices.md
dmd=skills/wp-demo-craft/references/design-md.md
C=skills/wp-demo-craft/compositions

for f in "$dev" "$dmd"; do [ -f "$f" ] || fail "$f is missing"; done

# --- the two kinds of motion are distinguished, and only one is budgeted ------
grep -qF 'Two kinds of motion, and only one of them has a budget' "$dev" \
  || fail "$dev must separate scroll choreography from element animation"
grep -qF 'not budgeted, not capped, and' "$dev" \
  || fail "$dev must say element animation is uncapped"
grep -qF 'It meters viewport-heights of added scroll, and nothing else' "$dev" \
  || fail "$dev: the budget paragraph must say what it meters, or it reads as a motion cap"
grep -qF 'Restraint is about scroll, never about life' "$dev" \
  || fail "$dev must say a restrained page still moves"

# --- the three silent-failure rules are written where motion is written ------
grep -qF 'Longhands only' "$dev" \
  || fail "$dev: the animation shorthand resets animation-timeline; say so"
grep -qF 'No `animation-duration`' "$dev" \
  || fail "$dev: a duration overrides the range; say so"
grep -qF 'animation-fill-mode: both' "$dev" \
  || fail "$dev: without fill-mode both, above-fold elements flash to their from value"

# --- the arity block and the way past it -------------------------------------
grep -qF 'One attribute, one device' "$dev" \
  || fail "$dev must state that data-motion holds one value"
grep -qF 'element motion first, root attribute second' "$dev" \
  || fail "$dev must say how a composition frees its root attribute"

# --- compositions actually carry element motion ------------------------------
# Six of these shipped `reveal` as their only device. A rule nothing implements is
# the failure this whole check exists to catch.
for c in page-head hero-type feature-zigzag offer-table faq-list testimonial-pair icon-row; do
  [ -f "$C/$c/section.css" ] || fail "$C/$c/section.css is missing"
  grep -qF 'animation-timeline: view()' "$C/$c/section.css" \
    || fail "$c carries no element motion: composing it faithfully still yields a static section"
  grep -qF '@supports not (animation-timeline: view())' "$C/$c/section.css" \
    || fail "$c has no fallback: without a view timeline its elements would hold their from state"
done

# Staggering must be per-element ranges, not one root reveal. Pin the shape on the
# compositions whose whole point is a sequence.
# Staggered means DISTINCT ranges. A pin that only proves one column carries a
# range passes on four identical ones, which is exactly the state it exists to
# forbid -- four columns animating in unison is not a stagger.
ot_ranges=$(grep -oE ':nth-child\([0-9]\) *\{ *animation-range: [^;}]+' "$C/offer-table/section.css" \
  | sed 's/.*animation-range: //' | sort -u | wc -l)
[ "$ot_ranges" -ge 3 ] \
  || fail "offer-table: columns must arrive on their own ranges ($ot_ranges distinct, need 3)"

grep -qE 'nth-child\(6n\+[0-9]\)' "$C/faq-list/section.css" \
  || fail "faq-list: rows must arrive in sequence"

# --- the icon composition ----------------------------------------------------
# `icon` appeared in the craft rules only as a prohibition, and animated icons were a
# direct client request. A refuse-list line is not a reason to have no capability.
[ -d "$C/icon-row" ] || fail "there is no icon composition"
grep -qF 'stroke-dashoffset' "$C/icon-row/section.css" \
  || fail "icon-row must draw its icons on, not fade them in"
grep -qF 'stroke-dasharray' "$C/icon-row/section.css" \
  || fail "icon-row needs a dash length or the draw does nothing"
grep -qF '| capability | icon-row |' "$C/README.md" \
  || fail "icon-row is not in the role table, so no build will find it"
grep -qF '"icon-row"' "$C/fills.json" \
  || fail "icon-row has no preview fills"
for f in preview-1440.png preview-390.png; do
  [ -s "$C/icon-row/$f" ] || fail "icon-row is missing $f"
done

# --- the design references reach motion --------------------------------------
# 67 reference sites, 57 mentioning motion, and the token mapping read none of it.
grep -qF '## Motion mapping' "$dmd" \
  || fail "$dmd must extract motion from the reference, not only colour and type"
grep -qF -- '--ease-entry' "$dmd" || fail "$dmd must map the entry easing"
grep -qF -- '--motion-rise' "$dmd" || fail "$dmd must map the arrival distance"
# The tokens are worthless unless the compositions read them.
for c in page-head feature-zigzag icon-row; do
  grep -qF 'var(--ease-entry' "$C/$c/section.css" \
    || fail "$c hardcodes its easing, so a reference's motion cannot reach it"
done

# --- transform collision ------------------------------------------------------
# The engine writes `transform` for parallax, magnet and cue rise, and `reveal`
# writes it on every child. A keyframe of ours that also writes `transform` replaces
# that instead of composing with it, and the last declaration wins -- so one of the
# two motions silently vanishes. `translate`/`scale`/`rotate` compose. This shipped
# wrong once: every entrance keyframe used `transform: translateY()`, on exactly the
# compositions that carry a root `reveal`.
grep -qF 'Use `translate`, `scale` and `rotate`, never `transform`' "$dev" \
  || fail "$dev must forbid transform in element keyframes"
for f in "$C"/*/section.css; do
  if awk '/@keyframes [a-z-]*-(rise|plate|fade)/ { if (/transform:/) exit 1 }' "$f"; then :; else
    fail "$(basename "$(dirname "$f")"): an entrance keyframe writes transform, which races the engine"
  fi
done

# --- a later rule inherits the earlier timeline --------------------------------
grep -qF 'Restate every `animation-*` longhand' "$dev" \
  || fail "$dev must warn that a second rule inherits animation-timeline from the first"

# --- motion lives in the composition -------------------------------------------
grep -qF 'Motion belongs in the composition, not beside it' "$dev" \
  || fail "$dev must say why element motion lives in section.css"
grep -qF 'silent no-op' "$dev" \
  || fail "$dev must say a guessed class name fails silently"

# --- hover is elevation, not a halo --------------------------------------------
grep -qF 'Hover states: elevation, never a halo' "$dev" \
  || fail "$dev must spec hover as depth, not an accent glow"
# And the library must not ship the thing it forbids.
if grep -l 'box-shadow[^;]*color-mix[^;]*--color-accent' "$C"/*/section.css >/dev/null 2>&1; then
  fail "a composition ships an accent-tinted glow, which impeccable reads as slop"
fi

# --- the --motion-p idiom is demonstrated --------------------------------------
grep -qF 'Driving a plain property off `--motion-p`' "$dev" \
  || fail "$dev must demonstrate reading --motion-p directly inside a scrubbed section"

# --- a modifier on the container root ------------------------------------------
grep -qF 'modifier class on the container root' "$C/README.md" \
  || fail "$C/README.md must warn that a modifier on the container root cannot match its own query"

# --- the explainer composition ------------------------------------------------
# The library was nine-of-fourteen text only: every composition a heading and some
# paragraphs, so every page came out the same shape and "less text" had nothing to
# become. score-scale is the first composition that draws data instead of describing
# it, and its numbers are published fact rather than a claim about a client.
[ -d "$C/score-scale" ] || fail "there is no explainer composition"
grep -qF '280fr 90fr 70fr 60fr 51fr' "$C/score-scale/section.css" \
  || fail "score-scale: bands must be drawn at their real point spans, not as equal blocks"
grep -qF 'score-scale-travel' "$C/score-scale/section.css" \
  || fail "score-scale: the marker must travel the range"

# taste.md refuses invented statistics, and the distinction this composition rests on
# is that a published band edge is not one. The marker therefore carries no value: a
# needle reading "580 to 720" is a claim about results, in the one industry where that
# claim attracts regulators. The band edges are hardcoded rather than slotted, because
# a slot invites a build to change them and a changed edge is misinformation.
grep -qF 'score-scale__marker">' "$C/score-scale/section.html" \
  && fail "score-scale: the marker must stay empty -- a number on it is a claim"
grep -qF '300' "$C/score-scale/section.html" \
  || fail "score-scale: the real band edges belong in the markup, not in slots"
grep -qF 'scale_caption' "$C/score-scale/section.html" \
  || fail "score-scale must name its scoring model, or the figure is uncheckable"
grep -qF '"score-scale"' "$C/fills.json" || fail "score-scale has no preview fills"
grep -qF '| explainer | score-scale |' "$C/README.md" \
  || fail "score-scale is not in the role table, so no build will find it"
for f in preview-1440.png preview-390.png; do
  [ -s "$C/score-scale/$f" ] || fail "score-scale is missing $f"
done

echo PASS
