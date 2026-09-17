#!/usr/bin/env bash
# wp-audit-rankmath shipped several SEO-data defects a real build's audit caught:
#
# - Theme identity JSON-LD (address/contactPoint/sameAs) sharing an @id with Rank
#   Math's own Organization node was printed as a second <script> instead of merged
#   through `rank_math/json_ld`. Two blocks sharing an @id merge per the JSON-LD spec,
#   but any validator that counts @type occurrences reads two Organizations.
# - The search-results page had no noindex step, so /?s=<term> and /search/<term>/
#   were both indexable for the same content.
# - Step 8 seeded rank_math_title/rank_math_description for posts and pages only —
#   taxonomy term archives got nothing.
# - The OG-image default could fall back to the theme screenshot, which has no
#   attachment ID, so Rank Math silently printed no og:image tag at all.
# - knowledgegraph_type accepts only the literal 'person'/'company'; anything else
#   (a plausible 'organization') silently degrades to 'person' — a company described
#   as a human in its own JSON-LD.
# - A sideloaded site icon could be silently converted to WebP by an unrelated global
#   image_editor_output_format filter, and iOS does not read a WebP touch icon.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

f=agents/wp-audit-rankmath.md
[ -f "$f" ] || fail "$f is missing"

# JSON-LD must be merged through Rank Math's own filter, never duplicated.
grep -qF "add_filter( 'rank_math/json_ld'" "$f" || fail "$f must merge theme identity data through rank_math/json_ld"
grep -qF 'array_merge( $extra, $entity )' "$f" || fail "$f json_ld merge must let Rank Math win on keys it already fills"
grep -qF 'FIX: if it shares an @id with' "$f" || fail "$f Step 8.5's duplicate-schema check must point to the merge filter, not blind removal"

# knowledgegraph_type must be read, not assumed, when resolving the merge target's @id.
grep -qF "knowledgegraph_type" "$f" || fail "$f must reference knowledgegraph_type"
grep -qF 'in_array(\$type,' "$f" || fail "$f must verify knowledgegraph_type is one of the two legal values"

# Search results: noindex via the frontend robots filter, no canonical fight.
grep -qF "add_filter( 'rank_math/frontend/robots'" "$f" || fail "$f must noindex search results via rank_math/frontend/robots"
grep -qF 'is_search()' "$f" || fail "$f search-noindex step must gate on is_search()"

# Term meta seeding, not just posts/pages.
grep -qF 'update_term_meta' "$f" || fail "$f Step 8 must also seed term meta (rank_math_title/description on taxonomy terms)"
grep -qF 'get_terms(' "$f" || fail "$f Step 8 must loop taxonomy terms, not only get_posts()"

# og:image must require a real attachment id; the theme-screenshot fallback CODE is gone
# (the escaped \$-form only appears inside a live $WP eval heredoc — the lesson can still
# be named in plain prose without a leading backslash).
! grep -qF '\$theme->get_screenshot()' "$f" || fail "$f Step 6 must not fall back to the theme screenshot for og:image"
grep -qF 'open_graph_image_id' "$f" || fail "$f must set open_graph_image_id"
grep -qF 'tag will not print' "$f" || fail "$f must warn when no attachment backs open_graph_image_id"

# Site icon: import forces the output format so an unrelated optimizer cannot rewrite it.
grep -qF "add_filter('image_editor_output_format', '__return_empty_array', 999)" "$f" \
  || fail "$f must force PNG output around the site-icon sideload"
grep -qF "site icon is PNG OK" "$f" || fail "$f must verify the imported site icon stayed a PNG"

echo PASS
