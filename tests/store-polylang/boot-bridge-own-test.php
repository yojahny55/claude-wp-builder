<?php
PHP_SAPI === 'cli' || exit; // Tests run from the CLI only, never from the web server.
require_once STORE_PLL_DIR . 'includes/boot.php';

define( 'PLL_WC_BRIDGE', 'store-polylang' );
$GLOBALS['wpll']['options']['active_plugins'] = array();
wpll_same( '', store_pll_other_bridge(), 'PLL_WC_BRIDGE set by this plugin is not another bridge' );
