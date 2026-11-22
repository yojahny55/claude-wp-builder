#!/usr/bin/env bash
# The cinematic switcher and the starters' front-end strings follow the page
# language under both i18n models: the switcher reads a per-model helper
# (Polylang answers from pll_the_languages, so links reach the translated
# page), and the tailwind chrome reads the starter's string table instead of
# gettext, which follows the site locale and has no .mo under Polylang.
set -euo pipefail
cd "$(dirname "$0")/../.."
# shellcheck source=../lib/assert.sh
. tests/lib/assert.sh

ST=starter-theme
for f in "$ST/__cinematic__/inc/i18n.php" "$ST/_i18n-variants/__cinematic__.php"; do
  grep >/dev/null -c 'function __starter___lang_switcher(): array' "$f" \
    || fail "$f: __starter___lang_switcher() missing"
done
grep >/dev/null -c 'pll_the_languages' "$ST/_i18n-variants/__cinematic__.php" \
  || fail "Polylang cinematic switcher does not read pll_the_languages()"
nav="$ST/__cinematic__/template-parts/cinematic/nav.php"
grep >/dev/null -c '__starter___lang_switcher()' "$nav" || fail "$nav does not use the switcher helper"
if grep -n "add_query_arg *( *'lang'" "$nav"; then
  fail "$nav still hard-codes ?lang= links"
fi

keys="skip_to_content main_menu error_404_title error_404_text error_404_categories error_404_archives footer_rights
  search_results_for post_nav_previous post_nav_next continue_reading page_links edit_post posted_on posted_by
  list_separator posted_in tagged leave_comment nothing_found first_post search_no_match nothing_here"
for f in "$ST/__tailwind__/inc/i18n.php" "$ST/_i18n-variants/__tailwind__.php"; do
  for k in $keys; do
    grep >/dev/null -c "'$k'" "$f" || fail "$f: string key '$k' missing"
  done
done
# Every front-end template of both starters. Only the nav-menu location labels
# (inc/theme-setup.php, functions.php) keep gettext: they show in wp-admin,
# which follows the user's locale, not the page language.
front=$(find "$ST/__tailwind__" "$ST/__cinematic__" -name '*.php' \
  -not -path '*/node_modules/*' -not -path '*/inc/*' -not -name functions.php | sort)
front="$front $ST/__tailwind__/inc/template-tags.php"
for p in $front; do
  if grep -nE "(^|[^A-Za-z0-9_])(esc_html_e|esc_attr_e|esc_html__|esc_attr__|esc_html_x|esc_attr_x|_e|__|_x|_n)\( *['\"]" "$p"; then
    fail "$p: front-end string still goes through gettext"
  fi
done
echo PASS
