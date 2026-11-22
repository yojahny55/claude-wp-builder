#!/usr/bin/env bash
# The suffix-model language resolver of both starters (Tailwind and cinematic inc/i18n.php),
# executed with stubbed WordPress functions rather than grepped. Pins:
#   - Accept-Language honours q-values: `fr,es;q=0.9` is Spanish. Reading the first two
#     characters named French, which is unsupported, and fell through to English.
#   - An unsupported ?lang falls through to the cookie in BOTH starters; the cinematic one
#     used to reset it to English.
#   - Page caches: every front response sends `Vary: Accept-Language, Cookie`, and one
#     that is not the default language or carries ?lang defines DONOTCACHEPAGE and sends
#     no-cache headers. A default-language page without ?lang stays cacheable.
#   - <html lang> is rewritten on the front end only, never in wp-admin or on the login
#     screen.
# Each case runs in its own PHP process: the resolver caches its answer in a static.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh
require_tool php
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/run.php" <<'PHP'
<?php
// argv: file, resolver, get-lang, cookie, accept, mode(front|admin|login)
[$_, $file, $resolver, $get, $cookie, $accept, $mode] = $argv;
define('ABSPATH', '/');
$GLOBALS['hooks'] = [];
$GLOBALS['nocache'] = false;
$GLOBALS['vary'] = false;
function add_action($h, $cb) { $GLOBALS['hooks'][$h][] = $cb; }
function add_filter($h, $cb) { $GLOBALS['hooks'][$h][] = $cb; }
function do_hook($h, ...$args) { foreach ($GLOBALS['hooks'][$h] ?? [] as $cb) { $r = $cb(...$args); if ($args) { $args[0] = $r; } } return $args[0] ?? null; }
function sanitize_key($k) { return preg_replace('/[^a-z0-9_\-]/', '', strtolower($k)); }
function sanitize_text_field($s) { return trim((string) $s); }
function wp_unslash($s) { return $s; }
function esc_attr($s) { return $s; }
function is_ssl() { return false; }
function is_admin() { return $GLOBALS['mode'] === 'admin'; }
function did_action($h) { return $h === 'login_init' && $GLOBALS['mode'] === 'login' ? 1 : 0; }
function nocache_headers() { $GLOBALS['nocache'] = true; }
$GLOBALS['mode'] = $mode;
if ($get !== '-') { $_GET['lang'] = $get; }
if ($cookie !== '-') { $_COOKIE['__starter___lang'] = $cookie; }
if ($accept !== '-') { $_SERVER['HTTP_ACCEPT_LANGUAGE'] = $accept; }
require $file;
ob_start();
do_hook('send_headers');
ob_end_clean();
$lang = $resolver();
$attr = do_hook('language_attributes', 'lang="en-US"');
$cache = defined('DONOTCACHEPAGE') ? 'nocache-page' : 'cacheable';
echo $lang, ' ', $attr, ' ', $cache, ' ', $GLOBALS['nocache'] ? 'no-cache-headers' : 'cache-headers', "\n";
PHP

case_() { # <starter> <get> <cookie> <accept> <mode> <expected>
  local file resolver got
  case "$1" in
    tailwind)  file=starter-theme/__tailwind__/inc/i18n.php;  resolver=__starter___get_current_lang ;;
    cinematic) file=starter-theme/__cinematic__/inc/i18n.php; resolver=__starter___current_lang ;;
  esac
  got=$(php -d display_errors=stderr -d error_reporting=E_ALL "$tmp/run.php" "$PWD/$file" "$resolver" "$2" "$3" "$4" "$5" 2>"$tmp/err") \
    || fail "$1 ($2|$3|$4|$5) crashed: $(cat "$tmp/err")"
  [ ! -s "$tmp/err" ] || fail "$1 ($2|$3|$4|$5) emitted PHP diagnostics: $(cat "$tmp/err")"
  [ "$got" = "$6" ] || fail "$1 ?lang=$2 cookie=$3 accept='$4' $5: expected '$6', got '$got'"
}

for s in tailwind cinematic; do
  # q-values decide, not the first two characters.
  case_ $s - - 'fr,es;q=0.9'            front 'es lang="es" nocache-page no-cache-headers'
  case_ $s - - 'es;q=0.2, en;q=0.8'     front 'en lang="en" cacheable cache-headers'
  case_ $s - - 'es-MX,en;q=0.5'         front 'es lang="es" nocache-page no-cache-headers'
  case_ $s - - 'es;q=0, fr'             front 'en lang="en" cacheable cache-headers'
  case_ $s - - 'de'                     front 'en lang="en" cacheable cache-headers'
  # URL beats cookie; an unsupported ?lang falls through to the cookie.
  case_ $s es en -                      front 'es lang="es" nocache-page no-cache-headers'
  case_ $s fr es -                      front 'es lang="es" nocache-page no-cache-headers'
  case_ $s en - -                       front 'en lang="en" nocache-page no-cache-headers'
  case_ $s - - -                        front 'en lang="en" cacheable cache-headers'
  # Admin and login keep the locale's lang attribute and get no cache meddling.
  case_ $s es - -                       admin 'es lang="en-US" cacheable cache-headers'
  case_ $s es - -                       login 'es lang="en-US" nocache-page no-cache-headers'
done

# Vary is sent on the front end (header() is a no-op on the CLI, so read the source).
for f in starter-theme/__tailwind__/inc/i18n.php starter-theme/__cinematic__/inc/i18n.php; do
  need_token "$f" "header('Vary: Accept-Language, Cookie', false);" "$f does not send Vary on language-dependent responses"
done
echo PASS
