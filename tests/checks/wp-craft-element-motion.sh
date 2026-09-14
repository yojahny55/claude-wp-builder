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

# --- a heading element is a role, not a size ----------------------------------
# An <h2> styled at 0.8rem does not read as small print to the type scale: it enters
# the h2 role and flattens the measured ladder for the WHOLE page. A real build
# tripped flat-type-hierarchy with `h2 12.8px, body 15.5px, h3 17.3px` -- and the
# 12.8px was three column labels in footer-columns, present on every page of every
# craft build, breaking sections that were themselves correctly proportioned.
#
# Enforced structurally rather than by prose: no heading in any composition may be
# sized below 1.1rem at the small end of its clamp. Label-sized headings are the
# defect; a label that wants to look like a label is a <p> with aria-label on its
# region.
for f in "$C"/*/section.html; do
  comp=$(basename "$(dirname "$f")")
  for cls in $(grep -oE '<h[1-6] class="[a-z-]+__[a-z0-9-]+"' "$f" \
                 | grep -oE '[a-z-]+__[a-z0-9-]+' | sort -u); do
    # The smallest size the heading can render at: the first length in its clamp,
    # or its plain font-size.
    min=$(grep -A8 "^\.$cls *{" "$C/$comp/section.css" 2>/dev/null \
            | grep -oE 'font-size: *clamp\( *[0-9.]+rem|font-size: *[0-9.]+rem' \
            | head -1 | grep -oE '[0-9.]+rem' | tr -d 'rem')
    [ -n "$min" ] || continue
    awk -v v="$min" 'BEGIN { exit !(v + 0 < 1.1) }' \
      && fail "$comp: .$cls is a heading element rendered at ${min}rem -- a label-sized heading flattens the h2/h3 role for every page it appears on"
  done
done

# footer-columns is where this was found. Its column labels must stay demoted.
grep -qE '<h[1-6][^>]*footer-columns__col-title' "$C/footer-columns/section.html" \
  && fail "footer-columns: the column labels are headings again, which flattens the type scale site-wide"
grep -qF 'aria-label' "$C/footer-columns/section.html" \
  || fail "footer-columns: demoting the labels removed their accessible names"

taste=skills/wp-demo-craft/references/taste.md

# --- cutting text must not manufacture a cadence ------------------------------
# The tempting cut is the one that leaves a contrast, which removes almost no
# information and converts a sentence into an aphorism. Three in a section is a
# cadence and impeccable names it. The bold-lead-in list format produces them as a
# set rather than one at a time.
grep -qF 'Cut inside the sentence, not at its pivot' "$taste" \
  || fail "$taste must say where a trim lands, not just that text should be shorter"
grep -qF 'bold-lead-in list format invites this' "$taste" \
  || fail "$taste must name the list shape that produces aphorisms as a set"
grep -qF 'A heading element is a role, not a size' "$taste" \
  || fail "$taste must forbid using a heading element as a small label"
grep -qF 'clears at least 1.25' "$taste" \
  || fail "$taste must state the heading-to-body ratio a component heading has to clear"

# --- an entrance must not finish before the reader arrives -------------------------
# `entry 0% entry 50%` is a working animation that nobody sees: it completes while the
# element is still grazing the bottom edge of the viewport. Every probe reports it as
# live -- a ViewTimeline exists, the keyframes ran -- and the reader reports the
# section as having no animation at all. A measured build had twelve of twelve
# selectors animating and drew exactly that complaint. `entry 100%` is the moment the
# element is fully in view, so an entrance ending at or past it is still moving when
# it is first looked at.
#
# Ranges anchored in `cover` are deliberately excluded: cover-phase endpoints are
# already past the entry phase by construction.
while IFS= read -r line; do
  f=${line%%:*}
  end=$(printf '%s' "$line" | grep -oE 'entry [0-9.]+% entry [0-9.]+%' | grep -oE '[0-9.]+%$' | tr -d '%')
  [ -n "$end" ] || continue
  awk -v v="$end" 'BEGIN { exit !(v + 0 < 100) }' \
    && fail "$f: an entrance range ends at entry ${end}%, inside the entry phase -- it finishes before the element is fully in view and reads as no animation at all"
done < <(grep -rn 'animation-range: entry [0-9.]*% entry [0-9.]*%' "$C"/*/section.css)

# The amplitude floor, for the same reason: an 18px fade at the bottom edge of a tall
# viewport is smaller than the reader's own scroll increment.
while IFS= read -r line; do
  f=${line%%:*}
  px=$(printf '%s' "$line" | grep -oE 'var\(--motion-rise, *[0-9.]+px\)' | grep -oE '[0-9.]+' | head -1)
  [ -n "$px" ] || continue
  awk -v v="$px" 'BEGIN { exit !(v + 0 < 35) }' \
    && fail "$f: --motion-rise falls back to ${px}px, below the amplitude floor where a rise stops being visible"
done < <(grep -rn 'var(--motion-rise,' "$C"/*/section.css)

grep -Fq 'An entrance ends at or past `entry 100%`' "$dev" \
  || fail "$dev does not state the entrance-range floor, so the ranges above are a convention nothing explains"
grep -Fq 'Amplitude has a floor too' "$dev" \
  || fail "$dev does not state the amplitude floor"
grep -Fq 'Two counts, not one' "$dev" \
  || fail "$dev does not separate the device count from the animated-element count, which is how a page ends up all fades"

# --- two readouts of one value must share one timeline ----------------------------
# `view()` builds a timeline from EACH ELEMENT'S OWN BOX, so two elements carrying
# identical `animation-range` declarations do not have identical progress. Measured on
# a gauge whose needle and figure read one score, at one scroll position: needle
# `currentTime -31.38%`, figure `-13.64%` -- the needle had finished its travel while
# the number still read its start value, an arrow at 850 beside a figure showing 300 in
# the same frame. Nothing reports it: every probe says both have a live ViewTimeline on
# the range they asked for, because they do. Same species as the NaN counter -- each
# part works, the composite is wrong, and only a reader catches it.
#
# A CSS counter read back from an animated custom property is the readout shape that
# ALWAYS has a partner moving somewhere else; that is the whole reason to build one.
# So a composition using that idiom has to name a timeline on the shared ancestor
# rather than leave each box to earn its own progress.
while IFS= read -r line; do
  f=${line%%:*}
  grep -Fq 'view-timeline-name' "$f" \
    || fail "$f reads a counter off an animated custom property but names no timeline -- on view() the figure and the thing it reads out get their own progress and disagree on screen"
done < <(grep -rln 'counter-reset: *[a-z-]* *var(--' "$C"/*/section.css 2>/dev/null | sed 's/$/:/')

# `counter-reset` belongs on the element, not on the pseudo that reads the counter.
grep -rn '::\(before\|after\)[^{]*{[^}]*counter-reset' "$C"/*/section.css \
  && fail "a composition sets counter-reset on the pseudo that reads it; it computes and is not trustworthy across engines -- put it on the element"

grep -Fq 'share a named timeline' "$dev" \
  || fail "$dev does not state that two elements displaying one value share a named timeline"
grep -Fq 'Two counters, and which one is a mistake' "$dev" \
  || fail "$dev does not separate the clock-driven counter from the scroll-driven one, so a readout that must track motion gets the tool that cannot"

echo PASS
