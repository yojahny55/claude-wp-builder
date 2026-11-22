#!/usr/bin/env bash
# agents/wp-template.md is loaded whole on every section dispatch, so conditional
# blocks (nav walker, carousels, CSS backgrounds, demo controls, archive queries)
# live in skills/wp-theme-standards/references/template-*.md and the agent reads
# them only when the case applies. This check keeps that split honest: every
# reference is pointed to, every pointer resolves, and the agent stays under the
# size budget so the blocks do not creep back in.
set -euo pipefail
cd "$(dirname "$0")/../.."
# shellcheck source=../lib/assert.sh
source tests/lib/assert.sh

agent=agents/wp-template.md
refdir=skills/wp-theme-standards/references
limit=32768

for ref in "$refdir"/template-*.md; do
  [ -e "$ref" ] || fail "no $refdir/template-*.md references found"
  grep >/dev/null -Fc "$ref" <(sed "s#\${CLAUDE_PLUGIN_ROOT}/##g" "$agent") \
    || fail "$agent does not point to $ref"
  grep >/dev/null -Fc "$(basename "$ref")" skills/wp-theme-standards/SKILL.md \
    || fail "skills/wp-theme-standards/SKILL.md does not list $ref"
done

while IFS= read -r target; do
  [ -f "$target" ] || fail "$agent points to missing $target"
done < <(grep -o '\${CLAUDE_PLUGIN_ROOT}/skills/wp-theme-standards/references/template-[a-z-]*\.md' "$agent" | sed 's#^\${CLAUDE_PLUGIN_ROOT}/##' | sort -u)

size=$(wc -c < "$agent")
[ "$size" -le "$limit" ] || fail "$agent is $size bytes, over the $limit budget: move a conditional block to a template-*.md reference"
echo PASS
