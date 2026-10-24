#!/usr/bin/env bash
# The starter's wpcf7_mail_components filter forced content_type=text/html on EVERY Contact
# Form 7 form on the site, not just the ones the wp-cf7 agent creates (those carry
# use_html => true). On a client's own plain-text form, [your-message] then reached the
# inbox unescaped and was parsed as HTML: injected links and remote images. The substituted
# settings values (%%contact_email%%, %%business_address%%, social URLs) were also pasted raw
# into an HTML body. And the agent spliced `$(pwd)` into a single-quoted PHP string, which a
# path containing a quote breaks.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

h=starter-theme/__tailwind__/inc/cf7-helpers.php
agent=agents/wp-cf7.md
[ -f "$h" ] && [ -f "$agent" ] || fail "files missing"

grep -Fq "get('use_html', false)" "$h" || fail "filter does not gate on the mail's use_html flag"
grep -Fq 'esc_html(' "$h" || fail "substituted text values are not escaped"
grep -Fq 'esc_url(' "$h" || fail "substituted URLs are not escaped"
! grep -Fq "file_get_contents('\$(pwd)" "$agent" || fail "agent still splices \$(pwd) into a PHP string"
grep -Fq 'eval-file cf7/create-form-en.php' "$agent" || fail "agent does not pass the path to eval-file"
grep -Fq '$args[0]' "$agent" || fail "agent never reads the eval-file argument"

if command -v php >/dev/null 2>&1; then
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  cat > "$tmp/t.php" <<'PHP'
<?php
define( 'ABSPATH', '/' );
class WPCF7 {}
$GLOBALS['hooks'] = array();
function add_action( $h, $cb ) { $GLOBALS['hooks'][ $h ] = $cb; }
function add_filter( $h, $cb ) { $GLOBALS['hooks'][ $h ] = $cb; }
function get_theme_mod() { return 0; }
function st_get_field() { return ''; }
function get_field( $k ) {
	return array(
		'contact_email'    => 'a&b@example.test',
		'business_address' => '<img src=x onerror=1>Street 1',
		'social_facebook'  => 'https://fb.test/x"><script>',
	)[ $k ] ?? '';
}
function home_url() { return 'https://example.test'; }
function get_option() { return 'admin@example.test'; }
function esc_html( $s ) { return htmlspecialchars( $s, ENT_QUOTES ); }
function esc_url( $s ) { return str_replace( array( '"', '<', '>' ), '', $s ); }
function esc_url_raw( $s ) { return esc_url( $s ); }
function wp_strip_all_tags( $s ) { return strip_tags( $s ); }
class Form { function id() { return 1; } }
class Mail { function __construct( $h ) { $this->h = $h; } function get( $k, $r = true ) { return $this->h; } }
eval( '?>' . str_replace( '__starter__', 'st', file_get_contents( $argv[1] ) ) );
( $GLOBALS['hooks']['plugins_loaded'] )();
$cb = $GLOBALS['hooks']['wpcf7_mail_components'];
$in = array( 'body' => '[your-message] %%contact_email%% %%business_address%% %%social_facebook%%', 'subject' => 'S %%contact_email%%' );

$plain = $cb( $in, new Form, new Mail( false ) );
if ( $plain !== $in ) { fwrite( STDERR, "plain-text form was touched\n" ); exit( 1 ); }

$out = $cb( $in, new Form, new Mail( true ) );
if ( ( $out['content_type'] ?? '' ) !== 'text/html' ) { fwrite( STDERR, "html form lost its content type\n" ); exit( 1 ); }
if ( strpos( $out['body'], '<img' ) !== false || strpos( $out['body'], '<script' ) !== false ) { fwrite( STDERR, "unescaped value in body: {$out['body']}\n" ); exit( 1 ); }
if ( strpos( $out['body'], 'a&amp;b@example.test' ) === false ) { fwrite( STDERR, "email not escaped as text\n" ); exit( 1 ); }
if ( strpos( $out['subject'], 'a&b@example.test' ) === false ) { fwrite( STDERR, "subject was HTML-escaped\n" ); exit( 1 ); }
PHP
  php "$tmp/t.php" "$h" || fail "filter behavior"
else
  echo "SKIP: php not available, filter behavior not run"
fi
echo PASS
