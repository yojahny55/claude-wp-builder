#!/usr/bin/env bash
# A global colour or link fix written with a broad selector repaints cards whose text sits on an
# overlay; a `:not([data-theme=...])` guard never excludes dark mode when the attribute lives on
# <html> and the guard reads <body>; and a dark-mode measurement taken mid-transition reads false
# blacks. The agent has to say how to scope the selector and how to measure it, and the CSS skill
# has to say where overrides go.
set -uo pipefail
cd "$(dirname "$0")/../.." || { echo "FAIL: cannot cd to the repository root"; exit 1; }

a11y=agents/wp-audit-a11y.md
css=skills/wp-css-system/SKILL.md
for f in "$a11y" "$css"; do
  [ -f "$f" ] || { echo "FAIL: $f is missing"; exit 1; }
done
flata=$(tr '\n' ' ' < "$a11y" | sed 's/  */ /g')
flatc=$(tr '\n' ' ' < "$css" | sed 's/  */ /g')

printf '%s' "$flata" | grep -Fq 'narrowest selector' \
  || { echo "FAIL: $a11y does not tell a global colour fix to use the narrowest selector"; exit 1; }
printf '%s' "$flata" | grep -Fq 'document.documentElement' \
  || { echo "FAIL: $a11y does not say to look for the theme switch attribute on document.documentElement versus body"; exit 1; }
printf '%s' "$flata" | grep -Eiq 'overlay|text over image' \
  || { echo "FAIL: $a11y does not name overlay / text-over-image cards as a context to measure"; exit 1; }
printf '%s' "$flata" | grep -Fq 'transition' \
  || { echo "FAIL: $a11y does not warn that dark-mode measurement needs transitions off or finished"; exit 1; }
printf '%s' "$flata" | grep -Fq 'getComputedStyle' \
  || { echo "FAIL: $a11y does not verify the :not() exclusion with getComputedStyle"; exit 1; }

printf '%s' "$flatc" | grep -Fq 'Overrides at the End of the Stylesheet' \
  || { echo "FAIL: $css has no section on end-of-sheet overrides"; exit 1; }
printf '%s' "$flatc" | grep -Eiq 'overlay|text over an image' \
  || { echo "FAIL: $css does not say to exclude overlay cards from a broad override"; exit 1; }

echo "PASS: global colour fixes are scoped narrowly and measured across light, dark, overlay, hover and focus"
