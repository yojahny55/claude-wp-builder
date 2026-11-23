<?php
PHP_SAPI === 'cli' || exit; // Tests run from the CLI only, never from the web server.
require_once STORE_PLL_DIR . 'includes/boot.php';

define( 'PLL_WC_BRIDGE', 'Some Other Bridge' );
wpll_same( 'Some Other Bridge', store_pll_other_bridge(), 'PLL_WC_BRIDGE set by another plugin is reported' );
