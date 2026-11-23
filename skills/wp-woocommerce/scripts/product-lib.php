<?php
/**
 * product-lib.php -- the decisions product-seed.php makes, with no WordPress calls, so
 * tests/checks/product-seed.sh runs them under bare PHP. Never run on its own. PHP 7.4 floor.
 *
 * A product entry, as /wp-seed --products reads it (the `products[]` of demo/.yolo-manifest.json,
 * or a client's products.json with the same shape):
 *   name               required
 *   regular_price      required, a plain decimal: "24", "24.00" (no currency sign, no comma)
 *   sale_price         optional, lower than regular_price
 *   sku                optional; when present it is the product's identity
 *   key                optional identity when there is no sku; defaults to the name, slugified
 *   short_description  optional, HTML allowed
 *   description        optional, HTML allowed
 *   categories         optional, names: ["Mugs", "Kitchen"]
 *   image              optional, a URL or a path relative to the products file's directory
 *   gallery            optional, the same, a list
 *   external_url       optional; makes the product External (a catalog's `where-to-buy`)
 *   button_text        optional, External only: the button's label
 *   options            optional, {"Size": ["S", "M"]}: variations are not built, so the product
 *                      is created as a draft and reported for review
 *   source             optional, the demo page it came from, for the report
 */

/** The fields compared between runs, in report order. */
function prodseed_fields() {
	return array( 'name', 'regular_price', 'sale_price', 'short_description', 'description', 'categories', 'image', 'gallery', 'external_url', 'button_text' );
}

/** A lowercase ASCII slug; '' when nothing is left. */
function prodseed_slug( $text ) {
	$text = strtolower( (string) $text );
	if ( function_exists( 'iconv' ) ) {
		$ascii = @iconv( 'UTF-8', 'ASCII//TRANSLIT//IGNORE', $text );
		if ( false !== $ascii ) {
			$text = strtolower( $ascii );
		}
	}
	return trim( (string) preg_replace( '/[^a-z0-9]+/', '-', $text ), '-' );
}

/** A price the source gave as a string or a number, or null when it is not a plain decimal. */
function prodseed_price( $value ) {
	if ( is_int( $value ) || is_float( $value ) ) {
		$value = (string) $value;
	}
	if ( ! is_string( $value ) ) {
		return null;
	}
	$value = trim( $value );
	return 1 === preg_match( '/^\d+(\.\d{1,4})?$/', $value ) ? $value : null;
}

/** An image reference: a URL as is, a relative path resolved against $base_dir. */
function prodseed_image_ref( $ref, $base_dir ) {
	$ref = trim( (string) $ref );
	if ( '' === $ref ) {
		return '';
	}
	if ( 1 === preg_match( '#^https?://#i', $ref ) || '/' === substr( $ref, 0, 1 ) ) {
		return $ref;
	}
	return rtrim( $base_dir, '/' ) . '/' . $ref;
}

/**
 * Validate and normalize one entry. Returns array( 'entry' => array ) or array( 'error' => why ).
 * The entry carries every field of prodseed_fields() plus key, sku, type, has_options, options
 * and source, so a later run compares the same shape.
 */
