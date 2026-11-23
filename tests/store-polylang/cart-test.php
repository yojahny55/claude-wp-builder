<?php
PHP_SAPI === 'cli' || exit; // Tests run from the CLI only, never from the web server.
function pll_current_language() {
	return $GLOBALS['wpll']['curlang'];
}
require_once STORE_PLL_DIR . 'includes/core/lang.php';
require_once STORE_PLL_DIR . 'includes/core/cart.php';

$GLOBALS['wpll']['curlang'] = 'en';
wpll_same( 'wc_fragments_abc_en', store_pll_cart_fragment_name( 'wc_fragments_abc' ), 'the fragments name carries the language' );

$GLOBALS['wpll']['curlang'] = false;
wpll_same( 'wc_fragments_abc', store_pll_cart_fragment_name( 'wc_fragments_abc' ), 'without a language the name is unchanged' );

wpll_same( null, store_pll_product_in_language( 'not a product', 'en' ), 'without a product there is no equivalent' );
