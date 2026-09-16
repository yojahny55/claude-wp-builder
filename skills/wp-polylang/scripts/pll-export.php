<?php
/**
 * Emit a manifest of everything missing or stale in the target language.
 *
 * Usage: wp eval-file pll-export.php <source_lang> <target_lang> <out.json>
 *
 * Skip logic, per item: no counterpart -> include with target_id null; a
 * counterpart whose stored source hash still matches -> skip, costing no
 * tokens; a counterpart whose hash differs -> include with its target_id so the
 * importer updates in place. Registered strings use the same idea, compared
 * through Polylang's own PLL_MO rather than a stored hash (see the strings
 * section below).
 *
 * Every translatable post type/taxonomy is walked WITHOUT a 'lang' query
 * filter and classified in the loop instead. Filtering by 'lang' at query
 * time silently drops any object that has no language assigned at all
 * (common for post types/taxonomies enabled for translation after Polylang
 * first ran) -- such objects never entered the result set, so no amount of
 * code inside the loop could see, count, or warn about them. Querying
 * everything and branching on pll_get_post_language()/pll_get_term_language()
 * ourselves means every object is accounted for as exactly one of: exported,
 * skipped (already current), unassigned-language (warned about below), or
 * legitimately a different language (silently not ours to export).
 */

require_once __DIR__ . '/pll-lib.php';

list( $source, $target, $out_path ) = pllx_args( 3, 'pll-export.php <source_lang> <target_lang> <out.json>' );

pllx_require_polylang();
pllx_require_langs( $source, $target );

$items      = array();
$skipped    = 0;
$unassigned = array(); // post_type or taxonomy name => count with no language at all.

/**
 * Decide whether an item needs work. Returns [include(bool), target_id|null].
 *
 * $usable_check answers "is the id this group names still a real, live object?"
 * Naming an id is not proof of one. Polylang cleans a translation group on
 * before_delete_post only, so a TRASHED counterpart stays in the group with its
 * hash intact: without this check the item read as fully translated, was never
 * re-exported, and pll-verify.php passed it too -- while the translated page
 * 404s. A term removed without Polylang's hooks leaves the same dangling name,
 * and the importer never got a chance to rebuild it because the item never
 * reached a manifest.
 */
function pllx_needs_work( $translations, $target, $hash, $meta_reader, $usable_check = null ) {
	if ( empty( $translations[ $target ] ) ) {
		return array( true, null );
	}
	$target_id = (int) $translations[ $target ];
	if ( $usable_check && ! call_user_func( $usable_check, $target_id ) ) {
		// Hand back the id: the importer still needs it to tell "rebuild this
		// counterpart" from "create a first one".
		return array( true, $target_id );
	}
	$stored    = call_user_func( $meta_reader, $target_id );
	if ( $stored === $hash ) {
		return array( false, $target_id );
	}
	return array( true, $target_id );
}

// ── Posts (every translatable post type Polylang is configured for) ──────────
$post_types = array_keys( PLL()->model->get_translated_post_types() );

// No 'lang' filter here on purpose -- see the file header. 'inherit' must be
// in the status list or WP_Query drops attachments entirely when queried
// alongside other post types, even though attachment is itself translatable.
$posts = get_posts( array(
	'post_type'        => $post_types,
	'post_status'      => array( 'publish', 'draft', 'pending', 'private', 'inherit' ),
	'numberposts'      => -1,
	'fields'           => 'ids',
	'suppress_filters' => false,
) );

foreach ( $posts as $post_id ) {
	$lang = pll_get_post_language( $post_id );

	if ( '' === $lang || false === $lang ) {
		$pt = get_post_type( $post_id );
		$unassigned[ $pt ] = isset( $unassigned[ $pt ] ) ? $unassigned[ $pt ] + 1 : 1;
		continue;
	}

	if ( $lang !== $source ) {
		continue; // A different language's own object; not ours to export.
	}

	$payload = pllx_post_payload( $post_id );
	$hash    = pllx_hash( $payload );

	list( $include, $target_id ) = pllx_needs_work(
		pll_get_post_translations( $post_id ),
		$target,
		$hash,
		function ( $id ) { return get_post_meta( $id, PLLX_HASH_META, true ); },
		function ( $id ) {
			$p = get_post( $id );
			return $p && 'trash' !== $p->post_status;
		}
	);

	if ( ! $include ) {
		$skipped++;
		continue;
	}

	$items[] = array(
		'id'        => 'post:' . $post_id,
		'kind'      => 'post',
		'post_type' => get_post_type( $post_id ),
		'source_id' => (int) $post_id,
		'target_id' => $target_id,
		'hash'      => $hash,
		'fields'    => $payload['fields'],
		'acf'       => $payload['acf'],
	);
}

