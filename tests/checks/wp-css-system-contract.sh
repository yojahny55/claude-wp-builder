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
# Comments are dropped first so a comment's words cannot become a selector.
code=$(awk '/^```css/{f=1; next} /^```/{f=0} f' "$pat" | tr '\n' ' ' | sed -e 's#/\*[^*]*\*/##g' -e 's/  */ /g')
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
q "$code" -F '.hero__container' && fail "$pat re-declares the .container utility as .hero__container"

# ---------------------------------------------------------------------------
# The rest of the contract, which nothing pinned: an edit could drop any of it silently.
# ---------------------------------------------------------------------------
tokens=skills/wp-css-system/references/tokens.md
reset=skills/wp-css-system/references/reset.md
agent=agents/wp-css.md
for f in "$tokens" "$reset" "$agent"; do [ -f "$f" ] || fail "$f is missing"; done

# 3. BEM: two levels, never a sub-element.
grep -Fq 'Maximum two levels' "$skill" || fail "$skill lost the two-level BEM limit"
grep -Fq 'never `.block__element__subelement`' "$skill" || fail "$skill no longer names the sub-element form as the one to avoid"

# 4. One delimiter form — twelve `=` each side — in the skill, its references and the agent
#    that writes section CSS. Any other width is a second house style.
for f in "$skill" "$reset" "$pat" "$agent"; do
  odd=$(grep -E '/\* *=+ *Section:' "$f" | grep -vE '/\* ={12} Section: [A-Za-z][A-Za-z -]* ={12} \*/' || true)
  [ -z "$odd" ] || fail "$f writes a section delimiter that is not the twelve-'=' form: $odd"
done
grep -Fq 'twelve `=` on each side' "$skill" || fail "$skill does not state the delimiter width"

# 5. The token inventory the skill promises is the one tokens.md declares.
for t in --color-primary --color-secondary --color-tertiary \
         --color-neutral-50 --color-neutral-100 --color-neutral-200 --color-neutral-300 --color-neutral-400 \
         --color-neutral-500 --color-neutral-600 --color-neutral-700 --color-neutral-800 --color-neutral-900 \
         --spacing-xs --spacing-sm --spacing-md --spacing-lg --spacing-xl --spacing-2xl --spacing-3xl \
         --font-size-xs --font-size-sm --font-size-base --font-size-xl --font-size-2xl --font-size-3xl \
         --font-size-4xl --font-size-5xl --font-size-6xl --container-max; do
  grep -Eq "^[[:space:]]*$t:" "$tokens" || fail "$tokens no longer declares $t, which $skill promises"
done

# 6. The reset is all bare selectors — a class or scope in it is the (0,1,1) trap the skill
#    warns about — and SKILL.md links it.
grep -Fq 'references/reset.md' "$skill" || fail "$skill does not link references/reset.md"
rsel=$(awk '/^```css/{f=1; next} /^```/{f=0} f' "$reset" | sed 's#/\*[^*]*\*/##g' | grep -E '^[^ {}][^{]*[{,]?$' | grep -E '\.[a-z]|#[a-z]' || true)
[ -z "$rsel" ] || fail "$reset scopes a reset selector with a class or id: $rsel"

# 7. The contour lint is run from the plugin, with its exit codes.
grep -Fq 'node "${CLAUDE_PLUGIN_ROOT}/bin/css-contour-lint.mjs"' "$skill" \
  || fail "$skill names the contour lint without the plugin-rooted command to run it"
q "$(tr '\n' ' ' < "$skill")" -F 'Exit 0 = pass, 1 =' || fail "$skill does not state the contour lint's exit codes"

echo PASS
