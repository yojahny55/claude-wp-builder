<?php
/**
 * Language in use: the one forced while an email is being built, else the request's.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * @param string|false|null $set         Slug to force, false to clear, null to leave as is.
 * @param bool              $forced_only Return only the forced language (null if none).
 * @return string|false|null
 */
function store_pll_lang( $set = null, $forced_only = false ) {
	static $forced = null;
	if ( null !== $set ) {
		$forced = $set ? $set : null;
	}
	if ( $forced_only ) {
		return $forced;
	}
	if ( $forced ) {
		return $forced;
	}
	return function_exists( 'pll_current_language' ) ? pll_current_language() : false;
}
