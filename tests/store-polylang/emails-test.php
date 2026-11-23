<?php
PHP_SAPI === 'cli' || exit; // Tests run from the CLI only, never from the web server.
class Wpll_Fake_Order {
	public $meta;
	public function __construct( array $meta ) {
		$this->meta = $meta;
	}
	public function get_meta( $key ) {
		return $this->meta[ $key ] ?? '';
	}
}
require_once STORE_PLL_DIR . 'includes/core/emails.php';
store_pll_register_emails();

$expected = array(
	'woocommerce_checkout_create_order'        => array( 'store_pll_record_order_lang', 10, 1 ),
	'woocommerce_store_api_checkout_update_order_from_request' => array( 'store_pll_record_order_lang', 10, 1 ),
	'woocommerce_allow_switching_email_locale' => array( 'store_pll_mark_email_pending', 10, 2 ),
	'woocommerce_email'                        => array( 'store_pll_add_email_recipient_filters', 10, 1 ),
	'woocommerce_allow_restoring_email_locale' => array( 'store_pll_restore_email_locale', 10, 2 ),
	'init'                                     => array( 'store_pll_register_email_footer_string', 10, 1 ),
	'woocommerce_email_footer_text'            => array( 'store_pll_translate_email_footer', 5, 1 ),
);
foreach ( $expected as $hook => $e ) {
	wpll_same( array( 'priority' => $e[1], 'args' => $e[2] ), wpll_hook( $hook, $e[0] ), "{$hook} {$e[1]}/{$e[2]}" );
}

// The block checkout posts to the Store API, where Polylang has no language: the cookie
// stands in, but only when it names one of the site's languages.
wpll_same( 'es', store_pll_checkout_lang( 'es', 'en', array( 'es', 'en' ) ), 'the request language wins over the cookie' );
wpll_same( 'en', store_pll_checkout_lang( false, 'en', array( 'es', 'en' ) ), 'no request language: the cookie' );
wpll_same( '', store_pll_checkout_lang( false, 'fr', array( 'es', 'en' ) ), 'a cookie naming no site language is ignored' );
wpll_same( '', store_pll_checkout_lang( false, '', array( 'es', 'en' ) ), 'neither: no language' );

wpll_same( '_store_pll_order_lang', store_pll_order_lang_meta_keys()[0], 'the own meta key is the one written' );
wpll_same( 'en', store_pll_order_lang( new Wpll_Fake_Order( array( '_store_pll_order_lang' => 'en', '_legacy_order_lang' => 'es' ) ) ), 'the own meta wins' );
wpll_same( '', store_pll_order_lang( new Wpll_Fake_Order( array( '_legacy_order_lang' => 'en' ) ) ), 'a foreign key is ignored by default' );
$GLOBALS['wpll']['filters']['store_pll_order_lang_meta_keys'] = function ( $keys ) {
	$keys[] = '_legacy_order_lang';
	return $keys;
};
wpll_same( 'en', store_pll_order_lang( new Wpll_Fake_Order( array( '_legacy_order_lang' => 'en' ) ) ), 'fallback: a key added through the filter is read when the own one is absent' );
wpll_same( 'es', store_pll_order_lang( new Wpll_Fake_Order( array( '_store_pll_order_lang' => 'es', '_legacy_order_lang' => 'en' ) ) ), 'the own meta still wins with the filter active' );
wpll_same( '', store_pll_order_lang( new Wpll_Fake_Order( array() ) ), 'no meta: empty string' );
wpll_same( '', store_pll_order_lang( null ), 'no order: empty string' );

$a = new stdClass();
$b = new stdClass();
store_pll_email_lang_state( $a, 'pending' );
wpll_same( 'pending', store_pll_email_lang_state( $a ), 'state per email' );
wpll_same( '', store_pll_email_lang_state( $b ), 'another email does not inherit the state' );
