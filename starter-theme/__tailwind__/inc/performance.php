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
 * WebP sibling for an uploads URL, or '' when there is none.
 *
 * Two naming conventions are in the wild and both are checked, because a site
 * can carry either or both. WordPress and (2) above replace the extension
 * (foto.png -> foto.webp); Robin Image Optimizer and most bulk optimizers
 * append instead (foto.png -> foto.png.webp). Checking only the first one is
 * why an optimized library could look entirely unoptimized on the front end.
 *
 * Only local uploads URLs resolve — anything else returns '' rather than
 * guessing a path for a host this site does not serve.
 *
 * @param string $url Absolute URL to a jpg/jpeg/png.
 * @return string WebP URL, or '' if no sibling exists on disk.
 */
function __starter___webp_sibling_url( $url ) {
	static $cache = array();

	$url = (string) $url;
	if ( isset( $cache[ $url ] ) ) {
		return $cache[ $url ];
	}
	$cache[ $url ] = '';

	// A versioned or anchored URL (foto.jpg?ver=3, foto.png#x) names the same file.
	// The extension test anchors on the end of the string, so the suffix has to go
	// first or the sibling is never found.
	$path_only = preg_replace( '/[?#].*$/', '', $url );
	if ( ! preg_match( '/\.(?:jpe?g|png)$/i', $path_only ) ) {
		return '';
	}

	$uploads  = wp_get_upload_dir();
	// The stored URL and the request can disagree on the scheme (http vs https),
	// which would make an otherwise local image look remote.
	$base_url = set_url_scheme( $uploads['baseurl'] );
	$compare  = set_url_scheme( $path_only );
	if ( 0 !== strpos( $compare, $base_url . '/' ) ) {
		return '';
	}
	$relative = substr( $compare, strlen( $base_url ) );
	// Answer in the scheme the caller asked in. The buffer replaces the exact text it
	// matched, so returning the normalized https base for an http match would leave a
	// mixed-scheme URL in the page on any install whose stored base URL disagrees with
	// the request.
	$input_base = substr( $path_only, 0, strlen( $path_only ) - strlen( $relative ) );

	// `<baseurl>/../../secret.png` still starts with the base URL, so the prefix test
	// alone would let file_exists() probe paths outside the uploads directory and
	// answer whether a file is there. Refuse the whole URL instead of normalizing it:
	// nothing legitimate in an uploads URL needs a parent segment.
	if ( false !== strpos( $relative, '..' ) ) {
		return '';
	}

	foreach ( array( $relative . '.webp', preg_replace( '/\.(?:jpe?g|png)$/i', '.webp', $relative ) ) as $candidate ) {
		if ( file_exists( $uploads['basedir'] . $candidate ) ) {
			$cache[ $url ] = $input_base . $candidate;
			return $cache[ $url ];
		}
	}

	return '';
}

/**
 * 3) Serve WebP for EXISTING + raw-URL + CSS-background images by rewriting the
 * finished HTML: any wp-content/uploads *.jpg/.png with a WebP sibling on disk
 * (either naming convention, see __starter___webp_sibling_url) is swapped —
 * covering <img src>, srcset, and inline background-image in one pass.
 * `template_redirect` is front-end only, and with a page cache the buffer runs
 * once per cache build. WebP is universally supported by target browsers
 * (matching the unconditional policy in (1)), so no Accept-header branching is
 * needed.
 *
 * A `background-image` declared in a STYLESHEET is not HTML and never reaches
 * this buffer. Use __starter___background_image() for backgrounds a template
 * prints, and see the wp-robin skill for the server-side rule that covers a
 * stylesheet.
 */