// ── Terms ───────────────────────────────────────────────────────────────────
$taxonomies = array_keys( PLL()->model->get_translated_taxonomies() );

foreach ( $taxonomies as $taxonomy ) {
	// No 'lang' filter here either -- same reasoning as the posts query above.
	$terms = get_terms( array( 'taxonomy' => $taxonomy, 'hide_empty' => false ) );
	if ( is_wp_error( $terms ) ) {
		pllx_warn( "Skipping taxonomy '$taxonomy': " . $terms->get_error_message() );
		continue;
	}
	foreach ( $terms as $term ) {
		$lang = pll_get_term_language( $term->term_id );

		if ( '' === $lang || false === $lang ) {
			$unassigned[ $taxonomy ] = isset( $unassigned[ $taxonomy ] ) ? $unassigned[ $taxonomy ] + 1 : 1;
			continue;
		}

		if ( $lang !== $source ) {
			continue; // A different language's own term; not ours to export.
		}

		$payload = pllx_term_payload( $term->term_id, $taxonomy );
		$hash    = pllx_hash( $payload );

		list( $include, $target_id ) = pllx_needs_work(
			pll_get_term_translations( $term->term_id ),
			$target,
			$hash,
			function ( $id ) { return get_term_meta( $id, PLLX_HASH_META, true ); },
			function ( $id ) use ( $taxonomy ) { return get_term( $id, $taxonomy ) instanceof WP_Term; }
		);

		if ( ! $include ) {
			$skipped++;
			continue;
		}

		$items[] = array(
			'id'        => 'term:' . $taxonomy . ':' . $term->term_id,
			'kind'      => 'term',
			'taxonomy'  => $taxonomy,
			'source_id' => (int) $term->term_id,
			'target_id' => $target_id,
			'hash'      => $hash,
			'fields'    => $payload['fields'],
			'acf'       => $payload['acf'],
		);
	}
}

// ── Registered strings ──────────────────────────────────────────────────────
if ( class_exists( 'PLL_Admin_Strings' ) ) {
	// Strings have no per-item stored hash to compare against (unlike posts and
	// terms, there is no target-language object to hold one). Polylang keeps
	// string translations itself in a PLL_MO per language; translate_if_any()
	// returns '' when a string has no translation yet and the actual
	// translation otherwise, so it doubles as the "already current" check.
	// (translate_if_any() is used deliberately over the inherited translate(),
	// which falls back to the SOURCE string when untranslated -- that would
	// misreport a string whose translation happens to equal its source as
	// "already translated".)
	$target_lang = PLL()->model->get_language( $target );
	$target_mo   = null;
	if ( $target_lang && class_exists( 'PLL_MO' ) ) {
		$target_mo = new PLL_MO();
		$target_mo->import_from_db( $target_lang );
	}

	foreach ( PLL_Admin_Strings::get_strings() as $entry ) {
		$value   = isset( $entry['string'] ) ? $entry['string'] : '';
		$context = isset( $entry['context'] ) ? $entry['context'] : 'polylang';

		if ( '' === $value || pllx_is_date_format( $value ) ) {
			$skipped++;
			continue;
		}

		if ( $target_mo && '' !== $target_mo->translate_if_any( $value ) ) {
			$skipped++; // Already translated in the target language.
			continue;
		}

		$hash = pllx_hash( array( 'fields' => array( 'value' => $value ), 'acf' => array() ) );

		$items[] = array(
			'id'      => 'string:' . $context . ':' . md5( $value ),
			'kind'    => 'string',
			'context' => $context,
			'hash'    => $hash,
			'fields'  => array( 'value' => $value ),
		);
	}
}

// ── Menus ───────────────────────────────────────────────────────────────────
// Only the item labels are translated. Re-pointing each item at its
// target-language object is mechanism, and lives in the importer.
$theme_slug   = get_stylesheet();
$pll_options  = get_option( 'polylang' );
$assignments  = isset( $pll_options['nav_menus'][ $theme_slug ] ) ? $pll_options['nav_menus'][ $theme_slug ] : array();

$menu_locations = get_nav_menu_locations();

