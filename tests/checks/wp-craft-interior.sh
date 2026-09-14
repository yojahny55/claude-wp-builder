#!/usr/bin/env bash
set -euo pipefail

# The interior-page floor.
#
# A craft build once shipped nine compositions on index.html and three on each of the
# other eleven pages -- site-head, closing-block, footer-columns, which is header, a CTA
# and a footer. The bodies were hand-rolled from one template. Every machine gate passed:
# valid markup, correct tokens, wired devices. What nothing asked was whether an interior
# page had been composed at all, or whether its motion could react to a scroll.
#
# The rules had a ceiling for interior pages ("never pin") and no floor, and "never pin"
# was read as permission to do nothing. These pins hold the floor in the two reference
# files /wp-yolo reads, since a craft yolo run never opens commands/wp-demo.md.

fail() { echo "FAIL: $*"; exit 1; }

comp=skills/wp-demo-craft/references/compositions.md
dev=skills/wp-demo-craft/references/devices.md
demo=commands/wp-demo.md
verify=bin/demo-verify.mjs

for f in "$comp" "$dev" "$demo" "$verify"; do [ -f "$f" ] || fail "$f is missing"; done

# --- the composition floor, stated where both entry points read it ------------
grep -qF 'composed, not' "$comp" \
  || fail "$comp must require interior pages to be composed, not hand-rolled"
grep -qF 'never *whether* it uses any' "$comp" \
  || fail "$comp: 'cheap roles' must constrain which compositions, not whether"
grep -qF 'not count toward that floor' "$comp" \
  || fail "$comp must exclude chrome from the interior-page floor"

# --- the motion floor ---------------------------------------------------------
grep -qF 'floor as well as a ceiling' "$dev" \
  || fail "$dev must state an interior-page floor, not only the never-pin ceiling"
grep -qF 'scroll-reactive device that is not' "$dev" \
  || fail "$dev must require a scroll-reactive device beyond reveal on interior pages"
grep -qF 'Hover is not motion on a touch screen' "$dev" \
  || fail "$dev must say why pointer devices do not satisfy the motion floor"

# --- the plan covers every page, not only the index ---------------------------
grep -qF 'covers every page in the agreed set, not only the index' "$demo" \
  || fail "$demo: the composition plan must cover interior pages too"
grep -qF 'Sum per page, not across the set' "$demo" \
  || fail "$demo: the motion budget must be summed per page"
grep -qF 'has not been built, only filled' "$demo" \
  || fail "$demo must say an uncomposed interior page is not a built page"

# --- the behavioural gate -----------------------------------------------------
# A grep pins the rule's wording. This one pins the check that catches the build,
# which is the half that was missing when the rule was only prose.
grep -qF "kind: 'static-page'" "$verify" \
  || fail "$verify must emit a static-page finding"
grep -qF 'POINTER_DEVICES' "$verify" \
  || fail "$verify must know which devices need a pointer"
grep -qE "scrollReactive" "$verify" \
  || fail "$verify must judge a page on whether any device reacts to scrolling"
# static-page must be blocking: ADVISORY findings do not fail a round, and a page
# that cannot move is not an advisory matter.
grep -qE "ADVISORY = new Set\(\[[^]]*'static-page'" "$verify" \
  && fail "$verify: static-page must not be advisory -- it has to fail the round"

echo PASS
