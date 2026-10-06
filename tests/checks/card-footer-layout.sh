#!/usr/bin/env bash
# A converted demo kept `mt-auto` on each card's link; the generated template dropped it,
# and price + link floated at a different height in every card with shorter text. The
# template authors must carry every layout utility from the demo (card = flex flex-col,
# h-full in a grid, footer mt-auto), never re-derive the layout.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

# The card contract moved out of SKILL.md into a reference file the skill links to.
sk=skills/wp-tailwind-system/references/components.md
grep -Fq "references/components.md" skills/wp-tailwind-system/SKILL.md \
  || fail "skills/wp-tailwind-system/SKILL.md no longer links $sk, so no agent reaches the card contract"
grep -Fq '## Cards pin their footer with `mt-auto`' "$sk" || fail "$sk has no card-footer section"
for f in "$sk" agents/wp-template.md agents/wp-tailwind.md; do
  grep -Fq 'mt-auto' "$f" || fail "$f never names mt-auto for the card footer"
  grep -Fq 'flex flex-col' "$f" || fail "$f does not make the card a flex column"
done
grep -Fq 'Layout utilities are carried, never re-derived' agents/wp-template.md \
  || fail "agents/wp-template.md does not forbid re-deriving the demo's layout utilities"
grep -Fq 'never re-derive the layout' "$sk" || fail "$sk does not forbid re-deriving the layout"

echo PASS
