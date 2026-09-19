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
 * Collect every reference field in a set of field objects, by dotted path.
 *
 * The mirror of pllx_acf_walk(): that one collects translatable TEXT, this one collects
 * the fields that point at another post -- `link`, `page_link`, `post_object`,
 * `relationship` -- so the import can re-point them at the target language's counterpart.
 *
 * It exists because the text walk learned to recurse and this did not, and the gap was
 * worse than the original limit: a nested link came out with a translated title on a URL
 * still pointing at the source language, which reads as translated and is not. Both
 * traversals now share pllx_acf_zip() and the same layout-by-name rule, so a structure one
 * can see is a structure the other can see.
 *
 * $out is filled as path => array( 'type' => ..., 'value' => ... ).
 */
function pllx_acf_refs( $objects, &$out, $prefix = '' ) {
	$refs = array( 'link', 'page_link', 'post_object', 'relationship' );

	foreach ( $objects as $name => $obj ) {
		$type = isset( $obj['type'] ) ? $obj['type'] : '';
		$val  = isset( $obj['value'] ) ? $obj['value'] : null;
		$subs = isset( $obj['sub_fields'] ) && is_array( $obj['sub_fields'] ) ? $obj['sub_fields'] : array();
		$key  = '' === $prefix ? (string) $name : $prefix . '.' . $name;

		if ( in_array( $type, $refs, true ) ) {
			$out[ $key ] = array( 'type' => $type, 'value' => $val );
			continue;
		}

		if ( 'group' === $type && is_array( $val ) ) {
			pllx_acf_refs( pllx_acf_zip( $subs, $val ), $out, $key );
			continue;
		}

		if ( 'repeater' === $type && is_array( $val ) ) {
			foreach ( $val as $i => $row ) {
				if ( is_array( $row ) ) {
					pllx_acf_refs( pllx_acf_zip( $subs, $row ), $out, "$key.$i" );
				}
			}
			continue;
		}

		if ( 'flexible_content' === $type && is_array( $val ) ) {
			foreach ( $val as $i => $row ) {
				if ( ! is_array( $row ) || ! isset( $row['acf_fc_layout'] ) ) {
					continue;
				}
				$layout_subs = pllx_acf_layout_subs( $obj, $row['acf_fc_layout'] );
				pllx_acf_refs( pllx_acf_zip( $layout_subs, $row ), $out, "$key.$i" );
			}
			continue;
		}

		// 'clone' is skipped here for the same reason pllx_acf_walk() skips it: its
		// sub-fields are either already visible as siblings, or are a second view of
		// the same underlying meta, and re-pointing the same reference twice under two
		// paths would have the second write fight the first.
	}
}

/**
 * Read the value at a dotted path, resolving each segment against the field definition
 * exactly as pllx_acf_set() does when writing.
 *
 * Returns null when the path does not resolve. That is deliberately indistinguishable
 * from a genuinely empty field: both mean "there is nothing of the editor's here", which
 * is the only question the ownership check asks of this value.
 */
function pllx_acf_get( $post_id, $dotted, $source_id = 0 ) {
	$parts = explode( '.', $dotted );
	$top   = array_shift( $parts );

	$node = get_field( $top, $post_id );
	if ( ! $parts ) {
		return $node;
	}

	$def = null;
	if ( function_exists( 'get_field_object' ) ) {
		// Source first, for the reason pllx_acf_write() states at length: ACF resolves
		// a field name through the hidden `_<name>` reference meta, so the definition
		// is unavailable on a post that has no value for the field.
		if ( $source_id ) {
			$candidate = get_field_object( $top, $source_id );
			if ( is_array( $candidate ) && isset( $candidate['type'] ) ) {
				$def = $candidate;
			}
		}
		if ( null === $def ) {
			$candidate = get_field_object( $top, $post_id );
			if ( is_array( $candidate ) && isset( $candidate['type'] ) ) {
				$def = $candidate;
			}
		}
	}
	if ( null === $def || ! is_array( $node ) ) {
		return null;
	}

	return pllx_acf_read( $node, $def, $parts );
}

/**
 * The read half of pllx_acf_set(): walk $parts through $node using $def to say whether a
 * segment is a row index or a sub-field name. Pure, so the same test that proves the
 * writer resolves a path proves the reader agrees with it.
 */
