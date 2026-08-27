<?php
/**
 * Performance: image delivery (WebP + right-sizing helpers).
 *
 * @package __starter__
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * 1) New uploads: generate WebP for the resized sub-sizes.
 *
 * Note this only affects images that later flow through WP's attachment
 * functions (wp_get_attachment_image, the_post_thumbnail). Templates that print
 * a raw SCF/ACF field URL (echo $field['url']) or a CSS background-image bypass
 * it — those are handled by the output-buffer rewrite in (3).
 */
add_filter( 'image_editor_output_format', function ( $formats ) {
	$formats['image/jpeg'] = 'image/webp';
	$formats['image/png']  = 'image/webp';
	return $formats;
} );

/**
 * 2) On upload, also write a WebP sibling next to the FULL-SIZE original, so
 * raw-URL and CSS-background usage (which reference the original) can be served
 * as WebP by (3). WP keeps the original in its uploaded format; this fills that
 * gap. For a theme seeded from an existing demo, batch-generate the siblings
 * once (any image with a `.webp` next to it is picked up automatically):
 *
 *   find wp-content/uploads -type f \( -iname '*.jpg' -o -iname '*.png' \) \
 *     -exec sh -c 'f="$1"; w="${f%.*}.webp"; [ -f "$w" ] || magick "$f" -quality 82 "$w"' _ {} \;
 */
add_filter( 'wp_generate_attachment_metadata', function ( $metadata, $attachment_id ) {
	$file = get_attached_file( $attachment_id );
	if ( ! $file || ! preg_match( '/\.(jpe?g|png)$/i', $file ) ) {
		return $metadata;
	}
	$webp = preg_replace( '/\.(?:jpe?g|png)$/i', '.webp', $file );
	if ( file_exists( $webp ) ) {
		return $metadata;
	}
	$editor = wp_get_image_editor( $file );
	if ( ! is_wp_error( $editor ) ) {
		$editor->save( $webp, 'image/webp' );
	}
	return $metadata;
}, 10, 2 );

/**
 * 3) Serve WebP for EXISTING + raw-URL + CSS-background images by rewriting the
 * finished HTML: any wp-content/uploads *.jpg/.png with a `.webp` sibling on
 * disk is swapped to `.webp` — covering <img src>, srcset, and inline
 * background-image in one pass. `template_redirect` is front-end only, and with
 * a page cache the buffer runs once per cache build. WebP is universally
 * supported by target browsers (matching the unconditional policy in (1)), so
 * no Accept-header branching is needed.
 */
add_action( 'template_redirect', function () {
	if ( is_admin() || is_feed() || is_robots() ) {
		return;
	}
	$uploads  = wp_get_upload_dir();
	$base_url = $uploads['baseurl'];
	$base_dir = $uploads['basedir'];

	ob_start( function ( $html ) use ( $base_url, $base_dir ) {
		// strpos on the uploads URL is ~free and skips the regex on any page
		// with no uploaded images (404s, search, text-only pages).
		if ( '' === $html || false === strpos( $html, $base_url ) ) {
			return $html;
		}
		$pattern = '#' . preg_quote( $base_url, '#' ) . '/[^"\'\)\s]+?\.(?:jpe?g|png)#i';
		return preg_replace_callback( $pattern, function ( $m ) use ( $base_url, $base_dir ) {
			$webp = preg_replace( '/\.(?:jpe?g|png)$/i', '.webp', $m[0] );
			$path = $base_dir . substr( $webp, strlen( $base_url ) );
			return file_exists( $path ) ? $webp : $m[0];
		}, $html );
	} );
} );

/**
 * Right-sized <img> from an SCF/ACF image field.
 *
 * Prefer this over `echo $field['url']` (which always emits the full-size
 * original — the #1 cause of Lighthouse "responsive-size" / oversized-image
 * waste). Passing the attachment ID lets WP emit a srcset the browser can pick
 * from; the WebP rewrite in (3) then swaps those URLs to `.webp`.
 *
 * @param mixed  $field SCF/ACF image field (array with 'id'/'url', or an ID/URL).
 * @param string $size  Registered image size for the base src (default 'large').
 * @param array  $attr  Extra attributes. ALWAYS set 'sizes' to the element's
 *                      real rendered width, e.g. '(max-width: 899px) 100vw, 50vw',
 *                      a full-bleed hero '100vw', or a fixed logo '136px'.
 * @return string <img> HTML (empty string if the field is empty).
 */
function __starter___image( $field, $size = 'large', $attr = array() ) {
	$id = is_array( $field ) ? (int) ( $field['id'] ?? 0 ) : ( is_numeric( $field ) ? (int) $field : 0 );
	if ( $id ) {
		return wp_get_attachment_image( $id, $size, false, $attr );
	}
	// Fallback: a bare URL (e.g. a theme asset) with no attachment behind it.
	$url = is_array( $field ) ? ( $field['url'] ?? '' ) : (string) $field;
	if ( ! $url ) {
		return '';
	}
	$out = '<img src="' . esc_url( $url ) . '"';
	foreach ( $attr as $k => $v ) {
		$out .= ' ' . esc_attr( $k ) . '="' . esc_attr( $v ) . '"';
	}
	return $out . ' />';
}
