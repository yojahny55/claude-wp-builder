#!/usr/bin/env bash
# Findings from measuring a real build rather than guessing:
#   - "The hero is the LCP" is a guess; a directory/archive grid can put the LCP on
#     a first-row CARD instead, and a blanket loading="lazy" below the fold then
#     defers exactly the element the page is judged on. Must be measured per
#     template with a PerformanceObserver, not assumed from the homepage alone.
#   - A font preload naming the wrong weight (picking "the first N files" rather
#     than the weight the LCP text actually renders in) preloads a file the first
#     paint never uses while the one it waits on loads on demand.
#   - A visually-modal drawer/overlay that does not trap Tab/Shift+Tab lets a
#     keyboard user tab into hidden content with no way back.
#   - A cross-engine `cursor` sweep must not read WebKit's `auto` (the UA default
#     for an undeclared pointer) as "no pointer" when other engines agree it is.
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }

pf=agents/wp-audit-performance.md
[ -f "$pf" ] || fail "$pf is missing"
grep -Fq "PerformanceObserver" "$pf" || fail "$pf: no PerformanceObserver-based LCP measurement"
grep -Fq "largest-contentful-paint" "$pf" || fail "$pf: LCP measurement does not use the largest-contentful-paint entry type"
grep -Eiq 'per template' "$pf" || fail "$pf: LCP measurement is not scoped per template (a card grid can differ from the homepage hero)"

af=agents/wp-audit-a11y.md
[ -f "$af" ] || fail "$af is missing"
grep -Eiq 'focus trap' "$af" || fail "$af: no focus-trap check for overlays/drawers"
grep -Fq "aria-modal" "$af" || fail "$af: focus-trap check does not name the modal-overlay pattern it applies to"
grep -Eiq 'opens in a new tab|opens a new tab' "$af" || fail "$af: no target=_blank new-tab notice check"
grep -Eiq 'scrollable-region-focusable|tabindex="0"' "$af" || fail "$af: no scrollable-region keyboard-access check"
grep -Fq "WebKit" "$af" || fail "$af: no caveat against reading WebKit's cursor:auto as 'no pointer'"

echo PASS