function prodseed_normalize( $raw, $base_dir ) {
	if ( ! is_array( $raw ) ) {
		return array( 'error' => 'not an object' );
	}
	$name = isset( $raw['name'] ) && is_string( $raw['name'] ) ? trim( $raw['name'] ) : '';
	if ( '' === $name ) {
		return array( 'error' => 'no name' );
	}
	$regular = prodseed_price( isset( $raw['regular_price'] ) ? $raw['regular_price'] : null );
	if ( null === $regular ) {
		return array( 'error' => 'regular_price is missing or not a plain decimal like "24.00"' );
	}
	$sale = '';
	if ( isset( $raw['sale_price'] ) && '' !== $raw['sale_price'] ) {
		$sale = prodseed_price( $raw['sale_price'] );
		if ( null === $sale ) {
			return array( 'error' => 'sale_price is not a plain decimal like "19.00"' );
		}
		if ( (float) $sale >= (float) $regular ) {
			return array( 'error' => 'sale_price ' . $sale . ' is not lower than regular_price ' . $regular );
		}
	}
	$sku = isset( $raw['sku'] ) && is_scalar( $raw['sku'] ) ? trim( (string) $raw['sku'] ) : '';
	$key = '' !== $sku ? 'sku:' . $sku : '';
	if ( '' === $key ) {
		$own = isset( $raw['key'] ) && is_scalar( $raw['key'] ) ? prodseed_slug( $raw['key'] ) : '';
		$key = '' !== $own ? $own : prodseed_slug( $name );
	}
	if ( '' === $key ) {
		return array( 'error' => 'no sku, and neither key nor name gives an identity' );
	}
	$categories = array();
	if ( isset( $raw['categories'] ) ) {
		if ( ! is_array( $raw['categories'] ) ) {
			return array( 'error' => 'categories is not a list of names' );
		}
		foreach ( $raw['categories'] as $cat ) {
			$cat = is_string( $cat ) ? trim( $cat ) : '';
			if ( '' === $cat ) {
				return array( 'error' => 'categories holds an empty or non-string name' );
			}
			$categories[] = $cat;
		}
		$categories = array_values( array_unique( $categories ) );
		sort( $categories, SORT_STRING );
	}
	$gallery = array();
	if ( isset( $raw['gallery'] ) ) {
		if ( ! is_array( $raw['gallery'] ) ) {
			return array( 'error' => 'gallery is not a list' );
		}
		foreach ( $raw['gallery'] as $g ) {
			$g = prodseed_image_ref( is_string( $g ) ? $g : '', $base_dir );
			if ( '' !== $g ) {
				$gallery[] = $g;
			}
		}
	}
	$external = isset( $raw['external_url'] ) && is_string( $raw['external_url'] ) ? trim( $raw['external_url'] ) : '';
	if ( '' !== $external && 1 !== preg_match( '#^https?://#i', $external ) ) {
		return array( 'error' => 'external_url is not an http(s) URL' );
	}
	$options = isset( $raw['options'] ) && is_array( $raw['options'] ) ? $raw['options'] : array();
	$text    = function ( $field ) use ( $raw ) {
		return isset( $raw[ $field ] ) && is_string( $raw[ $field ] ) ? trim( $raw[ $field ] ) : '';
	};
	return array(
		'entry' => array(
			'key'               => $key,
			'sku'               => $sku,
			'type'              => '' !== $external ? 'external' : 'simple',
			'name'              => $name,
			'regular_price'     => $regular,
			'sale_price'        => $sale,
			'short_description' => $text( 'short_description' ),
			'description'       => $text( 'description' ),
			'categories'        => $categories,
			'image'             => prodseed_image_ref( $text( 'image' ), $base_dir ),
			'gallery'           => $gallery,
			'external_url'      => $external,
			'button_text'       => '' !== $external ? $text( 'button_text' ) : '',
			'has_options'       => count( $options ) > 0,
			'options'           => array_keys( $options ),
			'source'            => $text( 'source' ),
		),
	);
}

/**
 * Normalize a whole list. Returns array( 'entries' => list, 'errors' => list of "<label>: why" ).
 * A key used twice is an error on the second: two entries would write one product.
 */
function prodseed_normalize_all( $list, $base_dir ) {
	$entries = array();
	$errors  = array();
	$seen    = array();
	foreach ( array_values( (array) $list ) as $i => $raw ) {
		$label = is_array( $raw ) && isset( $raw['name'] ) && is_string( $raw['name'] ) && '' !== trim( $raw['name'] ) ? trim( $raw['name'] ) : '#' . ( $i + 1 );
		$got   = prodseed_normalize( $raw, $base_dir );
		if ( isset( $got['error'] ) ) {
			$errors[] = $label . ': ' . $got['error'];
			continue;
		}
		$key = $got['entry']['key'];
		if ( isset( $seen[ $key ] ) ) {
			$errors[] = $label . ': same identity (' . $key . ') as ' . $seen[ $key ] . '; give one of them a sku or a key';
			continue;
		}
		$seen[ $key ] = $label;
		$entries[]    = $got['entry'];
	}
	return array(
		'entries' => $entries,
		'errors'  => $errors,
	);
}

/** The digest recorded for a value this script wrote. */
function prodseed_digest( $value ) {
	return sha1( (string) json_encode( $value ) );
}

/**
 * Whose value is a field? $current is what WooCommerce holds now, $last the digest recorded when
 * this script last wrote the field (null when none was recorded), $wanted what the source says.
 *   skip      nothing to write: WooCommerce already holds the source's value
 *   update    WooCommerce still holds what this script wrote, and the source changed
 *   conflict  WooCommerce holds something this script did not write (the client's edit, or a
 *             field with no record): left alone, unless $force
 */
function prodseed_decide( $current, $last, $wanted, $force ) {
	$now = prodseed_digest( $current );
	if ( prodseed_digest( $wanted ) === $now ) {
		return 'skip';
	}
	if ( null !== $last && $last === $now ) {
		return 'update';
	}
	return $force ? 'update' : 'conflict';
}
