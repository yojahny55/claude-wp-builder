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

echo PASS
