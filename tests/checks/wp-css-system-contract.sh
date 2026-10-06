#!/usr/bin/env bash
# wp-css-system's worked examples are what an agent copies, so they must obey the rules the
# same skill states. Two did not:
#   - the grid example was a bare `repeat(3, 1fr)` with no one-column base, so a copied
#     section rendered three columns on a phone, against the house mobile-first rule;
#   - the outline button (`.btn--secondary`) was a border on a transparent background, the
#     shape the skill's contour rule replaces with an inset box-shadow, under a second name
#     for the `.btn--outline` the skill itself uses.
set -uo pipefail
# `q "$text" <grep flags> <pattern>`: a here-string, never `printf | grep -q`. Under
# pipefail an early-exiting `grep -q` hands printf a SIGPIPE and the pipeline returns 141,
# which silently flips an assertion either way.
q() { local s=$1; shift; grep -q "$@" <<<"$s"; }
cd "$(dirname "$0")/../.." || { echo "FAIL: cannot cd to the repository root"; exit 1; }
fail() { echo "FAIL: $*"; exit 1; }

skill=skills/wp-css-system/SKILL.md
pat=skills/wp-css-system/references/patterns.md
for f in "$skill" "$pat"; do [ -f "$f" ] || fail "$f is missing"; done

# Rule blocks of patterns.md's ```css fences, one per line: `selector { declarations }`,
# with the @media wrapper kept on the inner rule's line so a mobile-first step is visible.
# Comments are dropped first so a comment's words cannot become a selector. The comment
# pattern lets a `*` stand inside the body (`/** … */`, `/* a * b */`), which `[^*]*` did not.
code=$(awk '/^```css/{f=1; next} /^```/{f=0} f' "$pat" | tr '\n' ' ' | sed -E -e 's#/\*([^*]|\*+[^*/])*\*+/##g' -e 's/  */ /g')
rules=$(printf '%s' "$code" | grep -oE '(@media[^{]*\{ *)?[.a-z_][^{}]*\{[^{}]*\}' | sed 's/^ *//' || true)
[ -n "$rules" ] || fail "no CSS rules parsed from $pat"

# 1. Every multi-column grid template sits inside a min-width step; the base is one column.
multi=$(printf '%s\n' "$rules" | grep -E 'grid-template-columns: *repeat\( *[2-9]' || true)
if [ -n "$multi" ]; then
  q "$multi" -v '@media *(min-width' \
    && fail "$pat sets a multi-column grid outside a min-width step — a phone gets every column: $(printf '%s\n' "$multi" | grep -v '@media' | head -1)"
fi
q "$rules" -E '^\.services__grid *\{[^}]*grid-template-columns: *1fr' \
  || fail "$pat's grid example has no one-column mobile base"

# 2. The outline button is the inset-shadow form, under the skill's own name.
grep -Fq '.btn--secondary' "$pat" && fail "$pat still names the outline button .btn--secondary — a second name for .btn--outline"
out=$(printf '%s\n' "$rules" | grep -E '^\.btn--outline *\{' || true)
[ -n "$out" ] || fail "$pat has no .btn--outline rule"
q "$out" -F 'inset 0 0 0 1px' || fail "$pat's .btn--outline is not drawn with the inset box-shadow contour"
q "$out" -E 'border: *[0-9]+px' && fail "$pat's .btn--outline draws its contour with a border"

echo PASS
