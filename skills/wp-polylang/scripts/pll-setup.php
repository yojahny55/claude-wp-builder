<?php
/**
 * Verify Polylang is usable and create any missing language.
 *
 * Usage: wp eval-file pll-setup.php <source_lang> <target_lang>
 *
 * Installing the plugin itself is WP-CLI's job and stays in the command doc;
 * this script fails with that exact command line when the plugin is absent.
 */

require_once __DIR__ . '/pll-lib.php';

list( $source, $target ) = pllx_args( 2, 'pll-setup.php <source_lang> <target_lang>' );

pllx_require_polylang();

if ( $source === $target ) {
	pllx_fail( "Source and target language are both '$source'." );
}

/**
 * Preferred locales.
 *
 * Polylang's predefined list is searched by language code and returns its FIRST
 * match, which for 'en' is en_AU and for 'es' is es_AR — not what a site
 * usually wants. These defaults win when present.
 */
$preferred = array(
	'en' => 'en_US', 'es' => 'es_ES', 'fr' => 'fr_FR', 'de' => 'de_DE',
	'it' => 'it_IT', 'pt' => 'pt_PT', 'nl' => 'nl_NL', 'ca' => 'ca',
);

// pllx_add_language() and pllx_language_model() live in pll-lib.php, so the fixture in
// tests/fixtures/wp/ creates its languages through this same code rather than a copy.

$configured = (array) pll_languages_list();
foreach ( array( $source, $target ) as $code ) {
	if ( ! in_array( $code, $configured, true ) ) {
		pllx_info( "Language '$code' missing" );
		pllx_add_language( $code, $preferred );
	}
}

// Re-read: add_language() invalidates the cached list.
PLL()->model->clean_languages_cache();
$configured = (array) pll_languages_list();

foreach ( array( $source, $target ) as $code ) {
	if ( ! in_array( $code, $configured, true ) ) {
		pllx_fail( "Language '$code' still missing after creation." );
	}
}

pllx_info( "Polylang ready: source=$source target=$target" );
pllx_info( 'Configured languages: ' . implode( ', ', $configured ) );
pllx_info( 'Default language: ' . pll_default_language() );
