<?php
/**
 * Custom template functions for Boilerplate Theme
 *
 * @package __starter__
 */



/**
 * Adds custom classes to the array of body classes.
 *
 * @param array $classes Classes for the body element.
 * @return array
 */
function __starter___body_classes( $classes ) {
	// Adds a class of hfeed to non-singular pages.
	if ( ! is_singular() ) {
		$classes[] = 'hfeed';
	}

	// Adds a class of no-sidebar when there is no sidebar present.
	if ( ! is_active_sidebar( 'sidebar-1' ) ) {
		$classes[] = 'no-sidebar';
	}

	return $classes;
}
add_filter( 'body_class', '__starter___body_classes' );

/**
 * Add a pingback url auto-discovery header for single posts, pages, or attachments.
 */
function __starter___pingback_header() {
	if ( is_singular() && pings_open() ) {
		printf( '<link rel="pingback" href="%s">', esc_url( get_bloginfo( 'pingback_url' ) ) );
	}
}
add_action( 'wp_head', '__starter___pingback_header' );




/**
 * Templates and Page IDs without editor
 *
 */
function __starter___disable_editor( $id = false ) {

	$excluded_templates = array(
//		'page-contact.php',
	);

	$excluded_ids = array(
//		get_option( 'page_on_front' )
	);

	if( empty( $id ) )
		return false;

	$id = intval( $id );
	$template = get_page_template_slug( $id );

	return in_array( $id, $excluded_ids ) || in_array( $template, $excluded_templates );
}

/**
 * Disable Gutenberg by template
 *
 */
function __starter___disable_gutenberg( $can_edit, $post_type ) {

	if( ! ( is_admin() && !empty( $_GET['post'] ) ) )
		return $can_edit;

	if( __starter___disable_editor( $_GET['post'] ) )
		$can_edit = false;

	return $can_edit;

}
//add_filter( 'gutenberg_can_edit_post_type', '__starter___disable_gutenberg', 10, 2 );
//add_filter( 'use_block_editor_for_post_type', '__starter___disable_gutenberg', 10, 2 );
