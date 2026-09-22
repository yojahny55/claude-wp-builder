#!/usr/bin/env bash
# Under Polylang a CPT archive's breadcrumb crumb stayed in the primary language on
# /en/<cpt-plural>/ and every single under it: Rank Math builds that crumb from the
# register_post_type() label, which no post_type_archive_title filter reaches. The fix is
# a rank_math/frontend/breadcrumb/items filter routing the crumb through the string table.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

rm=agents/wp-audit-rankmath.md
pll=skills/wp-polylang/SKILL.md

grep -Fq "add_filter( 'rank_math/frontend/breadcrumb/items'" "$rm" \
  || fail "$rm has no breadcrumb/items filter for CPT-archive crumbs"
grep -Fq "'plural_' . \$type" "$rm" \
  || fail "$rm's breadcrumb filter does not read the plural_<post_type> string"
grep -Fq 'rank_math/frontend/breadcrumb/items' "$pll" \
  || fail "$pll does not point Polylang builds at the breadcrumb filter"
# prefix_t() returns the key itself when missing; `prefix_t( $key ) ?: $title` never falls back.
grep -Fq 'prefix_t( $key ) ?: $title' "$pll" \
  && fail "$pll still falls back with ?: on prefix_t(), which returns the key, never ''"

echo PASS
