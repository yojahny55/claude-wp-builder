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

# --- the four silent-failure rules are written where motion is written -------
# The second of these used to pin the claim that a duration on a scroll-driven
# animation "overrides the range and the element plays through on its own clock".
# That was wrong, and the pin made it durable. Measured in Chrome with the repo's
# own playwright-core: two rules identical but for `animation-duration: auto`
# against `2s`, sampled at six scroll positions, produced the same value at every
# one -- 13.165, 79.0622, 95.4148, 99.9709, 100, 100. The duration is recorded in
# the timing and ignored. The advice (leave it off) survives; the reason changed,
# so the pin has to change with it or the file keeps teaching a false model.
grep -qF 'Longhands only' "$dev" \
  || fail "$dev: the animation shorthand resets animation-timeline; say so"
grep -qF 'A duration on a scroll-driven animation is inert' "$dev" \
  || fail "$dev: a duration on a scroll timeline is ignored, not obeyed; say so"
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
# `:nth-of-type`, not `:nth-child` -- these plans are <th> preceded by a <td> corner
# cell, so :nth-child counted the corner and every rung was off by one. This pin
# matched the old spelling and went to zero when that was fixed, which is the right
# way round: it failed loudly on a real change rather than passing on a stale one.
ot_ranges=$(grep -oE ':nth-of-type\([0-9]\) *\{ *animation-range: [^;}]+' "$C/offer-table/section.css" \
  | sed 's/.*animation-range: //' | sort -u | wc -l) || true
[ "$ot_ranges" -ge 3 ] \
  || fail "offer-table: columns must arrive on their own ranges ($ot_ranges distinct, need 3)"

grep -qE 'nth-(child|of-type)\(6n\+[0-9]\)' "$C/faq-list/section.css" \
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
  if awk '
    /@keyframes [a-z-]*-(rise|plate|fade)/ { in_block = 1; depth = 0 }
    in_block {
      if (/transform[[:space:]]*:/) exit 1
      line = $0
      depth += gsub(/{/, "{", line)
      depth -= gsub(/}/, "}", line)
      if (depth <= 0) in_block = 0
    }
  ' "$f"; then :; else
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
grep -qE 'score-scale__marker[^>]*>[[:space:]]*</div>' "$C/score-scale/section.html" \
  || fail "score-scale: the marker must stay empty -- a number on it is a claim"
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
    min=$(grep -E -A8 "(^|,)[[:space:]]*\.$cls([^a-zA-Z0-9_-]|$)" "$C/$comp/section.css" 2>/dev/null \
            | grep -oE 'font-size: *clamp\( *[0-9.]+rem|font-size: *[0-9.]+rem' \
            | head -1 | grep -oE '[0-9.]+rem' | tr -d 'rem') || true
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

