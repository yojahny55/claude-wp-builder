#!/usr/bin/env bash
# Two AOS seams found by scrolling a real build past its first entrance, not by
# reading the AOS docs:
#   1. aos.css rewrites transition-property/-duration/-delay on any element that
#      still carries data-aos, for as long as the attribute stays — breaking a
#      hover-lift card's or a color-fading button's OWN transition long after the
#      entrance finished. The attribute must come off once the entrance settles.
#   2. AOS measures trigger points at DOMContentLoaded, before web fonts and images
#      reflow the layout, so a block that moves afterward can end up permanently
#      below a stale trigger with `once: true`. Must re-measure on `load`.
# A third seam: the first screen looked unanimated because its LCP-critical
# elements were skipped outright to protect LCP — the skill must say to animate
# them too, with a fast plain fade, not leave them out.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $1"; exit 1; }

f=skills/wp-aos-animator/SKILL.md
[ -f "$f" ] || fail "$f is missing"

grep -Fq "removeAttribute('data-aos')" "$f" \
  || fail "$f: no removal of data-aos once the entrance settles (aos.css keeps rewriting the element's transitions otherwise)"
grep -Fq "transitionend" "$f" || fail "$f: attribute removal is not tied to the entrance's own transitionend"

grep -Fq "AOS.refresh()" "$f" || fail "$f: no AOS.refresh() call"
grep -Fq "addEventListener('load'" "$f" \
  || fail "$f: AOS.refresh() is not re-run on window 'load' (DOMContentLoaded predates font/image reflow)"

grep -Eiq 'LCP candidate|LCP element' "$f" \
  || fail "$f: no guidance for the above-the-fold LCP element — must animate it, not skip it"
grep -Fq 'data-aos="fade" data-aos-duration="400"' "$f" \
  || fail "$f: no fast-fade pattern documented for the LCP element"

grep -Eiq 'prefers-reduced-motion' "$f" || fail "$f: no reduced-motion escape hatch"

echo PASS
