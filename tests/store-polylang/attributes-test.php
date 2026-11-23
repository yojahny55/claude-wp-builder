<?php
PHP_SAPI === 'cli' || exit; // Tests run from the CLI only, never from the web server.
require_once STORE_PLL_DIR . 'includes/core/attributes.php';

$GLOBALS['wpll']['is_admin'] = false;
store_pll_register_attributes();
wpll_same( array( 'priority' => 20, 'args' => 1 ), wpll_hook( 'init', 'store_pll_register_attribute_strings' ), 'registered on init 20' );
wpll_same( array( 'priority' => 10, 'args' => 2 ), wpll_hook( 'get_term', 'store_pll_translate_attribute_term' ), 'front: get_term 10/2' );
wpll_same( array( 'priority' => 10, 'args' => 1 ), wpll_hook( 'woocommerce_attribute_label', 'store_pll_t' ), 'front: label' );

$GLOBALS['wpll']['hooks']    = array();
$GLOBALS['wpll']['is_admin'] = true;
store_pll_register_attributes();
wpll_same( null, wpll_hook( 'get_term', 'store_pll_translate_attribute_term' ), 'admin without AJAX: no term translation' );
wpll_same( array( 'priority' => 20, 'args' => 1 ), wpll_hook( 'init', 'store_pll_register_attribute_strings' ), 'admin: registration still happens' );
