<?php
/**
 * woo-lib.php -- the decisions /wp-woo-setup makes, with no WordPress calls.
 *
 * Loaded by woo-setup.php, and required under bare PHP by tests/checks/woo-lib.sh, which runs
 * every function here against inputs chosen to break it. Keep it that way: a function that
 * needs WordPress belongs in woo-setup.php. PHP 7.4 floor.
 */

/**
 * A scalar as WordPress would store and read it back: `true` -> "1", `false` -> "" (both
 * options are stored as strings), a number -> its canonical string, via json_encode so a
 * float keeps full precision (0.1+0.2 stays distinct from 0.3). `null` is untouched --
 * absent stays distinct from "". Strings are untouched.
 */
function wooset_scalar( $value ) {
	if ( is_bool( $value ) ) {
		return $value ? '1' : '';
	}
	if ( is_int( $value ) || is_float( $value ) ) {
		return json_encode( $value );
	}
	return $value;
}

/**
 * Arrays in a stable order: maps sorted by key, lists left as they are. Objects become maps.
 * Scalar leaves are normalised through wooset_scalar, recursively, so a value read from
 * WordPress and the same value handed in as a native PHP type compare equal.
 */
function wooset_sort( $value ) {
	if ( is_object( $value ) ) {
		$value = get_object_vars( $value );
	}
	if ( ! is_array( $value ) ) {
		return wooset_scalar( $value );
	}
	foreach ( $value as $k => $v ) {
		$value[ $k ] = wooset_sort( $v );
	}
	if ( array() !== $value && array_keys( $value ) !== range( 0, count( $value ) - 1 ) ) {
		ksort( $value, SORT_STRING );
	}
	return $value;
}

function wooset_canon( $value ) {
	return json_encode( wooset_sort( $value ), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE );
}

function wooset_same( $a, $b ) {
	return wooset_canon( $a ) === wooset_canon( $b );
}

function wooset_hash( $value ) {
	return hash( 'sha256', wooset_canon( $value ) );
}

/**
 * What to do with one setting: 'ok' (already the block's value), 'set' (write it), or 'client'
 * (leave it: someone else wrote it).
 *
 * An absent value is nobody's choice, so it is always set -- which is also how a setting added
 * in a later version reaches a store setup has already run on. A recorded hash is the proof
 * this script wrote the current value; without one, only a fresh store is the script's.
 *
 * Callers must pass null for an absent value (`get_option( $name, null )`), never
 * get_option()'s own default of `false` -- that reads as a real, present value here.
 */
function wooset_decide( $current, $desired, $recorded, $fresh, $force ) {
	if ( wooset_same( $current, $desired ) ) {
		return 'ok';
	}
	if ( null === $current || $force ) {
		return 'set';
	}
	if ( null !== $recorded ) {
		return wooset_hash( $current ) === $recorded ? 'set' : 'client';
	}
	return $fresh ? 'set' : 'client';
}

/** Fresh: no orders, and built by this plugin. An adopted store is never fresh. */
function wooset_is_fresh( $has_orders, $origin ) {
	return ! $has_orders && 'adopted' !== $origin;
}

function wooset_key_mode( $key ) {
	if ( preg_match( '/^(sk|rk|pk)_live_/', (string) $key ) ) {
		return 'live';
	}
	if ( preg_match( '/^(sk|rk|pk)_test_/', (string) $key ) ) {
		return 'test';
	}
	return 'unknown';
}

/** The test_* fields holding a live key. Setup refuses the run when this is not empty. */
function wooset_live_key_in_test( array $keys ) {
	$out = array();
	foreach ( $keys as $field => $key ) {
		if ( 0 === strpos( (string) $field, 'test_' ) && 'live' === wooset_key_mode( $key ) ) {
			$out[] = $field;
		}
	}
	return $out;
}

