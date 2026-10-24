#!/usr/bin/env bash
# An element the demo shows only on mobile needs a min-width override that hides it or
# dissolves its wrapper. wp-css must state the rule, show the pair, and ask for the
# list-and-confirm pass before it returns the file.
set -euo pipefail
cd "$(dirname "$0")/../.."

f=agents/wp-css.md
[ -f "$f" ] || { echo "FAIL: $f missing"; exit 1; }
t=$(tr '\n' ' ' < "$f" | sed -e 's/  */ /g')

grep -Fq '### An element that exists only on mobile is hidden by the desktop query' "$f" \
  || { echo "FAIL: $f has no section on mobile-only elements"; exit 1; }
grep -Eq 'min-width: 1024px\) \{ \.mobile-nav__footer \{ display: none; \} \.mobile-nav__links \{ display: contents; \}' <<<"$t" \
  || { echo "FAIL: the example does not pair display: none and display: contents in a min-width query"; exit 1; }
grep -Eq 'list every mobile-only class and confirm' <<<"$t" \
  || { echo "FAIL: no list-and-confirm step before the file is returned"; exit 1; }
grep -Eq '^14\. \*\*Every mobile-only element has a desktop override' "$f" \
  || { echo "FAIL: the rules list does not repeat the desktop-override rule"; exit 1; }
echo PASS