foreach ( get_registered_nav_menus() as $location => $label ) {
	// Polylang's synthetic per-language keys. PLL_Nav_Menu::create_nav_menu_locations()
	// OVERWRITES $_wp_registered_nav_menus with combined `loc___lang` keys, so
	// get_registered_nav_menus() does yield them wherever admin_init or
	// customize_register has fired. They are not real theme locations: the
	// theme never registered them, nothing renders them under that name, and
	// $assignments is keyed by the BARE location, so every one of them would
	// fall straight through to the bare-menu guess below. Skipped outright.
	if ( false !== strpos( $location, '___' ) ) {
		continue;
	}

	$per_language   = isset( $assignments[ $location ] ) ? (array) $assignments[ $location ] : array();
	$source_menu_id = isset( $per_language[ $source ] ) ? (int) $per_language[ $source ] : 0;

	if ( ! $source_menu_id ) {
		// The bare location key is NOT language-neutral: Polylang unsets the
		// non-default locations before writing the theme mod
		// (admin-nav-menu.php) and rewrites them when the default language
		// changes (Model/Languages.php), so this key holds the DEFAULT
		// language's menu. Taking it unconditionally exports the default
		// language's labels as though they were the source language's --
		// reachable by exporting from any non-default source language, and
		// again whenever update_nav_menu_locations() has stored the falsy 0 it
		// writes for an unassigned location. Accept it only once no other
		// language is recorded as owning it; otherwise refuse and say so,
		// because a wrong menu here is invisible in the manifest.
		$candidate = isset( $menu_locations[ $location ] ) ? (int) $menu_locations[ $location ] : 0;
		$claimed_by_other_language = '';
		foreach ( $per_language as $lang => $menu_id ) {
			if ( $candidate && (int) $menu_id === $candidate && $lang !== $source ) {
				$claimed_by_other_language = (string) $lang;
				break;
			}
		}
		if ( '' !== $claimed_by_other_language ) {
			pllx_warn( "Menu location '$location' has no '$source' menu recorded; its menu ($candidate) is recorded as the '$claimed_by_other_language' menu, so this location is refusing to guess and was not exported." );
			pllx_warn( "  Assign a '$source' menu to '$location' in Appearance > Menus, then re-run." );
			continue;
		}
		$source_menu_id = $candidate;
	}
	if ( ! $source_menu_id ) {
		continue;
	}

	$already = isset( $assignments[ $location ][ $target ] ) ? (int) $assignments[ $location ][ $target ] : 0;

	$menu_items = wp_get_nav_menu_items( $source_menu_id );
	if ( false === $menu_items ) {
		// The menu itself could not be read -- nothing to say about it.
		continue;
	}
	// An EMPTY source menu is still emitted, deliberately. Skipping it meant
	// the importer never created a target menu for the location, so
	// pll-verify.php failed the site with "menu location has no $target menu"
	// on every run, for good, with no way for the pipeline to fix it. An empty
	// menu that exists and is assigned is a valid, verifiable state.
	$menu_items = (array) $menu_items;

	$labels = array();
	foreach ( $menu_items as $mi ) {
		$labels[] = array( 'db_id' => (int) $mi->ID, 'title' => $mi->title );
	}

	$payload = array( 'fields' => array(), 'acf' => array() );
	foreach ( $labels as $l ) {
		$payload['fields'][ 'item_' . $l['db_id'] ] = $l['title'];
	}
	$hash = pllx_hash( $payload );

	if ( $already ) {
		$stored = get_term_meta( $already, PLLX_HASH_META, true );
		if ( $stored === $hash ) {
			$skipped++;
			continue;
		}
	}

	$items[] = array(
		'id'        => 'menu:' . $location,
		'kind'      => 'menu',
		'location'  => $location,
		'menu_id'   => $source_menu_id,
		'target_id' => $already ? $already : null,
		'hash'      => $hash,
		'fields'    => $payload['fields'],
	);
}

$manifest = array(
	'source_lang' => $source,
	'target_lang' => $target,
	'site_url'    => home_url(),
	'items'       => $items,
);

$json = wp_json_encode( $manifest, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES );
if ( false === $json ) {
	pllx_fail( 'Could not encode the manifest as JSON: ' . json_last_error_msg() );
}
if ( false === file_put_contents( $out_path, $json ) ) {
	pllx_fail( "Could not write the manifest to '$out_path'." );
}

$unassigned_total = array_sum( $unassigned );
if ( $unassigned_total > 0 ) {
	$parts = array();
	foreach ( $unassigned as $type => $count ) {
		$parts[] = "$type: $count";
	}
	pllx_warn( "$unassigned_total object(s) in translatable types have no language assigned and were not exported:" );
	pllx_warn( '  ' . implode( ', ', $parts ) );
	pllx_warn( 'Assign a language to them in the Polylang admin, or with pll_set_post_language(), then re-run.' );
}

pllx_info( sprintf( 'Exported %d item(s), skipped %d already current.', count( $items ), $skipped ) );
pllx_info( "Manifest: $out_path" );