# --- a loop that never states its timeline is wrong or lucky ----------------------
# A scroll timeline is INHERITED from any broader rule that hands one out, and
# motion.css gives descendants of a `reveal` section their own view(). An animation
# that means to loop on a clock and lands on a scroll timeline does not loop: it
# reports playState "finished" and sits at its start value forever. Measured on a
# 2s infinite sweep inside such a subtree -- timeline=ViewTimeline, duration=2000,
# finished, value pinned at 0, never moved -- against the same rule stating
# auto/normal, which ran on the DocumentTimeline and swept while the page was still.
#
# This is checkable without false positives, which the "two selectors share a range"
# idea is not: `animation-iteration-count: infinite` plus a finite
# `animation-duration` plus no explicit `animation-timeline` in the same rule is
# either wrong or lucky, and lucky only until a section wraps it.
loose=$(
  for f in "$C"/*/section.css; do
    awk -v F="$f" '
      /\{/ { inrule = 1; buf = "" }
      inrule { buf = buf $0 " " }
      /\}/ {
        if (inrule && buf ~ /animation-iteration-count: *infinite/ &&
            buf ~ /animation-duration: *[0-9.]+m?s/ && buf !~ /animation-timeline/)
          print F
        inrule = 0
      }' "$f"
  done
)
[ -z "$loose" ] || fail "these declare a clock loop with a duration and no animation-timeline -- if any ancestor rule hands them view() they report finished and never move, so state \`animation-timeline: auto\` and \`animation-range: normal\`:
$loose"

grep -Fq 'There are two coupling mechanisms' "$dev" \
  || fail "$dev names only one way to couple two readouts; a clock-driven pair is coupled by identical timing longhands, not by a timeline name"
grep -Fq 'motionless whenever the reader is' "$dev" \
  || fail "$dev does not state the cost of scroll-scrubbing a readout, which is the reason one build's gauge was a still picture"
grep -Fq 'A duration on a scroll-driven animation is inert' "$dev" \
  || fail "$dev has lost the measured correction about animation-duration on a scroll timeline"
grep -Fq 'needs `animation-timeline: auto` and' "$dev" \
  || fail "$dev does not state that a clock loop near scroll-driven CSS must declare auto/normal"

# --- every silent-failure rule carries the measurement that produced it -----------
# A silent-failure rule is by definition one nobody has cause to test: the advice is
# followed, nothing breaks, and the stated REASON is never exercised. So a wrong
# reason survives indefinitely, and is found only when someone reasons forward from
# it. Two of the four in this list were wrong that way -- one said a duration hijacks
# a scroll-driven animation when it is inert, one said the element falls back to its
# `from` value when it falls back to its un-animated value -- and both had been read
# many times, because the advice attached to them was correct.
#
# The cheap enforcement is that each numbered item carries a figure someone can
# disbelieve and re-run. It cannot tell a real measurement from a plausible number,
# so it is a floor and not a proof; what it does stop is the next rule landing as
# bare assertion, which is how both of these got in.
list=$(awk '/^Four ways this fails silently/ { on = 1; next }
            on && /^\*\*Use `translate`/ { exit }
            on { print }' "$dev")
[ -n "$list" ] || fail "$dev: cannot find the silent-failure list -- if it was renamed, re-anchor this check rather than dropping it"

n=0
while IFS= read -r item; do
  n=$((n+1))
  # A bare digit is not enough, and proving that took a mutation: stripping every
  # measured figure out of rules 1 and 3 left this check GREEN, because both quote
  # CSS values (`2s`, `10`, `90`) in their prose and a digit test cannot tell a
  # quoted declaration from an observation. So require the claim to be marked as
  # measured AND to carry a figure. Still a floor -- it cannot tell a real number
  # from a plausible one -- but it stops the shape both wrong reasons arrived in.
  printf '%s' "$item" | grep -qi 'measured' \
    || fail "$dev: silent-failure rule $n gives a reason that is not marked as measured. A rule nobody has cause to test is never exercised, so a wrong reason survives until someone reasons forward from it -- say what was observed: $(printf '%s' "$item" | cut -c1-70)"
  printf '%s' "$item" | grep -qE '[0-9]+\.[0-9]+|=[0-9]|`[0-9]+`' \
    || fail "$dev: silent-failure rule $n says it was measured but carries no figure to re-run: $(printf '%s' "$item" | cut -c1-70)"
done < <(printf '%s\n' "$list" | awk '
  /^[0-9]+\. / { if (buf != "") print buf; buf = $0; next }
  /^   / { buf = buf " " $0; next }
  { if (buf != "") { print buf; buf = "" } }
  END { if (buf != "") print buf }')

[ "$n" -ge 4 ] || fail "$dev: expected at least 4 silent-failure rules, parsed $n -- the list parser has drifted from the file's shape and is asserting nothing"

grep -Fq 'carries the measurement that produced it' "$dev" \
  || fail "$dev does not state that a silent-failure rule must carry its measurement, which is the rule that catches a correct rule with a false reason"

# --- stagger ladders put their rungs out of order in three independent ways -------
# Grouping the rules of one ladder needs real parsing -- a ladder is spread over N
# rules and which rules belong to it is not a grep -- so the scan lives in
# tests/checks/lib/ladder-scan.py, which documents each fault and the measurement
# behind it. The three:
#
#   1. `:nth-child` counts the parent's OTHER children. offer-table's plans are <th>
#      after a <td> corner cell and were off by one in the shipped markup: plan 1
#      received the rule written for plan 2, and the :nth-child(1) rule matched
#      nothing at all. `:nth-of-type` cannot be shifted by a sibling of another type.
#   2. `entry X%` and `cover X%` are not comparable. `entry 100%` sits at
#      min(h,vh)/(vh+h) of cover -- measured at exactly that across eight
#      element/viewport pairs, from cover 11.8% to cover 47.1% -- so a ladder that
#      switches unit is ordered only at the geometry it was written against.
#   3. A rung past the last written index falls back to `normal` (= cover 0% to
#      cover 100%), unrelated to the stagger.
#
# A fourth cause is not visible in one file and is asserted separately: rungs on
# `view()` each build a timeline from their own box, so a monotonic ladder still
# fires out of order when the elements differ in height. That is the shared-timeline
# rule above.
ladders=$(python3 "$(dirname "$0")/lib/ladder-scan.py" "$C") \
  || fail "ladder-scan.py failed to run"
[ -z "$ladders" ] || fail "stagger ladders are out of order:
$ladders"

grep -Fq 'the section stops being a sequence' "$C/process-flow/section.css" \
  || fail "process-flow has lost the note explaining why the guard is on the list and not on the sixth step"

# --- the measurement rules, and the exemption that must be argued -----------------
# Every wrong number produced while writing the ladder rules -- on both sides of the
# review -- came from reading the rendered value when the question was about the
# timeline. `getComputedStyle` and `getBoundingClientRect` both go through the timing
# function, so an eased reading is not progress and a transformed box is not a layout
# box. Recording the distinction is the only thing that stops it recurring.
grep -Fq 'two readouts, and they answer different questions' "$dev" \
  || fail "$dev does not separate animation.currentTime from the computed property; that conflation produced four wrong measurements"
grep -Fq 'Eased readings are not progress' "$dev" \
  || fail "$dev does not warn that a computed property is eased, which put entry 100% at cover 52.8% instead of 30.8%"
grep -Fq 'returns the transformed box' "$dev" \
  || fail "$dev does not warn that getBoundingClientRect reports the scaled box mid-animation"
grep -Fq 'An override can conceal what it overrode' "$dev" \
  || fail "$dev does not record that a flattening override hides a broken ladder -- 'all correct' and 'all identical' look the same"

# The scan cannot tell a deliberately mixed-type flow from a broken ladder, so the
# exemption is authored. It must not be a silent bypass: assert the marker carries a
# reason, by running the scanner over a fixture with and without one.
tmp=$(mktemp -d)
mkdir -p "$tmp/mixed"
cat > "$tmp/mixed/section.css" <<'FIXTURE'
.cn > * { animation-name: rise; animation-fill-mode: both; animation-timeline: --t; }
.cn > *:nth-child(1) { animation-range: entry 10% entry 110%; }
.cn > *:nth-child(2) { animation-range: entry 16% entry 116%; }
.cn > *:nth-child(n+3) { animation: none; }
FIXTURE
scan="$(dirname "$0")/lib/ladder-scan.py"
# Each assertion names the finding it wants. `-n` alone is not enough and proving that
# took a mutation: with the :nth-child branch disabled the fixture still emitted its
# catch-all finding, so a test for "some output" stayed green while the rule it names
# had been removed.
nth_finding() { python3 "$scan" "$1" | grep -c 'indexes a stagger by :nth-child'; }

[ "$(nth_finding "$tmp")" -ge 1 ] \
  || fail "ladder-scan.py does not flag :nth-child at all -- the rule is not enforced"

printf '/* ladder-scan: allow-nth-child .cn > * */\n' >> "$tmp/mixed/section.css"
[ "$(nth_finding "$tmp")" -ge 1 ] \
  || fail "ladder-scan.py accepts a bare allow-nth-child marker with no reason, which makes the exemption a silent bypass"

printf '/* ladder-scan: allow-nth-child .cn > * -- label, link and step in one flow */\n' >> "$tmp/mixed/section.css"
[ -z "$(python3 "$scan" "$tmp")" ] \
  || fail "ladder-scan.py refuses a reasoned exemption, so a genuinely mixed-type flow has no legal spelling: $(python3 "$scan" "$tmp")"
rm -rf "$tmp"

echo PASS