function pllx_acf_read( $node, $def, $parts ) {
	$type = isset( $def['type'] ) ? $def['type'] : '';
	$seg  = array_shift( $parts );

	if ( 'link' === $type ) {
		if ( 'title' !== $seg || $parts ) {
			return null;
		}
		return isset( $node['title'] ) ? $node['title'] : null;
	}

	if ( 'group' === $type ) {
		$subs = isset( $def['sub_fields'] ) && is_array( $def['sub_fields'] ) ? $def['sub_fields'] : array();
		return pllx_acf_read_sub( $node, $subs, $seg, $parts );
	}

	if ( 'repeater' === $type || 'flexible_content' === $type ) {
		$i = (int) $seg;
		if ( ! isset( $node[ $i ] ) || ! is_array( $node[ $i ] ) ) {
			return null;
		}
		if ( 'repeater' === $type ) {
			$subs = isset( $def['sub_fields'] ) && is_array( $def['sub_fields'] ) ? $def['sub_fields'] : array();
		} else {
			$layout = isset( $node[ $i ]['acf_fc_layout'] ) ? $node[ $i ]['acf_fc_layout'] : '';
			$subs   = pllx_acf_layout_subs( $def, $layout );
		}
		$seg2 = array_shift( $parts );
		if ( null === $seg2 ) {
			return null;
		}
		return pllx_acf_read_sub( $node[ $i ], $subs, $seg2, $parts );
	}

	return null;
}

function pllx_acf_read_sub( $node, $subs, $seg, $parts ) {
	if ( ! isset( $node[ $seg ] ) ) {
		return null;
	}
	if ( ! $parts ) {
		return $node[ $seg ];
	}
	foreach ( $subs as $candidate ) {
		if ( isset( $candidate['name'] ) && $candidate['name'] === $seg ) {
			return pllx_acf_read( $node[ $seg ], $candidate, $parts );
		}
	}
	return null;
}

/**
 * Write one translated value back to its dotted path.
 *
 * The path is resolved against the field STRUCTURE, never against the number
 * of dots in it. That distinction is the whole function: with nesting walked
 * to any depth, "a.b.c" is a repeater row's field when `a` is a repeater and a
 * group's group's field when `a` is a group, and the two need opposite
 * handling. The previous version branched on `count($parts)` -- 1 plain, 2
 * group, 3 repeater row -- which was correct only while the walker stopped at
 * one level. Against a group inside a group it would have read "b" as a row
 * index, and `(int) 'b'` is 0, so the translation landed in row 0 of a field
 * that has no rows. It also had no branch at all beyond 3 parts, and no else:
 * a deeper key wrote nothing and reported nothing.
 *
 * $source_id is walked in parallel with the target, and is needed for exactly
 * one thing: a flexible-content row being created for the first time has no
 * `acf_fc_layout` tag, SCF silently drops a row that lacks one, and the source
 * post is the only other place that still knows which layout that row is --
 * pllx_acf_walk() deliberately never emits `acf_fc_layout` as translatable.
 */
