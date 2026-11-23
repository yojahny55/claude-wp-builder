<?php
PHP_SAPI === 'cli' || exit; // Tests run from the CLI only, never from the web server.
function pll_current_language() {
	return $GLOBALS['wpll']['curlang'];
}
require_once STORE_PLL_DIR . 'includes/core/lang.php';

$GLOBALS['wpll']['curlang'] = 'es';
wpll_same( 'es', store_pll_lang(), 'when not forced, returns the request language' );
wpll_same( null, store_pll_lang( null, true ), 'when not forced, forced_only is null' );

store_pll_lang( 'en' );
wpll_same( 'en', store_pll_lang(), 'the forced language wins over the request one' );
wpll_same( 'en', store_pll_lang( null, true ), 'forced_only returns the forced language' );

store_pll_lang( false );
wpll_same( 'es', store_pll_lang(), 'false clears the forced language' );
wpll_same( null, store_pll_lang( null, true ), 'after clearing, forced_only is null' );

$GLOBALS['wpll']['curlang'] = false;
wpll_same( false, store_pll_lang(), 'without a request language returns false' );
