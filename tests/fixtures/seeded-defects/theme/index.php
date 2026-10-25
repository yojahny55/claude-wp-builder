<?php
/**
 * Fixture index.
 *
 * @package seeded
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

get_header();

// SEEDED WP-020: query_posts() replaces the main query.
query_posts( 'cat=3' );

// SEEDED SEC-001: request value echoed with no escaping.
echo $_GET['s'];

get_footer();