add_action( 'template_redirect', function () {
	if ( is_admin() || is_feed() || is_robots() ) {
		return;
	}
	$uploads  = wp_get_upload_dir();
	$base_url = $uploads['baseurl'];

	ob_start( function ( $html ) use ( $base_url ) {
		// strpos on the uploads URL is ~free and skips the regex on any page
		// with no uploaded images (404s, search, text-only pages).
		if ( '' === $html || false === strpos( $html, $base_url ) ) {
			return $html;
		}
		$count   = 0;
		$pattern = '#' . preg_quote( $base_url, '#' ) . '/[^"\'\)\s]+?\.(?:jpe?g|png)#i';
		return preg_replace_callback( $pattern, function ( $m ) use ( $html ) {
			// __starter___background_image() emits the original URL twice on purpose:
			// as the plain url() fallback and as the non-WebP candidate inside
			// image-set(). Swapping either one for the sibling would hand a browser
			// that cannot parse image-set() a WebP it may not decode — undoing the
			// fallback this buffer is not the author of. Both are recognized by what
			// follows them, so a background the theme already decided about is left
			// exactly as the helper wrote it.
			// PREG_OFFSET_CAPTURE makes each match array( text, offset ).
			list( $text, $offset ) = $m[0];

			$after = substr( $html, $offset + strlen( $text ), 32 );
			if ( 0 === strpos( $after, "') type('" ) || 0 === strpos( $after, "');background-image:image-set(" ) ) {
				return $text;
			}
			$webp = __starter___webp_sibling_url( $text );
			return '' !== $webp ? $webp : $text;
		}, $html, -1, $count, PREG_OFFSET_CAPTURE );
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

/**
 * Percent-encode a URL for use inside a CSS url() token.
 *
 * esc_url() keeps the HTML attribute safe — it strips the quote, angle bracket
 * and raw space that would break out of style="…" — but its whitelist passes
 * `(`, `)`, `'` and `;` through, and CSS reads all four as syntax. A file named
 * `plan (1).png`, which reaches disk on any library moved by rsync rather than
 * through wp_handle_upload(), would truncate the url() token at its first `)`;
 * a `;` in the name could close the declaration and start another one. The
 * server decodes these escapes back to the same file.
 *
 * @param string $url URL, already passed through esc_url().
 * @return string URL safe inside url('…').
 */
function __starter___css_url( $url ) {
	return str_replace(
		array( '(', ')', "'", '"', ';', ',', '\\' ),
		array( '%28', '%29', '%27', '%22', '%3B', '%2C', '%5C' ),
		$url
	);
}

/**
 * 4) WebP for a CSS `background-image`, as a value to print inside a style attribute.
 *
 * Robin Image Optimizer's default delivery mode rewrites <img> tags only, so a
 * background declared in CSS keeps serving the original JPEG/PNG however well
 * the library is optimized. This emits two declarations: the plain url() first,
 * then an image-set() that a browser supporting it uses instead. A browser
 * without image-set()/type() (Safari 16 and older) keeps the first line, so the
 * background never disappears. Each browser requests the URL it understands,
 * which makes this safe behind a full-page cache — unlike Accept-header
 * negotiation, which would cache one format for every visitor.
 *
 * The WebP branch is emitted only when the sibling exists on disk.
 *
 * Every URL goes through esc_url(), which keeps the HTML attribute intact, and
 * then __starter___css_url(), which percent-encodes the characters esc_url()
 * passes through but CSS reads as syntax. The return value is therefore safe to
 * print inside a double-quoted style attribute and must NOT be escaped again:
 *
 *   <div style="<?php echo __starter___background_image( $field['url'] ); ?>">
 *
 * The type() arguments are single-quoted because a double quote would end the
 * attribute.
 *
 * @param string $url Absolute URL of the background image.
 * @return string CSS declarations, or '' when $url is empty.
 */
function __starter___background_image( $url ) {
	$url = trim( (string) $url );
	if ( '' === $url ) {
		return '';
	}

	$src  = __starter___css_url( esc_url( $url ) );
	$css  = "background-image:url('" . $src . "');";
	$webp = __starter___webp_sibling_url( $url );
	if ( '' === $webp ) {
		return $css;
	}

	$type = preg_match( '/\.png(?:[?#]|$)/i', $url ) ? 'image/png' : 'image/jpeg';

	return $css . 'background-image:image-set('
		. "url('" . __starter___css_url( esc_url( $webp ) ) . "') type('image/webp'), "
		. "url('" . $src . "') type('" . $type . "'));";
}
