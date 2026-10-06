#!/usr/bin/env bash
# wp-bilingual described helpers the starters do not ship. Its reference was a hand-kept copy
# of the tailwind starter's inc/i18n.php that had drifted: it defined prefix__() where the
# starter ships prefix_t(), plus prefix_is_spanish() and prefix_get_js_translations(), which
# exist nowhere — a template written from it calls an undefined function and fatals. It never
# mentioned that the cinematic starter ships a different, three-helper contract with no
# prefix_get_field() at all. Its <html lang> recipe emitted two lang attributes, of which the
# browser keeps the first (the site locale), its cookie rule named the wrong cause, and its
# Spanish samples were missing their accents.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

s=skills/wp-bilingual/SKILL.md
tw=starter-theme/__tailwind__/inc/i18n.php
ci=starter-theme/__cinematic__/inc/i18n.php
harness=tests/checks/lib/suffix-i18n-behavior.php
for f in "$s" "$tw" "$ci" "$harness"; do [ -f "$f" ] || fail "$f is missing"; done
skill_md=$(find skills/wp-bilingual -name '*.md' | sort)
flat=$(tr '\n' ' ' < "$s" | sed 's/  */ /g')

# --- the helper names are the starters' names, in both directions --------------
# Every helper a starter defines is named in the skill under the prefix_ placeholder...
for pair in "$tw:tailwind" "$ci:cinematic"; do
  file=${pair%%:*}
  fns=$(grep -oP '^function __starter___\K[A-Za-z_0-9]+' "$file")
  [ -n "$fns" ] || fail "no helpers found in $file -- this check would be vacuous"
  for fn in $fns; do
    grep -qF "prefix_$fn(" "$s" || fail "$s does not name prefix_$fn(), which the ${pair##*:} starter defines"
  done
done
# ...and the names that drifted are gone from every file of the skill.
for gone in 'prefix__(' 'prefix_is_spanish' 'prefix_get_js_translations'; do
  hit=$(grep -lF -- "$gone" $skill_md || true)
  [ -z "$hit" ] || fail "$hit still names $gone, which no starter defines"
done

# --- which contract applies is read from the recorded template ------------------
grep -qF 'Read `Template:`' "$s" \
  || fail "$s does not tell the reader to pick the helper contract from the recorded Template: line"
grep -qF 'there is no `prefix_get_field()`' "$s" \
  || fail "$s does not warn that the cinematic starter has no prefix_get_field()"

# --- <html lang>: one attribute, set by a filter the starters ship --------------
grep -qF 'language_attributes(); ?> lang=' $skill_md \
  && fail "the skill still appends a second lang attribute after language_attributes() — the browser keeps the first, the site locale"
grep -qF "add_filter('language_attributes'" "$s" \
  || fail "$s does not show the language_attributes filter that makes <html lang> follow the request"
for h in starter-theme/__tailwind__/header.php starter-theme/__cinematic__/header.php; do
  grep -qF '<html <?php language_attributes(); ?>>' "$h" \
    || fail "$h no longer prints language_attributes() alone on <html>, so the starters' filter has nothing to act on"
done

# --- the cookie: the first call sets it, so the first call must precede output ---
case "$flat" in *'That first call must happen **before any output**'*) ;; *)
  fail "$s does not state that the first prefix_get_current_lang() call must precede output" ;; esac
case "$flat" in *'Including `i18n.php` early does not achieve this'*) ;; *)
  fail "$s still implies that including i18n.php early is what sets the cookie in time" ;; esac

# --- the starters' behaviour, run rather than grepped ---------------------------
if ! command -v php >/dev/null 2>&1; then
  echo "SKIP: php not found — the greps above passed, the starter behaviour was not run"
else
  for which in tailwind cinematic; do
    out=$(php -d pcre.jit=0 "$harness" "$which" 2>&1) \
      || { printf '%s\n' "$out" | sed 's/^/  /'; fail "the $which starter's inc/i18n.php does not set <html lang> or the cookie as the skill says"; }
  done
  # The cinematic starter read its cookie and never set it, so a ?lang= switch lasted one
  # request. It sets it on init now -- and only for a language that came from ?lang= and
  # is not already stored, so an ordinary page view sends no header.
  out=$(php tests/checks/lib/suffix-i18n-behavior.php cinematic stored-es 2>&1) \
    || { printf '%s\n' "$out" | sed 's/^/  /'; fail "the cinematic starter re-sends its language cookie on a request whose cookie already matches ?lang="; }
  out=$(php tests/checks/lib/suffix-i18n-behavior.php cinematic no-query 2>&1) \
    || { printf '%s\n' "$out" | sed 's/^/  /'; fail "the cinematic starter sets its language cookie from something other than ?lang="; }
fi
grep -nF -e 'never sets the cookie' -e 'sets no cookie' $skill_md \
  && fail "the skill still says the cinematic starter never sets its language cookie"
grep -qF "setcookie('__starter___lang'" "$ci" \
  || fail "$ci never calls setcookie() for the language it reads back from \$_COOKIE"

# --- Spanish samples carry their accents -----------------------------------------
for bad in "Saber Mas'" 'Enlaces Rapidos' 'Politica de Privacidad' 'Terminos y' 'Siguenos' "'Espanol'"; do
  hit=$(grep -lF -- "$bad" $skill_md || true)
  [ -z "$hit" ] || fail "$hit ships unaccented Spanish ('$bad')"
done

# --- the secondary-field instruction follows the primary language ---------------
grep -qF '"Leave empty to use English version" instruction' "$s" \
  && fail "$s's checklist still gives the English instruction as the rule for every secondary field"

echo PASS
