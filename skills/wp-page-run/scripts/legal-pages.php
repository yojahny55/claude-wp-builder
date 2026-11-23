<?php
/**
 * legal-pages.php -- create the legal pages /wp-page legal drafted, as drafts, and never
 * touch a page someone already wrote. PHP 7.4 floor.
 *
 * Usage: $WP eval-file legal-pages.php <spec.json> [dry-run]
 *
 * The spec is written by the /wp-page run (skills/wp-page-run/references/legal.md):
 *
 *   {
 *     "default_lang": "en",
 *     "updated": "2026-11-23",
 *     "pages": [
 *       { "role": "privacy", "slug": "privacy-policy", "lang": "en",
 *         "title":   { "en": "Privacy Policy", "es": "Politica de privacidad" },
 *         "content": { "en": "<h2>...</h2>...", "es": "..." } }
 *     ]
 *   }
 *
 * `role` is privacy, terms or cookies. `title` and `content` hold the default language and,
 * under the suffix strategy, one entry per other language: those land in the `_<lang>`
 * copies of the legal fields. `lang` is set with Polylang when Polylang is active.
 *
 * Per page, by slug:
 *   - no page:                  created as a draft on page-legal.php, fields filled  -> created
 *   - WordPress's own privacy   the draft core makes on install, when it is still the
 *     draft, never filled:      privacy page and has no legal_content: filled, kept a
 *                               draft                                                 -> filled
 *   - any other existing page:  left exactly as it is                                 -> kept
 *
 * Nothing is ever published: legal text is reviewed by the client before it goes live.
 * wp_page_for_privacy_policy is set only when it points at no page. Each output line is
 * one JSON object: role, slug, id, action, pending (the count of [[pending: ...]] markers
 * the draft still carries, facts the project did not record and nobody may invent).
 */

defined( 'ABSPATH' ) || exit;

$legal_args = isset( $args ) && is_array( $args ) ? $args : array();
$legal_file = isset( $legal_args[0] ) ? $legal_args[0] : '';
$legal_dry  = in_array( 'dry-run', $legal_args, true );

if ( '' === $legal_file || ! is_readable( $legal_file ) ) {
	WP_CLI::error( 'legal-pages: spec file missing or unreadable' );
}
$legal_spec = json_decode( (string) file_get_contents( $legal_file ), true );
if ( ! is_array( $legal_spec ) || empty( $legal_spec['pages'] ) || ! is_array( $legal_spec['pages'] ) ) {
	WP_CLI::error( 'legal-pages: spec has no pages' );
}
$legal_default = isset( $legal_spec['default_lang'] ) ? (string) $legal_spec['default_lang'] : '';
$legal_updated = isset( $legal_spec['updated'] ) ? (string) $legal_spec['updated'] : gmdate( 'Y-m-d' );
if ( '' === $legal_default ) {
	WP_CLI::error( 'legal-pages: spec has no default_lang' );
}
if ( ! preg_match( '/^\d{4}-\d{2}-\d{2}$/', $legal_updated ) ) {
	WP_CLI::error( 'legal-pages: updated must be YYYY-MM-DD' );
}

/**
 * Write one legal field, through ACF/SCF when it is loaded so the field reference is kept.
 */
function legal_pages_set( $post_id, $name, $value ) {
	if ( function_exists( 'update_field' ) ) {
		update_field( $name, $value, $post_id );
	} else {
		update_post_meta( $post_id, $name, $value );
	}
}

/**
 * Fill the legal fields for every language the page entry carries.
 */
function legal_pages_fill( $post_id, $page, $default, $updated ) {
	// date_picker stores Ymd.
	legal_pages_set( $post_id, 'legal_last_updated', str_replace( '-', '', $updated ) );
	foreach ( array( 'title' => 'legal_title', 'content' => 'legal_content' ) as $key => $field ) {
		foreach ( (array) $page[ $key ] as $lang => $value ) {
			$name = ( $lang === $default ) ? $field : $field . '_' . $lang;
			legal_pages_set( $post_id, $name, 'content' === $key ? wp_kses_post( $value ) : sanitize_text_field( $value ) );
		}
	}
	update_post_meta( $post_id, '_wp_page_template', 'page-legal.php' );
}

$legal_roles   = array( 'privacy', 'terms', 'cookies' );
$legal_privacy = (int) get_option( 'wp_page_for_privacy_policy', 0 );
$legal_failed  = false;

foreach ( $legal_spec['pages'] as $page ) {
	$role = isset( $page['role'] ) ? (string) $page['role'] : '';
	$slug = isset( $page['slug'] ) ? sanitize_title( (string) $page['slug'] ) : '';
	if ( ! in_array( $role, $legal_roles, true ) || '' === $slug
		|| empty( $page['title'][ $legal_default ] ) || empty( $page['content'][ $legal_default ] ) ) {
		WP_CLI::warning( 'legal-pages: skipped an entry without role, slug, or default-language title and content' );
		$legal_failed = true;
		continue;
	}
	$pending = 0;
	foreach ( (array) $page['content'] as $value ) {
		$pending += substr_count( (string) $value, '[[pending:' );
	}

	$existing = get_page_by_path( $slug, OBJECT, 'page' );
	if ( $existing && 'trash' === $existing->post_status ) {
		$existing = null; // a trashed page does not hold the slug for this purpose
	}
	$action = 'created';
	if ( $existing ) {
		$is_core_stub = (int) $existing->ID === $legal_privacy
			&& 'draft' === $existing->post_status
			&& '' === (string) get_post_meta( $existing->ID, 'legal_content', true );
		$action = $is_core_stub ? 'filled' : 'kept';
	}

	$id = $existing ? (int) $existing->ID : 0;
	if ( ! $legal_dry && 'kept' !== $action ) {
		if ( 'created' === $action ) {
			$id = wp_insert_post( array(
				'post_type'   => 'page',
				'post_status' => 'draft',
				'post_name'   => $slug,
				'post_title'  => sanitize_text_field( $page['title'][ $legal_default ] ),
			), true );
			if ( is_wp_error( $id ) ) {
				WP_CLI::warning( 'legal-pages: ' . $slug . ': ' . $id->get_error_message() );
				$legal_failed = true;
				continue;
			}
		}
		legal_pages_fill( $id, $page, $legal_default, $legal_updated );
		if ( ! empty( $page['lang'] ) && function_exists( 'pll_set_post_language' ) ) {
			pll_set_post_language( $id, (string) $page['lang'] );
		}
	}

	if ( 'privacy' === $role && $id && ! $legal_dry ) {
		$current = $legal_privacy ? get_post( $legal_privacy ) : null;
		if ( ! $current || 'trash' === $current->post_status ) {
			update_option( 'wp_page_for_privacy_policy', $id );
			$legal_privacy = $id;
		}
	}

	echo wp_json_encode( array(
		'role'    => $role,
		'slug'    => $slug,
		'id'      => $id,
		'action'  => $action,
		'pending' => $pending,
		'dry_run' => $legal_dry,
	) ) . "\n";
}

if ( $legal_failed ) {
	WP_CLI::halt( 1 );
}
