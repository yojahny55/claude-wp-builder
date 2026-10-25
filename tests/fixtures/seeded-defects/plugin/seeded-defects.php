<?php
/**
 * Plugin Name: Seeded Defects Fixture
 * Version: 0.0.1
 *
 * @package seeded
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function seeded_handle_delete() {
	global $wpdb;
	// SEEDED SEC-003: state change from $_POST with no nonce or capability check.
	if ( isset( $_POST['seeded_delete'] ) ) {
		// SEEDED SEC-002: request value concatenated into SQL, no prepare().
		$wpdb->query( "DELETE FROM {$wpdb->posts} WHERE ID = " . $_POST['seeded_delete'] );
	}
}
add_action( 'admin_init', 'seeded_handle_delete' );
