#!/usr/bin/env bash
# The wp-demo skeleton is what a demo's <style> block is copied from, and it ended in a
# trailing "Section: Responsive" block of @media (max-width: …) queries — desktop-first, against
# the min-width-only rule in wp-demo's own SKILL.md and in wp-responsive, and outside every
# section's block, so a section's CSS could not move to its template part whole. A demo built
# from it inherits both defects.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

d=skills/wp-demo
sk=$d/references/demo-skeleton.md
[ -f "$sk" ] || fail "$sk is missing"

! grep -rEn '@media[^{]*max-width' "$d" \
  || fail "$d carries a max-width media query; demos are mobile-first, min-width only"
grep -Eq '@media \(min-width: [0-9]+px\) \{ \.services' "$sk" \
  || fail "$sk no longer shows a section's own min-width steps inside its block"
! grep -Fq 'Section: Responsive' "$sk" \
  || fail "$sk is back to a trailing Responsive block instead of per-section steps"

echo PASS
