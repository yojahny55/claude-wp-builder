#!/usr/bin/env bash
# Under Polylang a CPT archive's breadcrumb crumb stayed in the primary language on
# /en/<cpt-plural>/ and every single under it: Rank Math builds that crumb from the
# register_post_type() label, which no post_type_archive_title filter reaches. The fix is
# a rank_math/frontend/breadcrumb/items filter routing the crumb through the string table.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

rm=skills/wp-audit-seo-standards/references/rankmath-polylang.md
agent=agents/wp-audit-rankmath.md
pll=skills/wp-polylang/SKILL.md

# The agent keeps no code for Step 15: it must send the reader to the reference.
grep -Fq 'references/rankmath-polylang.md' "$agent" \
  || fail "$agent Step 15 does not point at $rm"
grep -Fq "add_filter( 'rank_math/frontend/breadcrumb/items'" "$rm" \
  || fail "$rm has no breadcrumb/items filter for CPT-archive crumbs"
grep -Fq "'plural_' . \$type" "$rm" \
  || fail "$rm's breadcrumb filter does not read the plural_<post_type> string"
grep -Fq 'rank_math/frontend/breadcrumb/items' "$pll" \
  || fail "$pll does not point Polylang builds at the breadcrumb filter"
# prefix_t() returns the key itself when missing; `prefix_t( $key ) ?: $title` never falls back.
grep -Fq 'prefix_t( $key ) ?: $title' "$pll" \
  && fail "$pll still falls back with ?: on prefix_t(), which returns the key, never ''"

# The moved script's output only means something if the agent says how to read it.
grep -Fq 'each `WARN:` is a finding' agents/wp-audit-rankmath.md \
  || fail "agents/wp-audit-rankmath.md Step 15 no longer says how to treat the Polylang script's WARN/INFO/SKIP lines"

echo PASS
