#!/usr/bin/env bash
# The __cinematic__ nav ships a hamburger, a mobile-menu dialog and a motion toggle.
# Markup without CSS renders the dialog unstyled on every viewport; markup without JS
# leaves the button dead and the looping videos with no pause (WCAG 2.2.2). Pins all three.
set -euo pipefail
cd "$(dirname "$0")/../.."
d=starter-theme/__cinematic__
css=$d/assets/css/cinematic.css
js=$d/assets/js/cinematic-engine.js
nav=$d/template-parts/cinematic/nav.php

grep -qE '^\.nav__hamburger' "$css" || { echo "FAIL: no .nav__hamburger rule"; exit 1; }
grep -qE '^\.mobile-menu' "$css" || { echo "FAIL: no .mobile-menu rule"; exit 1; }
grep -q '\.mobile-menu\[aria-hidden="true"\]' "$css" || { echo "FAIL: closed state of .mobile-menu not styled"; exit 1; }
grep -qE '^\.nav__hamburger,\.mobile-menu\{display:none\}' "$css" || { echo "FAIL: hamburger/menu not hidden by default (desktop)"; exit 1; }
grep -q "'Escape'" "$js" || { echo "FAIL: engine does not close the menu on Escape"; exit 1; }
grep -q 'inert' "$js" || { echo "FAIL: engine does not toggle inert on the menu"; exit 1; }
grep -q "'Tab'" "$js" || { echo "FAIL: engine does not trap Tab in the open menu"; exit 1; }
[ "$(grep -c 'nav__motion-toggle' "$nav")" -ge 2 ] || { echo "FAIL: nav.php needs a motion toggle outside the mobile menu too"; exit 1; }
grep -q 'data-label-pause' "$nav" && grep -q 'data-label-play' "$nav" || { echo "FAIL: toggle labels missing"; exit 1; }
# Every play() call must be guarded by the shared paused state.
unguarded=$(grep -n '\.play' "$js" | grep -v 'motionPaused' || true)
# The resume path plays only inside the !motionPaused branch; allow lines in applyMotion.
unguarded=$(echo "$unguarded" | grep -v 'getBoundingClientRect\|r.bottom' || true)
[ -z "$unguarded" ] || { echo "FAIL: unguarded play(): $unguarded"; exit 1; }
grep -q 'if (motionPaused)' "$js" || { echo "FAIL: pause branch missing"; exit 1; }
# Under reduced motion nothing plays, so the toggle is hidden rather than left offering a
# "Play motion" that changes its label and starts nothing.
grep -q 'if (reducedAtLoad) toggles.forEach' "$js" || { echo "FAIL: motion toggles are not hidden under reduced motion"; exit 1; }
grep -q 'toggles.length && !reducedAtLoad' "$js" || { echo "FAIL: motion toggles are wired under reduced motion"; exit 1; }
# The label changes with the state, so the button is an action button: aria-pressed beside
# a changing label announces the opposite of the real state.
if grep -q 'aria-pressed' "$nav" "$js"; then echo "FAIL: motion toggle combines aria-pressed with a changing label"; exit 1; fi
echo PASS
