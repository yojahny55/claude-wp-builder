#!/usr/bin/env bash
# ACF's `url` field validates on save and accepts an absolute URL only. A hash-only link
# (`#contact`) or a site path stored in one is refused by the editor, so wp-acf must send
# those links to a `text` field and say so where the field type is chosen.
set -euo pipefail
cd "$(dirname "$0")/../.."

fail() { echo "FAIL: $*"; exit 1; }

f=agents/wp-acf.md
[ -f "$f" ] || fail "$f missing"
t=$(tr '\n' ' ' < "$f" | sed -e 's/  */ /g')

# Requirement: the agent names the anchor-only case and routes it to a text field.
grep -Eq "anchor \(\`#[a-zA-Z0-9_-]+\`\).{0,120}\`text\` field" <<<"$t" \
  || fail "$f has no rule sending anchor-only links to a text field"
# Requirement: the field type table warns that a url field takes absolute URLs only.
grep -Eq '\| `url` \|[^|]*\|[^|]*(Absolute|absolute)[^|]*`text`' <<<"$t" \
  || fail "the field type table does not warn that url takes absolute URLs only"
# Requirement: the seed example stores an anchor in a text field, not a url field.
grep -Fq "update_field('hero_cta_anchor', '#contact'" "$f" \
  || fail "the seed example does not show an anchor stored in a text field"
echo PASS
