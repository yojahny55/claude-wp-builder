<?php
/**
 * Shared helpers for the wp-polylang scripts.
 *
 * Loaded with `require_once __DIR__ . '/pll-lib.php';`. __DIR__ resolves
 * correctly under `wp eval-file` despite its eval() wrapper.
 *
 * PHP 7.4 floor: no match expressions, no union types.
 */

if ( ! defined( 'PLLX_HASH_META' ) ) {
	// Meta key on the TRANSLATION holding the hash of the SOURCE payload.
	define( 'PLLX_HASH_META', '_pll_src_hash' );
}

if ( ! defined( 'PLLX_REF_META' ) ) {
	// Meta key PREFIX on the TRANSLATION recording what the importer itself
	// last wrote into a given ACF reference field. Suffixed with the field
	// name. Lets the reference pass tell "this is my own earlier write, safe
	// to update" from "a human changed this in wp-admin, leave it alone" --
	// a distinction it cannot make by comparing against the source, since a
	// legitimately changed source and an editor's override look identical
	// from there.
	define( 'PLLX_REF_META', '_pll_ref_' );
}

/**
 * Bridge wp eval-file's $args into $GLOBALS.
 *
 * `wp eval-file` evaluates the target script inside a WP-CLI method's local
 * scope, so the $args array it populates with positional arguments is a
 * local variable there — it is never written to $GLOBALS. pllx_args() below
 * reads $args with `global $args;`, which only ever sees $GLOBALS, so
 * without this bridge it always sees an unset value and every script fails
 * its own usage check. This statement runs as top-level code required into
 * that same local scope (require does not open a new scope for top-level
 * statements), so it is the only place that can see the real local $args
 * and mirror it across for pllx_args() to find.
 */
if ( isset( $args ) && ! isset( $GLOBALS['args'] ) ) {
	$GLOBALS['args'] = $args;
}

function pllx_info( $msg ) { echo "[+] $msg\n"; }
function pllx_warn( $msg ) { echo "[!] $msg\n"; }

/** Report and exit non-zero. Never fail silently. */
function pllx_fail( $msg ) {
	fwrite( STDERR, "[x] $msg\n" );
	exit( 1 );
}

/** Read exactly $count positional arguments, or explain the usage and exit. */
function pllx_args( $count, $usage ) {
	global $args;
	$given = is_array( $args ) ? $args : array();
	if ( count( $given ) < $count ) {
		pllx_fail( "Usage: wp eval-file $usage" );
	}
	return array_slice( $given, 0, $count );
}

function pllx_require_polylang() {
	if ( ! function_exists( 'pll_languages_list' ) ) {
		pllx_fail( "Polylang is not active. Run: wp plugin install polylang --activate" );
	}
}

function pllx_require_langs( $source, $target ) {
	$langs = (array) pll_languages_list();
	foreach ( array( $source, $target ) as $l ) {
		if ( ! in_array( $l, $langs, true ) ) {
			pllx_fail( "Language '$l' is not configured. Configured: " . implode( ', ', $langs ) );
		}
	}
	if ( $source === $target ) {
		pllx_fail( "Source and target language are both '$source'." );
	}
}

/**
 * True for the site's date/time format strings.
 *
 * Compared against the actual option values rather than pattern-matched: a
 * heuristic on the shape of a format string produces false positives on short
 * real content, and this comparison is exact.
 */
function pllx_is_date_format( $s ) {
	return in_array( $s, array( get_option( 'date_format' ), get_option( 'time_format' ) ), true );
}

/** The translatable payload of a post. Used for both export and hashing. */
function pllx_post_payload( $post_id ) {
	$p = get_post( $post_id );
	if ( ! $p ) {
		return array( 'fields' => array(), 'acf' => array() );
	}
	return array(
		'fields' => array(
			'post_title'   => $p->post_title,
			'post_content' => $p->post_content,
			'post_excerpt' => $p->post_excerpt,
			'post_name'    => $p->post_name,
		),
		'acf'    => pllx_acf_payload( $post_id ),
	);
}

/**
 * The translatable payload of a term.
 *
 * 'acf' used to be hardcoded empty: nothing walked a term's own custom fields,
 * so a repeater or a plain text field attached to a taxonomy term never
 * reached a translation at all -- a term counterpart came out with a name and
 * nothing else, no error anywhere to say so. ACF/SCF accept the same
 * "<taxonomy>_<term_id>" context string in place of a post id everywhere a
 * post id is otherwise expected (get_field_objects(), get_field(),
 * update_field()), so pllx_acf_payload() -- written for posts -- works here
 * unchanged; only the id passed to it differs.
 */
