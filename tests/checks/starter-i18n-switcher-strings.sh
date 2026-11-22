#!/usr/bin/env bash
# The cinematic switcher and the tailwind chrome strings follow the page
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

keys="skip_to_content main_menu error_404_title error_404_text error_404_categories error_404_archives footer_rights"
for f in "$ST/__tailwind__/inc/i18n.php" "$ST/_i18n-variants/__tailwind__.php"; do
  for k in $keys; do
    grep >/dev/null -c "'$k'" "$f" || fail "$f: string key '$k' missing"
  done
done
for f in header.php 404.php template-parts/header/navigation.php template-parts/footer/site-info.php; do
  p="$ST/__tailwind__/$f"
  if grep -nE "(esc_html_e|esc_attr_e|esc_html__)\(" "$p"; then
    fail "$p: chrome string still goes through gettext"
  fi
done
echo PASS
