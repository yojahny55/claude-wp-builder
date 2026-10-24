#!/usr/bin/env bash
# /wp-polylang: the import rewrites posts, menus and _menu_item_url in place and Step 3.5 moves
# every URL to /<lang>/..., yet the command said nothing about a backup, offered no dry run and
# called a bare `wp`, ignoring the .wp-create.json wrapper (Docker, custom paths). It must back
# up the database outside the docroot, preview the import, ask before hide_default=0, and use $WP.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
c=commands/wp-polylang.md
i=skills/wp-polylang/scripts/pll-import.php

grep -Fq '## Step 2.5' "$c" || fail "no backup step"
grep -Fq '$WP db export' "$c" || fail "backup step does not run \$WP db export"
grep -Fq 'outside the docroot' "$c" || fail "backup is not required to live outside the docroot"
b=$(grep -n '^## Step 2.5' "$c" | cut -d: -f1 || true); m=$(grep -n '^## Step 6' "$c" | cut -d: -f1 || true)
[ -n "$b" ] && [ -n "$m" ] && [ "$b" -lt "$m" ] || fail "backup must come before Step 6"
s3=$(grep -n '^## Step 3:' "$c" | cut -d: -f1 || true)
[ -n "$s3" ] && [ "$b" -lt "$s3" ] || fail "backup must come before configuring languages"
grep -Fq 'pll-import.php" "$MANIFEST.translated" dry-run' "$c" || fail "Step 6 has no dry-run invocation"
d=$(grep -n 'translated" dry-run' "$c" | head -1 | cut -d: -f1 || true)
r=$(grep -n 'pll-import.php" "$MANIFEST.translated"$' "$c" | head -1 | cut -d: -f1 || true)
[ "$d" -lt "$r" ] || fail "dry-run must come before the real import"
grep -Fq 'AskUserQuestion' "$c" && grep -Fq 'without a yes' "$c" || fail "hide_default=0 is not gated on confirmation"
grep -Fq "wp_cli.wrapper" "$c" || fail "command does not read the WP-CLI wrapper"
! grep -E '^ *wp (plugin|eval-file|eval|rewrite|db) ' "$c" || fail "bare wp call left in the command; use \$WP"

grep -Fq "'dry-run'" "$i" || fail "pll-import.php has no dry-run mode"
dr=$(grep -n "in_array( 'dry-run'" "$i" | head -1 | cut -d: -f1 || true)
w=$(grep -n '^\$written  ' "$i" | head -1 | cut -d: -f1 || true)
[ -n "$dr" ] && [ -n "$w" ] && [ "$dr" -lt "$w" ] || fail "dry-run must return before the first write"
sed -n "${dr},${w}p" "$i" | grep -Eq 'wp_(insert|update|delete)_post|wp_(update_nav_menu_item|create_nav_menu|insert_term|update_term|delete_term|delete_nav_menu_item)|(update|add|delete)_(post|term)_meta|pll_save_(post|term)_translations|pll_set_(post|term)_language|set_post_thumbnail|create_media_translation|pllx_string_translate|pllx_acf_write' \
  && fail "the dry-run block itself writes" || true
sed -n "${dr},${w}p" "$i" | grep -Fq 'would-skip menu' && sed -n "${dr},${w}p" "$i" | grep -Fq 'empty translated value' || fail "dry-run does not mirror the write path's skips"
grep -Fq 'new translated menu' "$i" && grep -Fq 'existing translated menu rebuilt' "$i" || fail "dry-run does not distinguish an existing menu from a new one"
command -v php >/dev/null && { php -l "$i" >/dev/null || fail "pll-import.php does not parse"; }

echo PASS