function pllx_term_payload( $term_id, $taxonomy ) {
	$t = get_term( $term_id, $taxonomy );
	if ( ! $t || is_wp_error( $t ) ) {
		return array( 'fields' => array(), 'acf' => array() );
	}
	return array(
		'fields' => array(
			'name'        => $t->name,
			'description' => $t->description,
			'slug'        => $t->slug,
		),
		'acf'    => pllx_acf_payload( $taxonomy . '_' . $term_id ),
	);
}

/**
 * Flatten a post's translatable ACF values to dot notation.
 *
 * Only text-bearing types are included. Everything else -- images, URLs,
 * numbers, booleans, selects, dates -- is never sent for translation and is
 * instead copied to the counterpart by pllx_acf_copy_untranslated() in
 * pll-import.php, which runs before the translated values are written. This
 * comment used to assert that copy happened without any code doing it, so a
 * new counterpart came out with its text filled in and everything else blank.
 *
 * Ceiling: one level of nesting inside groups, repeaters and flexible-content
 * layouts. Deeper structures (a group nested inside a repeater or a
 * flexible-content layout, etc.) are not walked. `clone` fields are
 * deliberately never walked as their own type -- see the comment at the end
 * of pllx_acf_walk() for why. Widen pllx_acf_walk() if a project needs more.
 */
function pllx_acf_payload( $post_id ) {
	if ( ! function_exists( 'get_field_objects' ) ) {
		return array();
	}
	$objects = get_field_objects( $post_id );
	if ( ! is_array( $objects ) ) {
		return array();
	}
	$out = array();
	pllx_acf_walk( $objects, $out );
	return $out;
}

function pllx_acf_walk( $objects, &$out ) {
	$text = array( 'text', 'textarea', 'wysiwyg' );

	foreach ( $objects as $name => $obj ) {
		$type = isset( $obj['type'] ) ? $obj['type'] : '';
		$val  = isset( $obj['value'] ) ? $obj['value'] : null;
		$subs = isset( $obj['sub_fields'] ) && is_array( $obj['sub_fields'] ) ? $obj['sub_fields'] : array();

		if ( in_array( $type, $text, true ) ) {
			if ( is_string( $val ) && '' !== $val ) {
				$out[ $name ] = $val;
			}
			continue;
		}

		// A `link` field's `title` is translatable text; its `url` is a
		// reference and is re-pointed by the link-rewrite pass in
		// pll-import.php instead (pllx_repoint_acf_refs()), never walked
		// here. `name.title` is written back through the same 2-part
		// (group-shaped) branch of pllx_acf_write() that already
		// read-modify-writes a `link` array's `title` key without
		// disturbing `url`/`target`.
		if ( 'link' === $type && is_array( $val ) ) {
			if ( isset( $val['title'] ) && is_string( $val['title'] ) && '' !== $val['title'] ) {
				$out[ "$name.title" ] = $val['title'];
			}
			continue;
		}

		if ( 'group' === $type && is_array( $val ) ) {
			foreach ( $subs as $sub ) {
				$sname = $sub['name'];
				if ( in_array( $sub['type'], $text, true )
					&& isset( $val[ $sname ] ) && is_string( $val[ $sname ] ) && '' !== $val[ $sname ] ) {
					$out[ "$name.$sname" ] = $val[ $sname ];
				}
			}
			continue;
		}

		if ( 'repeater' === $type && is_array( $val ) ) {
			foreach ( $val as $i => $row ) {
				if ( ! is_array( $row ) ) {
					continue;
				}
				foreach ( $subs as $sub ) {
					$sname = $sub['name'];
					if ( in_array( $sub['type'], $text, true )
						&& isset( $row[ $sname ] ) && is_string( $row[ $sname ] ) && '' !== $row[ $sname ] ) {
						$out[ "$name.$i.$sname" ] = $row[ $sname ];
					}
				}
			}
			continue;
		}

		if ( 'flexible_content' === $type && is_array( $val ) ) {
			$layouts = isset( $obj['layouts'] ) && is_array( $obj['layouts'] ) ? $obj['layouts'] : array();
			foreach ( $val as $i => $row ) {
				if ( ! is_array( $row ) || ! isset( $row['acf_fc_layout'] ) ) {
					continue;
				}
				// Match the row's layout name (NOT its key) against the field
				// object's layouts to find that layout's sub_fields.
				$layout_subs = array();
				foreach ( $layouts as $layout ) {
					if ( isset( $layout['name'] ) && $layout['name'] === $row['acf_fc_layout'] ) {
						$layout_subs = isset( $layout['sub_fields'] ) && is_array( $layout['sub_fields'] ) ? $layout['sub_fields'] : array();
						break;
					}
				}
				foreach ( $layout_subs as $sub ) {
					$sname = $sub['name'];
					// acf_fc_layout is the machine identifier that names the
					// row's layout; it is never translatable and must never
					// be keyed here even if a layout happened to define a
					// sub_field with that name.
					if ( 'acf_fc_layout' === $sname ) {
						continue;
					}
					if ( in_array( $sub['type'], $text, true )
						&& isset( $row[ $sname ] ) && is_string( $row[ $sname ] ) && '' !== $row[ $sname ] ) {
						$out[ "$name.$i.$sname" ] = $row[ $sname ];
					}
				}
			}
			continue;
		}

		// 'clone' is deliberately NOT walked. With the default (seamless)
		// display, a clone's sub-fields surface as ordinary siblings under
		// their own names and are already walked by the branches above --
		// adding a 'clone' branch here would re-emit the same value under a
		// second key. With 'group' display, get_field_objects() returns the
		// clone as a SECOND object (type 'clone') whose value duplicates the
		// original field's, backed by the SAME underlying meta; walking it
		// would emit the same text twice under two different dotted keys, and
		// writing both back independently risks the second write clobbering
		// the first with a different translation. Verified on the SCF 6.9.5
		// fixture: `wp eval` probes for both display modes, see task-8-report.md.
	}
}