/** A block location string as WooCommerce stores it: "US", "US:FL", "postcode:X", "continent:NA". */
function wooset_location( $code ) {
	$code = (string) $code;
	if ( preg_match( '/^[A-Z]{2}$/', $code ) ) {
		return array( 'code' => $code, 'type' => 'country' );
	}
	if ( preg_match( '/^[A-Z]{2}:[A-Z0-9-]+$/', $code ) ) {
		return array( 'code' => $code, 'type' => 'state' );
	}
	if ( 0 === strpos( $code, 'postcode:' ) ) {
		return array( 'code' => substr( $code, 9 ), 'type' => 'postcode' );
	}
	if ( 0 === strpos( $code, 'continent:' ) ) {
		return array( 'code' => substr( $code, 10 ), 'type' => 'continent' );
	}
	return null;
}

/** Locations as a sorted set of "type:code", so their order in the block does not matter. */
function wooset_locations_canon( $locations ) {
	$out = array();
	foreach ( $locations as $l ) {
		$l     = (array) $l;
		$out[] = $l['type'] . ':' . $l['code'];
	}
	sort( $out, SORT_STRING );
	return $out;
}

/** A ;-separated postcode or city list as a sorted, deduplicated, upper-cased set -- how WooCommerce stores them. */
function wooset_tax_list( $value ) {
	$parts = array();
	foreach ( explode( ';', strtoupper( (string) $value ) ) as $part ) {
		$part = trim( $part );
		if ( '' !== $part ) {
			$parts[] = $part;
		}
	}
	$parts = array_values( array_unique( $parts ) );
	sort( $parts, SORT_STRING );
	return implode( ';', $parts );
}

/** A tax rate from the block or the database, normalised so the two compare. */
function wooset_tax_row( array $r ) {
	return array(
		'id'       => isset( $r['id'] ) ? (int) $r['id'] : 0,
		'country'  => strtoupper( (string) $r['country'] ),
		'state'    => strtoupper( isset( $r['state'] ) ? (string) $r['state'] : '' ),
		'postcode' => wooset_tax_list( isset( $r['postcode'] ) ? $r['postcode'] : '' ),
		'city'     => wooset_tax_list( isset( $r['city'] ) ? $r['city'] : '' ),
		'name'     => (string) $r['name'],
		'class'    => isset( $r['class'] ) && '' !== (string) $r['class'] ? (string) $r['class'] : 'standard',
		'rate'     => number_format( (float) $r['rate'], 4, '.', '' ),
		'shipping' => ! empty( $r['shipping'] ),
	);
}

/** What identifies a rate: where it applies, what it is called, and its class. Not the rate itself. */
function wooset_tax_key( array $row ) {
	return implode( '|', array( $row['country'], $row['state'], $row['postcode'], $row['city'], $row['name'], $row['class'] ) );
}

/** The method settings setup owns. Anything else on the method (its title, say) is left alone. */
function wooset_method_settings( array $method ) {
	switch ( $method['type'] ) {
		case 'flat_rate':
			return array( 'cost' => $method['cost'], 'tax_status' => 'taxable' );
		case 'free_shipping':
			return isset( $method['min_amount'] )
				? array( 'requires' => 'min_amount', 'min_amount' => $method['min_amount'] )
				: array( 'requires' => '' );
		case 'local_pickup':
			return array( 'cost' => isset( $method['cost'] ) ? $method['cost'] : '' );
	}
	return array();
}

/** Whether a cart or checkout page holds WooCommerce's block, its shortcode, or neither. */
function wooset_page_mode( $content, $page ) {
	$content = (string) $content;
	if ( false !== strpos( $content, '<!-- wp:woocommerce/' . $page ) ) {
		return 'block';
	}
	if ( false !== strpos( $content, '[woocommerce_' . $page . ']' ) ) {
		return 'shortcode';
	}
	return 'other';
}

/** A value short enough for one report line. Never called on a secret. */
function wooset_show( $value ) {
	if ( null === $value ) {
		return '(absent)';
	}
	$s = is_scalar( $value ) ? (string) $value : wooset_canon( $value );
	return strlen( $s ) > 60 ? substr( $s, 0, 57 ) . '...' : $s;
}

function wooset_summary( array $n, $plan ) {
	return sprintf(
		"%s: %d %s, %d already right, %d client's, %d degraded",
		$plan ? 'plan' : 'setup',
		$n['set'],
		$plan ? 'to set' : 'set',
		$n['ok'],
		$n['client'],
		$n['degraded']
	);
}
