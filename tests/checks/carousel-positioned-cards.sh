#!/usr/bin/env bash
# A real build scrolled sideways at every width: the A11Y-032 new-tab notice, a
# position:absolute screen-reader span, sat in the "see more" link of each carousel card.
# Its containing block was a container ABOVE the overflow-x:auto strip, so the strip never
# clipped it, and every off-screen card's span widened the document. It shows in no
# screenshot. The carousel rules must require positioned cards, the A11Y-032 fix must warn
# about it where it adds the span, and both must name the document-width check.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

# The carousel rules live in a reference the agent is told to read; assert on both.
t=$(mktemp); trap 'rm -f "$t"' EXIT
cat agents/wp-template.md skills/wp-theme-standards/references/template-carousels.md > "$t"
a=agents/wp-audit-a11y.md

grep -Fq 'Every card inside the scrolling element is `relative`' "$t" \
  || fail "$t does not require positioned cards inside a scrolling strip"
grep -Fq 'containing block' "$t" \
  || fail "$t does not say why: overflow clips only boxes whose containing block is inside it"
grep -Fq 'scrollWidth <= document.documentElement.clientWidth' "$t" \
  || fail "$t does not give the document-width check that catches an invisible escapee"

grep -Fq 'the card needs `position: relative`' "$a" \
  || fail "$a adds an absolute screen-reader span to new-tab links without warning about scrolling strips"
grep -Fq 'scrollWidth <= clientWidth' "$a" \
  || fail "$a does not tell the fixer to check the document width after adding the span"

# The warning must sit with the A11Y-032 fix, where the span is added, not somewhere else.
awk '/A11Y-032 fix/ { f = 1 } f && /A11Y-033 fix/ { exit } f && /position: relative/ { found = 1 } END { exit !found }' "$a" \
  || fail "$a has the positioned-card warning outside the A11Y-032 fix block"

echo PASS
