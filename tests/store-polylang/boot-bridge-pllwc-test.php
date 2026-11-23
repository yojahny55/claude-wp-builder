<?php
PHP_SAPI === 'cli' || exit; // Tests run from the CLI only, never from the web server.
require_once STORE_PLL_DIR . 'includes/boot.php';

define( 'PLLWC_VERSION', '1.0' );
wpll_same( 'Polylang for WooCommerce', store_pll_other_bridge(), 'PLLWC_VERSION: the paid Polylang for WooCommerce is reported' );
