#!/usr/bin/env bash
# Polylang routing defects found on a finished 16-page bilingual delivery. Each
# one returned HTTP 200 while serving the wrong language, the wrong template or
# nothing at all — so every check here is about asserting from a REQUEST rather
# than from the database, which is the thing they all have in common.
set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }

p=commands/wp-polylang.md
s=commands/wp-seed.md
v=starter-theme/_i18n-variants/__tailwind__.php
for x in "$p" "$s" "$v"; do test -f "$x" || fail "$x missing"; done

# B3 — an unprefixed default language serves English at /es/.
grep -q 'hide_default' "$p" || fail "wp-polylang never sets hide_default"
grep -q 'every English URL moves' "$p" || fail "the hide_default URL cost is not stated"

# B4 — the cached per-language home_url, which rewrite flush does not touch.
grep -q 'clean_languages_cache' "$p" || fail "wp-polylang never clears the language cache"
grep -q '`wp rewrite flush` does not clear it' "$p" || fail "wp-polylang does not say rewrite flush is not the fix"

# B5 — an imported string outranks the theme's table forever.
grep -q 'the theme.s PHP table stops deciding what it says' "$p" \
  || fail "wp-polylang does not warn that imported strings win over the PHP table"

# A1 — the menus, asserted from the front end because WP-CLI conceals this one.
grep -q 'Verify the menus from the front end' "$s" || fail "wp-seed does not verify menus by request"
grep -q 'under WP-CLI. So the CLI prints' "$s" || fail "wp-seed does not record that CLI conceals the menu map"

# B1/B2 — both live in the shipped Polylang helper, not in a project's head.
grep -q '__starter___resolve_post_id' "$v" || fail "the front/posts page language hop is missing"
grep -q "page_for_posts" "$v" || fail "the posts page is not resolved per language"
grep -q "template_include" "$v" || fail "a translated page still has no route to its template"
grep -q 'resolves a page request by slug BEFORE any language filter' "$v" \
  || fail "the shared-slug trap is not recorded where someone would try it"

php -l "$v" >/dev/null || fail "$v does not parse"

echo PASS
