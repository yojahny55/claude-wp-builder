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
# The section ends at the next **A11Y-NNN header, whichever it is; an empty section fails.
fix=$(awk '/^\*\*A11Y-025\/026 fix/{on=1; print; next} on&&/^\*\*A11Y-[0-9]/{exit} on' "$a")
[ -n "$fix" ] || fail "$a has no **A11Y-025/026 fix section"

# A bare or universal :focus-visible anywhere in a selector list carries specificity and
# stacks on a component's own indicator: at column 0, indented, inside @layer/@media, or
# after a comma or combinator. `:where(...):focus-visible` and `.foo:focus-visible` are fine.
# Comments are stripped first, so prose that names the pseudo-class is not a hit.
bare_focus() {
  perl -0777 -ne 's{/\*.*?\*/}{}gs; exit(/(?:^|[\s,>+~{])\*?:focus-visible\b/m ? 0 : 1)'
}
# Self-test: the detector must catch these and pass these, or every result below is noise.
for bad in ':focus-visible { outline: 0 }' '*:focus-visible{}' '@layer base {\n  :focus-visible { outline: 0 }\n}' \
           'a, :focus-visible { outline: 0 }' '@media (hover) { .x > :focus-visible {} }'; do
  printf '%b\n' "$bad" | bare_focus || fail "self-test: bare_focus missed: $bad"
done
for ok in ':where(a, button):focus-visible { outline: 0 }' '.btn:focus-visible {}' 'a:focus-visible, .b:focus-visible {}' \
          '/* a bare :focus-visible rule is wrong */' '.x:not(:focus-visible) {}'; do
  printf '%b\n' "$ok" | bare_focus && fail "self-test: bare_focus flagged: $ok"
done

# The old bare global rule is gone from the fix's CSS.
fixcss=$(printf '%s\n' "$fix" | awk '/^ *```css/{on=1; next} on&&/^ *```/{on=0} on')
[ -n "$fixcss" ] || fail "$a's A11Y-025/026 fix has no css block"
printf '%s\n' "$fixcss" | bare_focus \
  && fail "$a still ships a bare or universal :focus-visible rule as the A11Y-025/026 fix"
printf '%s\n' "$fix" | grep -Fq 'one focus indicator per element' || fail "$a's fix does not state one indicator per element"
printf '%s\n' "$fix" | grep -Fq 'Inventory before writing' || fail "$a's fix does not inventory components with their own focus style first"
printf '%s\n' "$fix" | grep -Fq 'replaced, not stacked' || fail "$a's fix does not replace a design focus colour that fails 3:1"
printf '%s\n' "$fix" | grep -Fq 'getComputedStyle(el)' || fail "$a's fix does not measure before and after"
printf '%s\n' "$fix" | grep -Fq ':where(' || fail "$a's global ring is not zero-specificity"

r=starter-theme/__tailwind__/assets/css/src/tailwindcss/base/reset.css
grep -Fq ':where(a[href], button' "$r" || fail "$r's default focus ring is not wrapped in :where()"
bare_focus < "$r" && fail "$r carries a specificity-bearing global focus rule"
# The doc's ring is the starter's ring: same selector list, same outline.
where_list() {
  perl -0777 -ne 's{/\*.*?\*/}{}gs; s/\s+/ /g; print "$1\n" if /(:where\([^{}]*\):focus-visible)/'
}
doc_list=$(printf '%s\n' "$fixcss" | where_list)
starter_list=$(where_list < "$r")
[ -n "$starter_list" ] && [ "$doc_list" = "$starter_list" ] \
  || fail "$a's ring selector ($doc_list) differs from $r's ($starter_list)"
outline_decl() { grep -oE 'outline: *[^;]+;' | head -1; }
[ "$(printf '%s\n' "$fixcss" | outline_decl)" = "$(outline_decl < "$r")" ] \
  || fail "$a's ring outline differs from $r's"
grep -Fq 'focus-visible:outline-none' starter-theme/__tailwind__/assets/css/src/tailwindcss/components/buttons.css \
  || fail ".btn draws a ring without clearing the outline, so the base ring stacks on it"

echo PASS