/**
 * Deterministic hash of a payload.
 *
 * Keys are sorted so that a change in field order never registers as drift.
 * export and verify MUST both call this — a second implementation would drift
 * and make verify report false staleness on correctly translated content.
 */
function pllx_hash( $payload ) {
	$f = isset( $payload['fields'] ) ? $payload['fields'] : array();
	$a = isset( $payload['acf'] ) ? $payload['acf'] : array();
	ksort( $f );
	ksort( $a );
	return hash( 'sha256', wp_json_encode( array( 'fields' => $f, 'acf' => $a ) ) );
}

/**
 * True when $href is a candidate for pll_url_to_postid()-based resolution:
 * same host as this site (or host-less, i.e. root-relative), and an http(s)
 * URL rather than mailto:, tel:, javascript:, etc.
 *
 * Compared by HOST, not by a home_url() string prefix. Measured on the live
 * site (task-9-report.md, the T9-D probe): home_url() is NOT localized by
 * Polylang under WP-CLI (it returns the same value regardless of
 * PLL()->curlang), so a prefix test would happen to work here -- but
 * url_to_postid() itself is tolerant of a scheme mismatch (it matched an
 * https:// href against an http:// site in the same probe), and a literal
 * prefix comparison is not. Comparing hosts is the correct test either way.
 */
function pllx_is_internal_url( $href ) {
	$parts = wp_parse_url( (string) $href );
	if ( ! is_array( $parts ) ) {
		return false; // unparseable -- never touch it.
	}
	if ( isset( $parts['scheme'] ) && ! in_array( strtolower( $parts['scheme'] ), array( 'http', 'https' ), true ) ) {
		return false; // mailto:, tel:, javascript:, etc.
	}
	if ( empty( $parts['host'] ) ) {
		return true; // root-relative http(s) path on this site.
	}
	$home_host = wp_parse_url( home_url(), PHP_URL_HOST );
	if ( ! is_string( $home_host ) ) {
		return false;
	}
	// A leading 'www.' is stripped from BOTH sides, which is what core's
	// url_to_postid() does (rewrite.php:504-517). Without this a www. href on
	// a non-www. site was neither rewritten by the importer nor audited by the
	// verifier -- it simply fell out of the pipeline unseen. Distinct from the
	// documented limitation about hosts that do not match at all.
	$strip = function ( $host ) {
		return preg_replace( '/^www\./i', '', $host );
	};
	return 0 === strcasecmp( $strip( $parts['host'] ), $strip( $home_host ) );
}

/**
 * Resolve $href to the post id it points at, or 0 when it is not a post URL
 * at all (an archive, a term, the home page) or not an internal URL
 * (see pllx_is_internal_url()).
 */
function pllx_url_to_postid( $href ) {
	if ( ! pllx_is_internal_url( $href ) ) {
		return 0;
	}
	$parts  = wp_parse_url( (string) $href );
	$lookup = ! empty( $parts['host'] ) ? $href : ( home_url() . $href );
	return (int) url_to_postid( $lookup );
}
