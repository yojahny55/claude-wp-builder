<?php
/**
 * Print the menu location a starter's i18n layer answers for one base name.
 *
 * Usage: php nav-location.php <i18n.php or _i18n-variants file> <lang> <base>
 *
 * Loads the file with WordPress stubbed out (Polylang absent), sets ?lang=<lang>,
 * and echoes __starter___nav_location(<base>). Used by tests/checks/menu-locations.sh
 * to compare what templates will ask for against what the starters and the
 * commands register.
 */

define( 'ABSPATH', __DIR__ );

function add_filter( $hook, $cb, $prio = 10, $args = 1 ) { return true; }
function add_action( $hook, $cb, $prio = 10, $args = 1 ) { return true; }
function sanitize_text_field( $s ) { return trim( strip_tags( (string) $s ) ); }
function sanitize_key( $s ) { return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $s ) ); }
function wp_unslash( $s ) { return $s; }
function esc_attr( $s ) { return htmlspecialchars( (string) $s, ENT_QUOTES ); }
function wp_kses( $s, $allowed ) { return $s; }
function get_field( $name, $id = false ) { return ''; }
function is_ssl() { return false; }

if ( count( $argv ) !== 4 ) {
	fwrite( STDERR, "usage: php nav-location.php <file> <lang> <base>\n" );
	exit( 2 );
}

$_GET['lang'] = $argv[2];
require $argv[1];

if ( ! function_exists( '__starter___nav_location' ) ) {
	fwrite( STDERR, "{$argv[1]} defines no __starter___nav_location()\n" );
	exit( 1 );
}
echo __starter___nav_location( $argv[3] );
