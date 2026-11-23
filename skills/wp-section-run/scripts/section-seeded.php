<?php
/**
 * How many fields of one section hold content on one page.
 *
 * Usage: wp eval-file section-seeded.php <page-id> <section_slug>
 * Prints a count, or -1 when there is nothing to ask: no ACF/SCF, or no field group
 * `group_<section_slug>` (the key /wp-section's field convention gives every section).
 *
 * The fields come from the section's own field group, not from a meta-key prefix: a prefix
 * also matches a section whose slug starts the same way (`hero` and `hero_alt`), and ACF
 * stores an empty repeater as "0". A field counts when get_field() returns something other
 * than null, false, '' or an empty array. PHP 7.4 floor.
 */

$page = isset( $args[0] ) ? (int) $args[0] : 0;
$slug = isset( $args[1] ) ? (string) $args[1] : '';
if ( $page <= 0 || ! preg_match( '/^[a-z0-9_]+$/', $slug ) ) {
	fwrite( STDERR, "usage: wp eval-file section-seeded.php <page-id> <section_slug>\n" );
	exit( 64 );
}
if ( ! function_exists( 'acf_get_fields' ) || ! function_exists( 'get_field' ) ) {
	echo "-1\n";
	return;
}
$fields = acf_get_fields( 'group_' . $slug );
if ( ! is_array( $fields ) || array() === $fields ) {
	echo "-1\n";
	return;
}
$filled = 0;
foreach ( $fields as $field ) {
	if ( empty( $field['name'] ) ) {
		continue;
	}
	$value = get_field( $field['name'], $page );
	if ( null === $value || false === $value || '' === $value || ( is_array( $value ) && array() === $value ) ) {
		continue;
	}
	$filled++;
}
echo $filled, "\n";