function pllx_acf_write( $post_id, $dotted, $value, $source_id = 0 ) {
	$parts = explode( '.', $dotted );
	$top   = array_shift( $parts );

	if ( ! $parts ) {
		update_field( $top, $value, $post_id );
		return;
	}

	// The definition is resolved from the SOURCE first, and that ordering is not a
	// preference -- it is the only one that works. ACF resolves a field NAME to its
	// definition through the hidden `_<name>` reference meta on the post, so
	// get_field_object( $name, $post_id ) returns false on a post that has no value
	// for that field. A brand-new translation counterpart has no values at all, which
	// is exactly and only the case this function exists to serve: resolving against
	// the target skipped every write to a new counterpart and reported each one.
	// Measured against SCF 6.5.0 in tests/fixtures/wp/acf-nesting.php, which failed on
	// its first run for this reason.
	//
	// The source always has the value, because the payload being written was walked
	// out of it. The target is tried second for the case where there is no source --
	// pllx_acf_write() is callable with $source_id 0.
	$def = null;
	if ( function_exists( 'get_field_object' ) ) {
		if ( $source_id ) {
			$candidate = get_field_object( $top, $source_id );
			if ( is_array( $candidate ) && isset( $candidate['type'] ) ) {
				$def = $candidate;
			}
		}
		if ( null === $def ) {
			$candidate = get_field_object( $top, $post_id );
			if ( is_array( $candidate ) && isset( $candidate['type'] ) ) {
				$def = $candidate;
			}
		}
	}
	if ( null === $def ) {
		// No definition to resolve against. Writing anyway would mean guessing the
		// shape, which is the defect this function exists to remove; say so instead
		// of writing something arbitrary.
		pllx_warn( "skipped $dotted: no field definition for '$top' on post $post_id or source $source_id" );
		return;
	}

	$node = get_field( $top, $post_id );
	if ( ! is_array( $node ) ) {
		$node = array();
	}
	$src = $source_id ? get_field( $top, $source_id ) : null;

	if ( pllx_acf_set( $node, $def, $parts, $value, is_array( $src ) ? $src : array(), $dotted ) ) {
		update_field( $top, $node, $post_id );
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

/**
 * A post_object/relationship field's row can come back as a bare id or, with
 * return_format => 'object', a WP_Post -- normalise either shape to an int
 * id, or 0 for anything else (unset, false, a stray string).
 */
function pllx_acf_ref_id( $value ) {
	if ( is_numeric( $value ) ) {
		return (int) $value;
	}
	if ( is_array( $value ) && isset( $value['ID'] ) ) {
		return (int) $value['ID'];
	}
	if ( is_object( $value ) && isset( $value->ID ) ) {
		return (int) $value->ID;
	}
	return 0;
}

/**
 * Normalise any reference value to one comparable string.
 *
 * Reference fields come back in several shapes (a string URL, an int, a
 * WP_Post, an array of either), so comparisons are done on this instead.
 */
function pllx_ref_norm( $value ) {
	if ( is_array( $value ) && isset( $value['url'] ) ) {
		return (string) $value['url'];
	}
	if ( is_array( $value ) ) {
		$ids = array();
		foreach ( $value as $row ) {
			$id = pllx_acf_ref_id( $row );
			if ( $id ) {
				$ids[] = $id;
			}
		}
		return implode( ',', $ids );
	}
	if ( is_string( $value ) ) {
		return $value;
	}
	$id = pllx_acf_ref_id( $value );
	return $id ? (string) $id : '';
}

/**
 * May the importer overwrite this reference field?
 *
 * Yes when the field is still empty, or when it holds exactly what the
 * importer itself last wrote there. No when a human has since changed it in
 * wp-admin -- that is a deliberate editorial choice about the translated
 * page, and re-deriving it from the source would silently undo their work on
 * every subsequent import.
 *
 * Comparing against the SOURCE cannot make this distinction: a source whose
 * reference legitimately changed and a target an editor overrode look
 * identical from there. Recording our own writes is what separates them.
 */
function pllx_ref_may_write( $target_id, $name, $current_norm, $source_norm = null ) {
	if ( '' === $current_norm ) {
		return true;
	}
	$stored = get_post_meta( $target_id, PLLX_REF_META . $name, true );
	if ( '' !== $stored && (string) $stored === $current_norm ) {
		return true;
	}
	// Still holding the SOURCE's own unmapped value. That is never a
	// deliberate editorial choice for a translated page -- it is a stale copy
	// pointing into the wrong language, which is exactly what pll-verify.php
	// fails a site over. Counterparts created before this ownership tracking
	// existed all look like this, and refusing to touch them would freeze
	// them wrong forever. An editor's real override points somewhere else,
	// so it is not caught by this branch.
	return null !== $source_norm && '' !== $source_norm && $current_norm === $source_norm;
}

/**
 * Record that the value now on the target is this pass's own.
 *
 * Called on BOTH branches: after a write, and when the target already held
 * exactly what this run would have written. Skipping the second case left the
 * commonest state -- a target that is already correct -- permanently unowned,
 * so the first real source change was refused as an editor's and the field
 * froze for good, with nothing left to ever re-stamp it.
 */
function pllx_ref_claim( $target_id, $name, $norm ) {
	update_post_meta( $target_id, PLLX_REF_META . $name, $norm );
}

/**
 * Resolve $href to its $target_lang counterpart's permalink if it is a
 * same-host link to a post; otherwise return it unchanged.
 *
 * - External links (a different host) are never this function's business.
 * - A same-host URL that is not a post at all (an archive, a term, the home
 *   page -- pllx_url_to_postid() returns 0) has no per-language object to
 *   re-point at and is left exactly as it is.
 * - A same-host post URL whose target has no $target_lang counterpart yet
 *   is left pointed at the source and reported with pllx_warn(): a link
 *   into the wrong language is bad, but a broken link is worse.
 * - Otherwise the href is rewritten to the counterpart's permalink, with the
 *   original query string and fragment preserved, and written back in the
 *   same root-relative-or-absolute form it arrived in.
 *
 * $context is a short human label ("post 605", "menu item 123") used only in
 * the warning message.
 */
function pllx_repoint_internal_url( $href, $target_lang, $context ) {
	$found_id = pllx_url_to_postid( $href );
	if ( ! $found_id ) {
		return $href;
	}

	$target_id = pll_get_post( $found_id, $target_lang );
	if ( ! $target_id ) {
		pllx_warn( "$context links to post $found_id, which has no '$target_lang' counterpart; leaving the link pointed at the source" );
		return $href;
	}

	if ( (int) $target_id === (int) $found_id ) {
		return $href; // already pointing at the correct language (or itself).
	}

	$new_permalink = get_permalink( (int) $target_id );
	if ( ! $new_permalink ) {
		return $href;
	}

	$parts = wp_parse_url( (string) $href );
	$home  = home_url();

	// Root-relative in, root-relative out: strip the scheme+host this pass
	// is not supposed to introduce. get_permalink() may itself carry a query
	// string (?page_id=NN, on a site without pretty permalinks) rather than
	// a clean path, so this strips a literal prefix instead of reassembling
	// pieces from wp_parse_url(), which would silently drop that query
	// string.
	$result = ( empty( $parts['host'] ) && 0 === strpos( $new_permalink, $home ) )
		? substr( $new_permalink, strlen( $home ) )
		: $new_permalink;

	if ( ! empty( $parts['query'] ) ) {
		// Drop the arguments that IDENTIFIED the source post rather than
		// carrying them onto the translation. url_to_postid() matches ?p=N
		// and ?page_id=N first (core rewrite.php:524-530), so re-appending
		// them produced hrefs like '/?page_id=20&page_id=10' -- which
		// WordPress still resolves to the SOURCE post, stably and wrongly, on
		// every run, and which verify's check 9 then failed the site over
		// forever.
		// Removed TEXTUALLY, not via parse_str()/http_build_query(). That round
		// trip re-encodes everything it touches, and measured it changes query
		// strings that have nothing to do with the identifier:
		//   a[]=1&a[]=2   -> a%5B0%5D=1&a%5B1%5D=2   (append becomes indexed)
		//   flag          -> flag=                    (valueless flag gains =)
		//   q=hola%20mundo-> q=hola+mundo
		// Everything not being dropped must survive byte-for-byte, so only the
		// identifying pairs are cut out. `&amp;` is matched as a separator too,
		// since these come out of post_content where hrefs are HTML-escaped.
		$carry = preg_replace(
			'/(^|&(?:amp;)?)(?:p|page_id|attachment_id)=[^&]*/i',
			'$1',
			$parts['query']
		);
		// Collapse separators the removal left behind, then trim the edges.
		// Collapsing to a bare '&' first keeps the trim simple; the original
		// separator style is put back afterwards, because these hrefs come out
		// of post_content where '&amp;' is what an editor's HTML actually
		// carries -- emitting a bare '&' there would rewrite the markup on a
		// pass that is only supposed to change where the link points.
		$carry = preg_replace( '/(?:&(?:amp;)?)+/', '&', (string) $carry );
		$carry = trim( $carry, '&' );
		if ( '' !== $carry ) {
			$amp   = false !== stripos( $parts['query'], '&amp;' ) ? '&amp;' : '&';
			$carry = str_replace( '&', $amp, $carry );
			$result .= ( false === strpos( $result, '?' ) ? '?' : $amp ) . $carry;
		}
	}
	if ( ! empty( $parts['fragment'] ) ) {
		$result .= '#' . $parts['fragment'];
	}

	return $result;
}

/**
 * Re-point every ACF reference on the target at the target language's counterpart.
 *
 * Walks the source's whole field structure, not just its top level: `link`, `page_link`,
 * `post_object` and `relationship` are handled wherever they sit, including inside groups,
 * repeater rows and flexible-content layouts. It used to stop at the top level, which was
 * defensible while the text walk did too -- a nested field was simply untouched at both
 * ends. Once the text walk learned to recurse it stopped being defensible: a nested link
 * got a translated title on a URL still pointing at the source language, which reads as
 * translated and is not, and is worse than the untranslated link it replaced.
 *
 * Ownership is recorded per PATH rather than per field name, so two references differing
 * only by row keep separate records of what this importer last wrote, and an editor's
 * change to one is not read as a change to the other.
 */
function pllx_repoint_acf_refs( $source_id, $target_id, $target_lang ) {
	$source_objects = get_field_objects( $source_id );
	if ( ! is_array( $source_objects ) ) {
		return 0;
	}

	$count = 0;

	// Collected by path rather than read off the top level, so a reference inside a
	// group, a repeater row or a flexible-content layout is re-pointed like any other.
	// $path is a dotted path from here down: it is what the warnings name, and it is what
	// the ownership meta is keyed by, so two references that differ only by row keep
	// separate records of who last wrote them.
	$refs = array();
	pllx_acf_refs( $source_objects, $refs );

	foreach ( $refs as $path => $ref ) {
		$type = $ref['type'];
		$val  = $ref['value'];

		if ( 'link' === $type ) {
			if ( ! is_array( $val ) || empty( $val['url'] ) ) {
				continue;
			}
			$new_url = pllx_repoint_internal_url( $val['url'], $target_lang, "post $target_id, field '$path'" );

			$target_val = pllx_acf_get( $target_id, $path, $source_id );
			if ( ! is_array( $target_val ) ) {
				$target_val = array();
			}
			$current_url = isset( $target_val['url'] ) ? $target_val['url'] : '';
			if ( $current_url !== $new_url ) {
				if ( ! pllx_ref_may_write( $target_id, $path, $current_url, (string) $val['url'] ) ) {
					pllx_warn( "post $target_id, field '$path': link was changed after the last import; leaving '$current_url' alone" );
					continue;
				}
				$target_val['url'] = $new_url;
				if ( ! isset( $target_val['title'] ) ) {
					$target_val['title'] = '';
				}
				if ( ! isset( $target_val['target'] ) ) {
					$target_val['target'] = '';
				}
				pllx_acf_write( $target_id, $path, $target_val, $source_id );
				pllx_ref_claim( $target_id, $path, $new_url );
				$count++;
			} else {
				pllx_ref_claim( $target_id, $path, $new_url );
			}
			continue;
		}

		if ( 'page_link' === $type ) {
			if ( ! is_string( $val ) || '' === $val ) {
				continue;
			}
			$new_url = pllx_repoint_internal_url( $val, $target_lang, "post $target_id, field '$path'" );
			$current = pllx_acf_get( $target_id, $path, $source_id );
			if ( $current !== $new_url ) {
				$current_norm = pllx_ref_norm( $current );
				if ( ! pllx_ref_may_write( $target_id, $path, $current_norm, (string) $val ) ) {
					pllx_warn( "post $target_id, field '$path': page_link was changed after the last import; leaving '$current_norm' alone" );
					continue;
				}
				pllx_acf_write( $target_id, $path, $new_url, $source_id );
				pllx_ref_claim( $target_id, $path, $new_url );
				$count++;
			} else {
				pllx_ref_claim( $target_id, $path, $new_url );
			}
			continue;
		}

		if ( 'post_object' === $type ) {
			$source_post_id = pllx_acf_ref_id( $val );
			if ( ! $source_post_id ) {
				continue;
			}
			$new_id = (int) pll_get_post( $source_post_id, $target_lang );
			if ( ! $new_id ) {
				pllx_warn( "post $target_id, field '$path': post_object references post $source_post_id, which has no '$target_lang' counterpart; leaving it pointed at the source" );
				continue;
			}
			$current_id = pllx_acf_ref_id( pllx_acf_get( $target_id, $path, $source_id ) );
			if ( $current_id !== $new_id ) {
				$current_norm = $current_id ? (string) $current_id : '';
				if ( ! pllx_ref_may_write( $target_id, $path, $current_norm, (string) $source_post_id ) ) {
					pllx_warn( "post $target_id, field '$path': post_object was changed after the last import; leaving post $current_id alone" );
					continue;
				}
				pllx_acf_write( $target_id, $path, $new_id, $source_id );
				pllx_ref_claim( $target_id, $path, (string) $new_id );
				$count++;
			} else {
				pllx_ref_claim( $target_id, $path, (string) $new_id );
			}
			continue;
		}

		if ( 'relationship' === $type ) {
			if ( ! is_array( $val ) || ! $val ) {
				continue;
			}
			$new_ids = array();
			foreach ( $val as $row ) {
				$row_id = pllx_acf_ref_id( $row );
				if ( ! $row_id ) {
					continue;
				}
				$mapped = (int) pll_get_post( $row_id, $target_lang );
				if ( ! $mapped ) {
					pllx_warn( "post $target_id, field '$path': relationship references post $row_id, which has no '$target_lang' counterpart; leaving that entry pointed at the source" );
					$new_ids[] = $row_id; // leave pointed at the source rather than silently drop it.
					continue;
				}
				$new_ids[] = $mapped;
			}

			$current_ids = array();
			foreach ( (array) pllx_acf_get( $target_id, $path, $source_id ) as $row ) {
				$id = pllx_acf_ref_id( $row );
				if ( $id ) {
					$current_ids[] = $id;
				}
			}

			if ( $current_ids !== $new_ids ) {
				$current_norm = implode( ',', $current_ids );
				if ( ! pllx_ref_may_write( $target_id, $path, $current_norm, pllx_ref_norm( $val ) ) ) {
					pllx_warn( "post $target_id, field '$path': relationship was changed after the last import; leaving [$current_norm] alone" );
					continue;
				}
				pllx_acf_write( $target_id, $path, $new_ids, $source_id );
				pllx_ref_claim( $target_id, $path, implode( ',', $new_ids ) );
				$count++;
			} else {
				pllx_ref_claim( $target_id, $path, implode( ',', $new_ids ) );
			}
			continue;
		}
	}

	return $count;
}

/**
 * Create one Polylang language, by code, from Polylang's own predefined list.
 *
 * Lives here rather than in pll-setup.php so tests/fixtures/wp/acf-refs.php creates its
 * languages through the same code the plugin ships, instead of through a copy that can
 * agree with a bug.
 *
 * It takes an admin-capable model rather than PLL()->model, and that is a fix, not a
 * style: add_language() is defined on PLL_Admin_Model, and Polylang only instantiates
 * that subclass when is_admin() is true. Under `wp eval-file` -- the documented way to
 * run every script in this directory -- is_admin() is false and PLL()->model is a plain
 * PLL_Model, so `PLL()->model->add_language()` is a fatal "call to undefined method".
 * The old guard checked class_exists( 'PLL_Settings' ), which is true in both contexts
 * and therefore never caught it. Measured against Polylang 3.6.6 in a fixture.
 */
function pllx_language_model() {
	if ( ! class_exists( 'PLL_Admin_Model' ) || ! function_exists( 'PLL' ) ) {
		return null;
	}
	$model = PLL()->model;
	if ( is_callable( array( $model, 'add_language' ) ) ) {
		return $model;
	}
	// Same options object the live model uses, so the new instance is not a second
	// source of truth for the site's language configuration -- only a way to reach a
	// method the CLI context does not otherwise expose.
	return new PLL_Admin_Model( $model->options );
}

function pllx_add_language( $code, $preferred ) {
	if ( ! class_exists( 'PLL_Settings' ) || ! is_callable( array( 'PLL_Settings', 'get_predefined_languages' ) ) ) {
		pllx_fail( "Cannot read Polylang's predefined language list; add '$code' from the admin instead." );
	}

	$model = pllx_language_model();
	if ( ! $model || ! is_callable( array( $model, 'add_language' ) ) ) {
		pllx_fail( "This Polylang build exposes no way to add a language from the CLI; add '$code' from the admin instead." );
	}

	$predefined = PLL_Settings::get_predefined_languages();
	$want       = isset( $preferred[ $code ] ) ? $preferred[ $code ] : null;
	$chosen     = null;

	foreach ( $predefined as $entry ) {
		$entry_code   = isset( $entry['code'] ) ? $entry['code'] : '';
		$entry_locale = isset( $entry['locale'] ) ? $entry['locale'] : '';
		if ( $want && $entry_locale === $want ) {
			$chosen = $entry;
			break;
		}
		if ( ! $chosen && $entry_code === $code ) {
			$chosen = $entry; // fallback: first match by code
		}
	}

	if ( ! $chosen ) {
		pllx_fail( "'$code' is not a language Polylang recognises." );
	}

	$existing = PLL()->model->get_languages_list();
	$res      = $model->add_language( array(
		'name'       => $chosen['name'],
		'slug'       => $code,
		'locale'     => $chosen['locale'],
		'rtl'        => ! empty( $chosen['dir'] ) && 'rtl' === $chosen['dir'] ? 1 : 0,
		'term_group' => count( $existing ),
		'flag'       => isset( $chosen['flag'] ) ? $chosen['flag'] : '',
	) );

	if ( is_wp_error( $res ) ) {
		pllx_fail( "Could not create language '$code': " . $res->get_error_message() );
	}

	PLL()->model->clean_languages_cache();
	pllx_info( "  created language $code ({$chosen['locale']})" );
}
