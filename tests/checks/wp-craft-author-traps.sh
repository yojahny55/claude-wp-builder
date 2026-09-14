#!/usr/bin/env bash
set -euo pipefail

# Traps an author falls into because the plugin never said otherwise.
#
# Every rule here was reconstructed from a real craft build, by asking the session that
# made it where it had to invent a rule. Each one cost at least a full verify round, and
# none of them was the author's error: the plugin stated a design and left its
# consequences undocumented. A rule that exists only in the head of whoever wrote the
# library is not a rule.

fail() { echo "FAIL: $*"; exit 1; }

dev=skills/wp-demo-craft/references/devices.md
taste=skills/wp-demo-craft/references/taste.md
feel=skills/wp-demo-craft/references/feel.md
comp=skills/wp-demo-craft/compositions/README.md
demo=commands/wp-demo.md
verify=bin/demo-verify.mjs
hero=skills/wp-demo-craft/compositions/hero-bleed
foot=skills/wp-demo-craft/compositions/footer-columns

for f in "$dev" "$taste" "$feel" "$comp" "$demo" "$verify"; do
  [ -f "$f" ] || fail "$f is missing"
done

# --- container-type freezes view() timelines ----------------------------------
# The library is container-query based, so putting container-type higher up reads as
# the natural next step. It kills every CSS-path reveal beneath it.
grep -qF 'Never put `container-type` on `body`' "$comp" \
  || fail "$comp must warn that container-type on an ancestor freezes view() timelines"
grep -qF 'freezes' "$comp" \
  || fail "$comp must say what container-type on an ancestor does to the timeline"
grep -qF 'containFreeze' "$verify" \
  || fail "$verify must detect the container-type declaration that freezes the timeline"
grep -qF "kind: 'dead-scroll'" "$verify" \
  || fail "$verify must still EMIT dead-scroll — a bare substring pin survives in comments"
# The hint attaches to the existing finding: the finding was right, it could not say why.
grep -qF "f.kind === 'dead-scroll' && !f.hint" "$verify" \
  || fail "$verify must name the container-type cause on dead-scroll findings"

# --- cascade order is a guarantee, not an etiquette ---------------------------
grep -qF '@layer compositions' "$demo" \
  || fail "$demo must emit composition CSS in a layer so author overrides win"
grep -qF 'your own CSS in a layer' "$demo" \
  || fail "$demo must say author CSS stays unlayered"

# --- a deliberately hidden element is not clipped copy ------------------------
grep -qF 'deliberatelyHidden' "$verify" \
  || fail "$verify must exempt visually-hidden copy from clipped-copy"
grep -qF 'aria-hidden' "$verify" \
  || fail "$verify must treat an aria-hidden subtree as deliberately hidden"
grep -qF 'clippedSeen' "$verify" \
  || fail "$verify must deduplicate clipped-copy: one element is one defect"

# --- hero-bleed clears the fold on a short frame ------------------------------
grep -qF 'align-content: center' "$hero/section.css" \
  || fail "$hero: the default must centre copy; end presses the CTA against a short fold"
grep -qF 'min-height: 700px' "$hero/section.css" \
  || fail "$hero: the bottom anchor must be restored by a HEIGHT query, not unconditionally"
grep -qF 'align-content: end' "$hero/section.css" \
  || fail "$hero: the bottom anchor is the composition's identity and must survive"

# --- footer-columns can carry the client's logo -------------------------------
grep -qF '{{logo_src}}' "$foot/section.html" \
  || fail "$foot has no logo slot, so no build can put the client's mark in the footer"
grep -qF 'footer-columns__logo' "$foot/section.css" \
  || fail "$foot: the logo slot needs its own rule, not the wordmark's display type"
grep -qF 'logo_src' "$foot/README.md" \
  || fail "$foot/README.md must document the logo slot"
grep -qF '"logo_alt"' skills/wp-demo-craft/compositions/fills.json \
  || fail "fills.json must fill logo_alt, or the preview reads the raw slot to a screen reader"

# --- pan is wrong for a short set ---------------------------------------------
grep -qF 'needs five items or more' "$dev" \
  || fail "$dev must state a minimum item count for pan"
grep -qF 'Do not put the heading in the rail' "$dev" \
  || fail "$dev must retract the heading-as-rail-item remedy: it pans the label offscreen"

# --- thresholds an author cannot guess ----------------------------------------
grep -qF '0.16em` is over the line' "$taste" \
  || fail "$taste must name the eyebrow tracking threshold the slop detector enforces"
grep -qF 'scroll budget, not a spacing preference' "$taste" \
  || fail "$taste must state the --space-section floor as a budget"

# --- the {{ check must not fail on the engine ---------------------------------
grep -qF 'rendered markup' "$demo" \
  || fail "$demo: the {{ check must read rendered markup, not the file that inlines motion.js"

# --- a bespoke section can still get a plate ----------------------------------
grep -qF 'escape hatch' "$demo" \
  || fail "$demo must document how a hand-built section gets a generated image"

# --- interior pages get their own curve ---------------------------------------
# The composition plan is written per curve, and the curve was defined for one page,
# so interior pages fell outside the step that produces plans.
grep -qF 'Interior pages get their own curve' "$feel" \
  || fail "$feel must give interior pages their own curve, or they fall outside the plan step"

echo PASS
