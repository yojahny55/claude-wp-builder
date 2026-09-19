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
 * Nesting is walked to any depth: a group inside a repeater, a repeater
 * inside a flexible-content layout, and so on. It used to stop at one level,
 * which dropped the deeper text silently -- no error, and a counterpart that
 * looked translated because its top-level fields were.
 *
 * `clone` fields are deliberately never walked as their own type -- see the
 * comment at the end of pllx_acf_walk() for why.
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

/**
 * Walk a set of ACF field objects, emitting translatable text by dotted path.
 *
 * $prefix is the dotted path of the container this call is walking inside,
 * empty at the top level. Recursion carries it down, so a text field three
 * containers deep comes out as "sections.0.cta.label" and addresses itself.
 *
 * The recursion follows VALUES, not definitions: a container contributes
 * nothing when its value is absent, so the walk is bounded by the data on the
 * post and cannot loop even if a field group referenced itself.
 */
function pllx_acf_walk( $objects, &$out, $prefix = '' ) {
	$text = array( 'text', 'textarea', 'wysiwyg' );

	foreach ( $objects as $name => $obj ) {
		$type = isset( $obj['type'] ) ? $obj['type'] : '';
		$val  = isset( $obj['value'] ) ? $obj['value'] : null;
		$subs = isset( $obj['sub_fields'] ) && is_array( $obj['sub_fields'] ) ? $obj['sub_fields'] : array();
		$key  = '' === $prefix ? (string) $name : $prefix . '.' . $name;

		if ( in_array( $type, $text, true ) ) {
			if ( is_string( $val ) && '' !== $val ) {
				$out[ $key ] = $val;
			}
			continue;
		}

		// A `link` field's `title` is translatable text; its `url` is a
		// reference and is re-pointed by the link-rewrite pass in
		// pll-import.php instead (pllx_repoint_acf_refs()), never walked
		// here. At the top level this emits "name.title"; nested, it emits
		// the container path plus ".title", and pllx_acf_write() resolves
		// either by structure rather than by counting the dots.
		if ( 'link' === $type && is_array( $val ) ) {
			if ( isset( $val['title'] ) && is_string( $val['title'] ) && '' !== $val['title'] ) {
				$out[ "$key.title" ] = $val['title'];
			}
			continue;
		}

		if ( 'group' === $type && is_array( $val ) ) {
			pllx_acf_walk( pllx_acf_zip( $subs, $val ), $out, $key );
			continue;
		}

		if ( 'repeater' === $type && is_array( $val ) ) {
			foreach ( $val as $i => $row ) {
				if ( ! is_array( $row ) ) {
					continue;
				}
				pllx_acf_walk( pllx_acf_zip( $subs, $row ), $out, "$key.$i" );
			}
			continue;
		}

		if ( 'flexible_content' === $type && is_array( $val ) ) {
			foreach ( $val as $i => $row ) {
				if ( ! is_array( $row ) || ! isset( $row['acf_fc_layout'] ) ) {
					continue;
				}
				// Matched by layout NAME, not by key, through the same
				// helper the writer uses -- two copies of this rule is two
				// places for a row's layout to be identified differently.
				$layout_subs = pllx_acf_layout_subs( $obj, $row['acf_fc_layout'] );
				pllx_acf_walk( pllx_acf_zip( $layout_subs, $row ), $out, "$key.$i" );
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
 * Pair a container's sub-field definitions with one set of its values.
 *
 * get_field_objects() hands back definition-and-value together at the top
 * level, but a container's sub_fields are definitions only and its value is a
 * plain associative array. Zipping them produces the same definition+value
 * shape the walk already understands, which is what lets one function handle
 * every level instead of one branch per depth.
 *
 * `acf_fc_layout` is the machine identifier naming a flexible-content row's
 * layout. It is never translatable and must never be emitted as a key, even
 * if a layout happened to define a sub_field with that name -- so it is
 * dropped here, at the one place every flexible-content row passes through.
 */
function pllx_acf_zip( $subs, $values ) {
	$out = array();
	foreach ( $subs as $sub ) {
		if ( ! isset( $sub['name'] ) || 'acf_fc_layout' === $sub['name'] ) {
			continue;
		}
		$sname = $sub['name'];
		if ( ! array_key_exists( $sname, $values ) ) {
			continue;
		}
		$obj          = $sub;
		$obj['value'] = $values[ $sname ];
		$out[ $sname ] = $obj;
	}
	return $out;
}

/**
 * Set $value at $parts inside $node, using $def to say what each part means.
 *
 * Returns true when the value was placed. A false return means the path did
 * not match the structure, and the caller writes nothing rather than writing
 * to a guessed location.
 */
function pllx_acf_set( &$node, $def, $parts, $value, $src, $dotted ) {
	$type = isset( $def['type'] ) ? $def['type'] : '';
	$seg  = array_shift( $parts );

	// A `link` is a leaf whose `title` is the only translatable key. Its
	// `url`/`target` are references and are left exactly as they are: this
	// read-modify-write only ever touches the one key.
	if ( 'link' === $type ) {
		if ( 'title' !== $seg || $parts ) {
			pllx_warn( "skipped $dotted: a link field carries no '$seg'" );
			return false;
		}
		$node['title'] = $value;
		return true;
	}

	if ( 'group' === $type ) {
		$subs = isset( $def['sub_fields'] ) && is_array( $def['sub_fields'] ) ? $def['sub_fields'] : array();
		return pllx_acf_descend( $node, $subs, $seg, $parts, $value, $src, $dotted );
	}

	if ( 'repeater' === $type || 'flexible_content' === $type ) {
		// Here, and only here, a path segment is a row index.
		$i = (int) $seg;
		if ( ! isset( $node[ $i ] ) || ! is_array( $node[ $i ] ) ) {
			$node[ $i ] = array();
		}
		$src_row = isset( $src[ $i ] ) && is_array( $src[ $i ] ) ? $src[ $i ] : array();

		if ( 'repeater' === $type ) {
			$subs = isset( $def['sub_fields'] ) && is_array( $def['sub_fields'] ) ? $def['sub_fields'] : array();
		} else {
			// A row created for the first time has no layout tag, and SCF
			// drops a row without one. Carry it across from the source row --
			// a row the target already has keeps its own, untouched.
			if ( ! isset( $node[ $i ]['acf_fc_layout'] ) && isset( $src_row['acf_fc_layout'] ) ) {
				$node[ $i ]['acf_fc_layout'] = $src_row['acf_fc_layout'];
			}
			$layout_name = isset( $node[ $i ]['acf_fc_layout'] ) ? $node[ $i ]['acf_fc_layout'] : '';
			$subs        = pllx_acf_layout_subs( $def, $layout_name );
			if ( ! $subs ) {
				pllx_warn( "skipped $dotted: no layout '$layout_name' on this flexible-content field" );
				return false;
			}
		}

		$seg2 = array_shift( $parts );
		if ( null === $seg2 ) {
			pllx_warn( "skipped $dotted: path ends on a row rather than on a field" );
			return false;
		}
		return pllx_acf_descend( $node[ $i ], $subs, $seg2, $parts, $value, $src_row, $dotted );
	}

	pllx_warn( "skipped $dotted: '$type' is not a container this can write into" );
	return false;
}

/**
 * Place $value under $seg inside a container's value, recursing when $parts
 * still has path left. Shared by the group branch and by both row branches,
 * which differ only in how they arrive here.
 */
function pllx_acf_descend( &$node, $subs, $seg, $parts, $value, $src, $dotted ) {
	if ( ! $parts ) {
		$node[ $seg ] = $value;
		return true;
	}

	$sub = null;
	foreach ( $subs as $candidate ) {
		if ( isset( $candidate['name'] ) && $candidate['name'] === $seg ) {
			$sub = $candidate;
			break;
		}
	}
	if ( null === $sub ) {
		pllx_warn( "skipped $dotted: no sub-field '$seg' in this container" );
		return false;
	}

	if ( ! isset( $node[ $seg ] ) || ! is_array( $node[ $seg ] ) ) {
		$node[ $seg ] = array();
	}
	$src_sub = isset( $src[ $seg ] ) && is_array( $src[ $seg ] ) ? $src[ $seg ] : array();

	return pllx_acf_set( $node[ $seg ], $sub, $parts, $value, $src_sub, $dotted );
}

/**
 * The sub_fields of one named layout on a flexible-content field definition.
 * Matched by layout NAME, not by key -- the same rule pllx_acf_walk() follows,
 * because the row records its layout by name.
 */
function pllx_acf_layout_subs( $def, $layout_name ) {
	$layouts = isset( $def['layouts'] ) && is_array( $def['layouts'] ) ? $def['layouts'] : array();
	foreach ( $layouts as $layout ) {
		if ( isset( $layout['name'] ) && $layout['name'] === $layout_name ) {
			return isset( $layout['sub_fields'] ) && is_array( $layout['sub_fields'] ) ? $layout['sub_fields'] : array();
		}
	}
	return array();
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
