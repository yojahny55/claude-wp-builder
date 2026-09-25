<?php
/**
 * Removes every option Store Kit owns. The STORE_KIT_STRIPE_* constants in wp-config.php are
 * left in place: they are the operator's, and deleting a site's payment keys is not a
 * side effect anyone expects from removing a plugin.
 */

if ( ! defined( 'WP_UNINSTALL_PLUGIN' ) ) {
	exit;
}

foreach ( array( 'store_kit_catalog_mode', 'store_kit_setup_state' ) as $store_kit_option ) {
	delete_option( $store_kit_option );
}
