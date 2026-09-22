<?php
/**
 * Security baseline: the hardening a delivered site needs whatever server it lands on.
 *
 * Everything here lives in the theme on purpose. wp-config.php constants
 * (DISALLOW_FILE_EDIT and friends) and server headers are not in the repository,
 * so a site deployed by cloning it arrives without them. A full audit of a
 * delivered build found every item below missing.
 *
 * @package __starter__
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * XML-RPC off, pingbacks included. `xmlrpc_enabled` alone only gates the
 * authenticated methods; `pingback.ping` stays callable until the method list
 * itself is emptied.
 */
add_filter( 'xmlrpc_enabled', '__return_false' );
add_filter( 'xmlrpc_methods', '__return_empty_array' );

// No RSD link in <head> and no X-Pingback header advertising the endpoint.
remove_action( 'wp_head', 'rsd_link' );
add_filter( 'wp_headers', function ( $headers ) {
	unset( $headers['X-Pingback'] );
	return $headers;
} );

/**
 * Hide the REST user routes from anyone who cannot write posts.
 *
 * `/wp/v2/users` lists every author's login slug to an anonymous visitor. The
 * gate is `edit_posts` rather than `list_users`: the block editor's author
 * selector reads this route, and an Editor has no `list_users`.
 */
add_filter( 'rest_endpoints', function ( $endpoints ) {
	if ( current_user_can( 'edit_posts' ) ) {
		return $endpoints;
	}
	foreach ( array_keys( $endpoints ) as $route ) {
		if ( 0 === strpos( $route, '/wp/v2/users' ) ) {
			unset( $endpoints[ $route ] );
		}
	}
	return $endpoints;
} );

/**
 * Whether the site publishes author archives. Off by default: most builds have
 * no blog, and /author/<nicename>/ (plus the ?author=N redirect to it) hands out
 * the login name. A build with a real blog opts in with
 * add_filter( '__starter___author_archives', '__return_true' );
 * __starter___posted_by() links the byline only when this is true.
 */
function __starter___author_archives_enabled() {
	return (bool) apply_filters( '__starter___author_archives', false );
}

/**
 * With author archives off, `?author=N` and /author/<nicename>/ answer 404
 * instead of redirecting to /author/<login>/. Runs before redirect_canonical
 * (priority 10), which is what performs that redirect.
 */
function __starter___block_author_enumeration() {
	if ( is_admin() || __starter___author_archives_enabled() || ( ! is_author() && ! isset( $_GET['author'] ) ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		return;
	}
	global $wp_query;
	$wp_query->set_404();
	status_header( 404 );
	nocache_headers();
}
add_action( 'template_redirect', '__starter___block_author_enumeration', 1 );

/**
 * No theme or plugin file editor in wp-admin. DISALLOW_FILE_EDIT would do this,
 * but wp-config.php is not deployed with the repository.
 */
add_filter( 'map_meta_cap', function ( $caps, $cap ) {
	if ( in_array( $cap, array( 'edit_themes', 'edit_plugins', 'edit_files' ), true ) ) {
		$caps[] = 'do_not_allow';
	}
	return $caps;
}, 10, 2 );

/**
 * Response headers for front-end pages. Permissions-Policy denies only what a
 * brochure site never asks for; geolocation is left alone because an embedded
 * map may use it. A vhost that also sets them sends two copies of each; check
 * the live response and keep one source.
 */
add_action( 'send_headers', function () {
	if ( headers_sent() ) {
		return;
	}
	header( 'X-Content-Type-Options: nosniff' );
	header( 'X-Frame-Options: SAMEORIGIN' );
	header( 'Referrer-Policy: strict-origin-when-cross-origin' );
	header( 'Permissions-Policy: camera=(), microphone=(), payment=(), usb=()' );
	header_remove( 'X-Powered-By' );
} );
