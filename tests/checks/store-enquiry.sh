#!/usr/bin/env bash
# A catalog store records enquiry channels, and until now nothing rendered the WhatsApp button
# or the enquiry form. /wp-woo-setup Step 6.5 installs templates/store/store-enquiry.php into
# the theme. This runs the template against stubbed WordPress and WooCommerce: nothing renders
# outside catalog mode or with the fields empty; a number renders a wa.me link with the product
# in the message; a short or malformed number renders nothing; the form renders only for a real
# Contact Form 7 form; and the command never fills a number.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

cmd=commands/wp-woo-setup.md
tpl=templates/store/store-enquiry.php
[ -f "$tpl" ] || fail "$tpl is missing"
need_token "$cmd" '## Step 6.5: Enquiry channels in the theme'
need_token "$cmd" 'templates/store/store-enquiry.php'
need_token "$cmd" 'do not retype or "improve" it'
need_token "$cmd" '**Never fill the number or'
need_token "$cmd" 'never load it twice'
need_token "$cmd" 'cp "$tmp" "$dest" && echo INSTALLED'
need_token "$cmd" 'The installed file is always the substituted copy'
need_token "$tpl" "defined( 'ABSPATH' ) || exit;"
need_token "$tpl" "store_kit_catalog_mode()"
need_token "$tpl" "'__textdomain__-settings'"
need_token starter-theme/__tailwind__/functions.php "'menu_slug'  => '__starter__-settings'"
need_token BACKLOG.md 'tests/checks/store-enquiry.sh'
need_token BACKLOG.md 'tests/checks/store-enquiry-integration.sh'
need_token .github/workflows/ci.yml 'bash tests/checks/store-enquiry-integration.sh'
if grep -nE 'update_field\( *.store_whatsapp_number|option update [a-z_]*store_whatsapp' "$cmd" "$tpl" >/dev/null; then
  fail "a WhatsApp number is written by the plugin; only the client fills it"
fi

require_tool php
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sed -e 's/__prefix__/fx/g' -e 's/__textdomain__/fx-theme/g' "$tpl" > "$tmp/store-enquiry.php"
if grep -q '__prefix__\|__textdomain__' "$tmp/store-enquiry.php"; then fail "$tpl has a token the command does not substitute"; fi
php -l "$tmp/store-enquiry.php" >/dev/null || fail "$tpl does not parse"

cat > "$tmp/run.php" <<'PHP'
<?php
// argv: catalog (0|1), number, message, form id, form post type, [variant: noacf|post]
define( 'ABSPATH', __DIR__ . '/' );
list( , $catalog, $number, $message, $form, $ftype ) = $argv;
$GLOBALS['opt']   = array( 'store_whatsapp_number' => $number === '-' ? '' : $number, 'store_whatsapp_message' => $message === '-' ? '' : $message, 'store_enquiry_form' => $form === '-' ? '' : $form );
$GLOBALS['hooks'] = array();
$GLOBALS['group'] = null;
$GLOBALS['via']   = '';
function add_action( $h, $f, $p = 10 ) { $GLOBALS['hooks'][ $h ] = $f; }
function __( $s, $d ) { return $s; }
function esc_html__( $s, $d ) { return htmlspecialchars( $s ); }
function esc_url( $u ) { return htmlspecialchars( $u, ENT_QUOTES ); }
function absint( $v ) { return abs( (int) $v ); }
function store_kit_catalog_mode() { return '1' === $GLOBALS['argv'][1]; }
$variant = isset( $argv[6] ) ? $argv[6] : '';
if ( 'noacf' !== $variant ) {
	function get_field( $n, $where ) { return $GLOBALS['opt'][ $n ]; }
}
// The theme's helper calls get_field() unguarded, as the starter's does.
function fx_get_field( $n, $where ) { $GLOBALS['via'] = 'helper'; return get_field( $n, $where ); }
function acf_add_local_field_group( $g ) { $GLOBALS['group'] = $g; }
function get_permalink( $id ) { return 'https://shop.test/p/' . $id; }
function shortcode_exists( $s ) { return 'contact-form-7' === $s; }
function get_post_type( $id ) { return $GLOBALS['argv'][5]; }
function do_shortcode( $s ) { return '[FORM:' . $s . ']'; }
class WC_Product {}
class FxProduct extends WC_Product { function get_name() { return 'Chair <b>"Oak"</b>'; } function get_id() { return 7; } }
require __DIR__ . '/store-enquiry.php';
$GLOBALS['hooks']['acf/init']();
$loc = $GLOBALS['group']['location'][0][0]['value'];
ob_start();
$GLOBALS['product'] = 'post' === $variant ? new stdClass() : new FxProduct();
$GLOBALS['hooks']['woocommerce_single_product_summary']();
$html = ob_get_clean();
echo $loc . '|' . $GLOBALS['via'] . '|' . $html;
PHP

run() { php "$tmp/run.php" "$@"; }
expect_has()  { got=$(run "$@" | cut -d'|' -f3-); printf '%s' "$got" | grep -F -- "$EXPECT" >/dev/null || fail "case [$*]: expected '$EXPECT' in: $got"; }
expect_none() { got=$(run "$@" 2>&1 | cut -d'|' -f3- || true); [ -z "$got" ] || fail "case [$*]: expected nothing, got: $got"; }

[ "$(run 1 - - - x | cut -d'|' -f1)" = fx-theme-settings ] || fail "the field group is not on the theme's settings page (<theme slug>-settings)"
expect_none 0 '+1 813 555 0100' - 12 wpcf7_contact_form    # a store that sells: nothing
expect_none 1 - - - x                                     # catalog, nothing filled: nothing
expect_none 1 '123' - - x                                 # too short to be a number
expect_none 1 '1234567890123456' - - x                    # too long (E.164 is 15 digits at most)
expect_none 1 '+1 813 555 0100 ext 22' - - x              # an extension would be glued onto the number
expect_none 1 '555 0100 / 555 0199' - - x                 # two numbers are not one
expect_none 1 '+18135550100' - - x post                   # a builder hands a non-product: nothing, no fatal
expect_none 1 '+18135550100' - 12 wpcf7_contact_form noacf  # ACF/SCF off: nothing, no fatal
EXPECT='https://wa.me/18135550100?text=Hello%2C%20I%20would%20like%20to%20know%20more%20about%20Chair%20%3Cb%3E%22Oak%22%3C%2Fb%3E%20https%3A%2F%2Fshop.test%2Fp%2F7'
expect_has 1 '+1 (813) 555-0100' - - x
EXPECT='text=Call%20me%20Chair'
expect_has 1 '+18135550100' 'Call me' - x                 # no {product}: appended
EXPECT='[FORM:[contact-form-7 id="12"]]'
expect_has 1 - - 12 wpcf7_contact_form
expect_none 1 - - 12 page                                 # an ID that is not a CF7 form
[ "$(run 1 '+18135550100' - - x | cut -d'|' -f2)" = helper ] || fail "the settings are not read through the theme's prefix_get_field"
if run 1 '+18135550100' - - x | grep -F '<b>' >/dev/null; then fail "the product name reaches the markup unescaped"; fi
echo "PASS: store-enquiry renders filled channels on catalog product pages only, and never invents a number"
