#!/usr/bin/env bash
# /wp-maintenance closes a site to visitors and keeps it open to editors. The command is
# prose; the behavior is templates/maintenance/maintenance.php, which this check runs against
# stubbed WordPress: a visitor with maintenance on must get a 503 with Retry-After, an editor
# or a site with the option absent must get nothing, and anonymous REST must be refused.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

cmd=commands/wp-maintenance.md
tpl=templates/maintenance/maintenance.php
[ -f "$cmd" ] || fail "$cmd is missing"
[ -f "$tpl" ] || fail "$tpl is missing"

need_token "$cmd" 'templates/maintenance/maintenance.php'
need_token "$cmd" 'do not retype or "improve" it'
need_token "$cmd" 'Different without `--force`: stop and show the diff'
need_token "$cmd" 'never load it twice'
need_token "$cmd" '$WP option delete <prefix>_maintenance'
need_token "$cmd" '**On a store, use WooCommerce'"'"'s own coming-soon mode and skip Step 4.**'
need_token "$cmd" 'woocommerce_store_pages_only no'
need_token "$cmd" 'the status line must be `503` and `Retry-After` must be present'
need_token "$cmd" 'wp-config.mjs" validate'
need_token "$tpl" "defined( 'ABSPATH' ) || exit;"
need_token README.md '/wp-maintenance'
need_token docs/commands.md '(#wp-maintenance)'
need_token BACKLOG.md 'tests/checks/wp-maintenance.sh'

require_tool php

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sed -e 's/__prefix__/fx/g' -e 's/__textdomain__/fx-theme/g' "$tpl" > "$tmp/maintenance.php"
if grep -q '__prefix__\|__textdomain__' "$tmp/maintenance.php"; then fail "$tpl has a token the command does not substitute"; fi

cat > "$tmp/run.php" <<'PHP'
<?php
// argv: option value ("-" = absent), can edit_posts (0|1), entry (front|rest)
define( 'ABSPATH', __DIR__ . '/' );
define( 'DAY_IN_SECONDS', 86400 );
$GLOBALS['opt']  = $argv[1] === '-' ? false : $argv[1];
$GLOBALS['can']  = $argv[2] === '1';
$GLOBALS['hooks'] = array();
$GLOBALS['status'] = 200;
$GLOBALS['headers'] = array();
class WP_Error { public $data; function __construct( $c, $m, $d ) { $this->data = $d; } }
function add_action( $h, $f ) { $GLOBALS['hooks'][ $h ] = $f; }
function add_filter( $h, $f ) { $GLOBALS['hooks'][ $h ] = $f; }
function apply_filters( $h, $v ) { return $v; }
function get_option( $k, $d = false ) { return $k === 'fx_maintenance' ? $GLOBALS['opt'] : $d; }
function absint( $v ) { return abs( (int) $v ); }
function current_user_can( $c ) { return $c === 'edit_posts' && $GLOBALS['can']; }
function status_header( $s ) { $GLOBALS['status'] = $s; }
function nocache_headers() {}
function __( $s, $d ) { return $s; }
function esc_html_e( $s, $d ) { echo $s; }
function esc_html( $s ) { return $s; }
function language_attributes() {}
function bloginfo( $k ) {}
function get_bloginfo( $k ) { return 'Site'; }
function body_class( $c ) {}
function has_custom_logo() { return false; }
// header() and exit cannot be stubbed: rename the one header call and turn the exit into
// a throw, and refuse to run if either rewrite found nothing to rewrite.
$src = file_get_contents( __DIR__ . '/maintenance.php' );
$src = str_replace( 'header( \'Retry-After', 'fx_header( \'Retry-After', $src );
$src = str_replace( "    exit;\n}, 1 );", "    throw new Exception( 'exit' );\n}, 1 );", $src );
if ( substr_count( $src, 'fx_header(' ) !== 1 || strpos( $src, "throw new Exception( 'exit' )" ) === false ) {
    echo 'REWRITE-FAILED'; exit;
}
function fx_header( $h ) { $GLOBALS['headers'][] = $h; }
file_put_contents( __DIR__ . '/loaded.php', $src );
require __DIR__ . '/loaded.php';
if ( $argv[3] === 'rest' || $argv[3] === 'rest-prior' ) {
    // rest-prior: another authenticator already decided; its answer must pass through.
    $r = $GLOBALS['hooks']['rest_authentication_errors']( $argv[3] === 'rest-prior' ? true : null );
    if ( true === $r ) { echo 'rest:prior'; exit; }
    echo $r instanceof WP_Error ? 'rest:' . $r->data['status'] : 'rest:open';
    exit;
}
ob_start();
try { $GLOBALS['hooks']['template_redirect'](); } catch ( Exception $e ) {}
$body = ob_get_clean();
echo $GLOBALS['status'] . '|' . implode( ',', $GLOBALS['headers'] ) . '|' . ( strpos( $body, 'We will be back soon' ) !== false ? 'page' : 'none' );
PHP

run() { php "$tmp/run.php" "$@"; }
expect() { got=$(run "$1" "$2" "$3"); [ "$got" = "$4" ] || fail "option=$1 editor=$2 $3: expected '$4', got '$got'"; }

php -l "$tmp/maintenance.php" >/dev/null || fail "$tpl does not parse"
expect -     0 front '200||none'
expect 600   0 front '503|Retry-After: 600|page'
expect 600   1 front '200||none'
expect 5     0 front '503|Retry-After: 3600|page'      # under 60 s falls back to an hour, never to off
expect junk  0 front '503|Retry-After: 3600|page'
expect 99999999 0 front '503|Retry-After: 604800|page'  # clamped to 7 days
expect 600   0 rest  'rest:503'
expect 600   1 rest  'rest:open'
expect -     0 rest  'rest:open'
expect 600   0 rest-prior 'rest:prior'
echo "PASS: wp-maintenance template closes the site to visitors only, command contract intact"
