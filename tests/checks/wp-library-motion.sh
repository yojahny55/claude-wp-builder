#!/usr/bin/env bash
# An entry's strip is a grid of sampled frames: it shows what a section is MADE of, never how it
# moves. Before motion clips existed, a craft build had nothing but the strip and the entry's prose
# `motion.notes` to pick a data-motion device from, so the device was an inference from a still.
# get_motion returns the frames timestamped, at original playback speed. These assertions pin the
# instruction to read them, and pin the vocabulary gap that makes a naive 1:1 mapping wrong.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

d=commands/wp-demo.md
v=skills/wp-demo-craft/references/devices.md
# Guard both paths. The negative loop at the bottom is the one place a missing
# file would pass SILENTLY: `if grep -Fq ...` reads grep's exit 2 as "absent",
# so a vanished devices.md would report the contract intact. The positive
# assertions below all carry `|| fail`, but their wording would blame a changed
# sentence rather than a missing file.
[ -f "$d" ] || fail "$d is missing"
[ -f "$v" ] || fail "$v is missing"

# --- The tool is named, and the frames are what must be read. ----------------
grep -Fq 'call `get_motion` with that slug' "$d" \
  || fail "$d never tells a craft build to call get_motion on the entry's own slug"
grep -Fq 'motion.clips' "$d" || fail "$d does not say which entries carry a clip"
grep -Fq 'a video URL alone does not provide video understanding' "$d" \
  || fail "$d does not carry the tool's own ceiling about a bare video URL"

# --- The strip is explicitly NOT the source of timing. -----------------------
grep -Fq 'shows composition, not timing' "$d" \
  || fail "$d does not say a strip shows composition rather than timing"

# --- The vocabulary gap, in the three kinds it actually comes in. ------------
# Proven against the declared contract below, not asserted: ten map one to one, two are modifier
# attributes, three have no expression at all. Getting this wrong writes an inert attribute.
grep -Fq 'modifiers, not devices' "$d" \
  || fail "$d does not distinguish a modifier attribute from a device"
grep -Fq 'data-motion-stagger' "$d" || fail "$d does not name the stagger modifier"
grep -Fq 'data-motion-count' "$d" || fail "$d does not name the count modifier"
grep -Fq 'have no expression in the contract' "$d" \
  || fail "$d does not name the library terms the contract cannot express"

# --- The claim above must stay true of the contract it describes. ------------
# If devices.md ever gains or loses a device, this is what notices that wp-demo.md now lies.
# Pinned verbatim, order included, and that is deliberate rather than brittle:
# devices.md declares the enumeration as one literal value on one line, so this
# matches a single contract token, not a sentence that might be re-wrapped. A
# reorder fails too, which is wanted -- wp-demo.md maps the library's terms onto
# these ten by name, and a reordering is a contract edit a human should see
# rather than one a check waves through. Asserting the ten individually would
# need extra machinery to also prove an eleventh had not appeared.
grep -Fq 'data-motion="reveal|pin|pan|wipe|kinetic|parallax|drift|tilt|magnet|spotlight"' "$v" \
  || fail "$v no longer declares exactly the ten devices wp-demo.md maps the library onto"
for mod in data-motion-stagger data-motion-count; do
  grep -Fq "$mod=\"" "$v" || fail "$v no longer declares $mod=, which wp-demo.md points entries at"
done
# Quote-agnostic on purpose. A negative guard that matches one quoting style
# passes silently on the other, which is the worst failure mode for an assertion
# whose whole job is noticing drift: devices.md could start declaring
# `data-motion='marquee'` and this loop would report the contract intact while
# wp-demo.md's build-it-by-hand rule went stale. Backticked prose is already
# covered, since the pattern matches inside `data-motion="marquee"`. A bare
# unquoted data-motion=marquee is not -- but devices.md quotes every value it
# declares, including the ten-device line pinned above.
for absent in marquee stack tabs; do
  if grep -Eq "data-motion=[\"']$absent[\"']" "$v"; then
    fail "$v now declares $absent as a device, so wp-demo.md's build-it-by-hand rule is stale"
  fi
done

# --- Citation discipline: a clip is cited only when its frames were read. ----
grep -Fq 'name the clip id and the section whose motion it informed' "$d" \
  || fail "$d does not say how a consulted clip is recorded in demo/BRIEF.md"

echo PASS
