#!/usr/bin/env bash
# wp-audit-a11y's A11Y-025/026 fix used to be a bare global `:focus-visible { outline }`.
# On a build whose form fields already had a design focus border, every field then showed
# two indicators, and nothing flagged it because each one passed on its own. The fix must
# inventory existing focus styles first, replace a failing design colour instead of
# stacking a ring on it, and measure with getComputedStyle. The tailwind starter's default
# ring must be unable to stack on a component's own (zero specificity, base layer).
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

a=agents/wp-audit-a11y.md
fix=$(awk '/^\*\*A11Y-025\/026 fix/{on=1} on&&/^\*\*A11Y-060 fix/{exit} on' "$a")
[ -n "$fix" ] || fix=$(cat "$a")

# The old bare global rule is gone.
printf '%s\n' "$fix" | grep -qE '^:focus-visible \{' \
  && fail "$a still ships a bare global :focus-visible rule as the A11Y-025/026 fix"
printf '%s\n' "$fix" | grep -Fq 'one focus indicator per element' || fail "$a's fix does not state one indicator per element"
printf '%s\n' "$fix" | grep -Fq 'Inventory before writing' || fail "$a's fix does not inventory components with their own focus style first"
printf '%s\n' "$fix" | grep -Fq 'replaced, not stacked' || fail "$a's fix does not replace a design focus colour that fails 3:1"
printf '%s\n' "$fix" | grep -Fq 'getComputedStyle(el)' || fail "$a's fix does not measure before and after"
printf '%s\n' "$fix" | grep -Fq ':where(' || fail "$a's global ring is not zero-specificity"

r=starter-theme/__tailwind__/assets/css/src/tailwindcss/base/reset.css
grep -Fq ':where(a[href], button' "$r" || fail "$r's default focus ring is not wrapped in :where()"
grep -Eq '^:focus-visible|^\*:focus-visible' "$r" && fail "$r carries a specificity-bearing global focus rule"
grep -Fq 'focus:outline-none' starter-theme/__tailwind__/assets/css/src/tailwindcss/components/buttons.css \
  || fail ".btn draws a ring without clearing the outline, so the base ring stacks on it"

echo PASS
