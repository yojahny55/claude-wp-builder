<?php
/**
 * Write a translated manifest back through the Polylang API.
 *
 * Usage: wp eval-file pll-import.php <translated.json>
 *
 * The whole file is validated before the first write. Counterparts are created
 * published, mirroring the source status, so writing half of them and finding
 * the problem at item 30 is not acceptable.
 *
 * No rollback is needed on a mid-run failure: hashes are recorded only after a
 * successful write, so re-running resumes where it stopped. For posts that
 * means after the parent fixup below, not after the inline write -- a child
 * whose parent could not be resolved must stay dirty so the next run retries
 * it, otherwise it sits at the site root forever with nothing to notice.
 */

require_once __DIR__ . '/pll-lib.php';

list( $manifest_path ) = pllx_args( 1, 'pll-import.php <translated.json>' );

pllx_require_polylang();

// KSES strips tags from post_content on save for any user without
// unfiltered_html. Measured on this test site it is NOT registered under
// `wp eval-file` (current user is 0 and the filter is absent), but that is an
// environment fact, not a guarantee: a wrapper that runs this as a real
// low-privilege user would silently strip markup out of every translated post
// -- the same shape as the unslashing bug, corruption with no error.
// Removed explicitly rather than relied upon. This is process-local; each
// `wp eval-file` is its own process, so nothing is left changed on the site.
if ( function_exists( 'kses_remove_filters' ) ) {
	kses_remove_filters();
}

if ( ! is_readable( $manifest_path ) ) {
	pllx_fail( "Cannot read manifest '$manifest_path'." );
}

$manifest = json_decode( file_get_contents( $manifest_path ), true );
if ( ! is_array( $manifest ) ) {
	pllx_fail( 'Manifest is not valid JSON: ' . json_last_error_msg() );
}

foreach ( array( 'source_lang', 'target_lang', 'items' ) as $key ) {
	if ( ! isset( $manifest[ $key ] ) ) {
		pllx_fail( "Manifest is missing '$key'." );
	}
}

$source = $manifest['source_lang'];
$target = $manifest['target_lang'];
pllx_require_langs( $source, $target );

if ( ! is_array( $manifest['items'] ) ) {
	pllx_fail( "Manifest 'items' is not a list." );
}

// ── Validate every item before writing anything ─────────────────────────────
$errors = array();

// Every id in a manifest is meaningful on exactly one site. pll-export.php
// records home_url() so that applying a manifest somewhere else -- a staging
// copy, a second install, a colleague's machine -- is refused instead of
// overwriting whatever content happens to occupy those ids here.
if ( empty( $manifest['site_url'] ) ) {
	$errors[] = "manifest has no 'site_url', so it was not produced by pll-export.php";
} elseif ( untrailingslashit( $manifest['site_url'] ) !== untrailingslashit( home_url() ) ) {
	$errors[] = sprintf(
		"manifest was exported from '%s' but this site is '%s'; ids are not portable between sites",
		$manifest['site_url'],
		home_url()
	);
}

foreach ( $manifest['items'] as $i => $item ) {
	foreach ( array( 'id', 'kind', 'hash', 'fields' ) as $key ) {
		if ( ! isset( $item[ $key ] ) ) {
			$errors[] = "item $i is missing '$key'";
		}
	}
	if ( isset( $item['kind'] ) && ! in_array( $item['kind'], array( 'post', 'term', 'string', 'menu' ), true ) ) {
		$errors[] = "item $i has unknown kind '{$item['kind']}'";
	}
	if ( isset( $item['fields'] ) && ! is_array( $item['fields'] ) ) {
		$errors[] = "item $i has a non-object 'fields'";
	}
	if ( isset( $item['kind'] ) && 'post' === $item['kind'] ) {
		if ( empty( $item['source_id'] ) || ! get_post( $item['source_id'] ) ) {
			$errors[] = "item $i references post {$item['source_id']}, which does not exist";
		} elseif ( ! empty( $item['target_id'] ) ) {
			// target_id decides which post gets OVERWRITTEN -- title, content,
			// excerpt, type, status and translation group all come from the
			// source. Existence alone is not a safe check: one wrong digit in
			// an AI-generated manifest would silently convert an unrelated
			// live page into a translation of this source and orphan its real
			// counterpart. Polylang's own group is the only authority on which
			// post is legitimately this source's counterpart.
			$known    = pll_get_post_translations( (int) $item['source_id'] );
			$expected = isset( $known[ $target ] ) ? (int) $known[ $target ] : 0;
			if ( (int) $item['target_id'] !== $expected ) {
				$errors[] = sprintf(
					"item $i names target_id %d for post %d, but Polylang says %s; refusing to overwrite an unrelated post",
					(int) $item['target_id'],
					(int) $item['source_id'],
					$expected ? "its $target counterpart is $expected" : "it has no $target counterpart"
				);
			}
		}
	}
	if ( isset( $item['kind'] ) && 'term' === $item['kind'] ) {
		$term = empty( $item['taxonomy'] ) || empty( $item['source_id'] )
			? null
			: get_term( $item['source_id'], $item['taxonomy'] );
		// get_term() returns NULL (not a WP_Error) for a nonexistent term id on
		// a valid taxonomy -- is_wp_error() alone lets that case through.
		if ( empty( $item['taxonomy'] ) || empty( $item['source_id'] ) || ! $term || is_wp_error( $term ) ) {
			$errors[] = "item $i references a term that does not exist";
		} elseif ( ! empty( $item['target_id'] ) ) {
			// Same reasoning as the post branch above.
			$known    = pll_get_term_translations( (int) $item['source_id'] );
			$expected = isset( $known[ $target ] ) ? (int) $known[ $target ] : 0;
			if ( (int) $item['target_id'] !== $expected ) {
				$errors[] = sprintf(
					"item $i names target_id %d for term %d, but Polylang says %s; refusing to overwrite an unrelated term",
					(int) $item['target_id'],
					(int) $item['source_id'],
					$expected ? "its $target counterpart is $expected" : "it has no $target counterpart"
				);
			}
		}
	}
}

if ( $errors ) {
	foreach ( $errors as $e ) {
		pllx_warn( $e );
	}
	pllx_fail( sprintf( '%d validation error(s); nothing was written.', count( $errors ) ) );
}

// ── Write ───────────────────────────────────────────────────────────────────
$written        = 0;
$written_posts   = 0;
$written_attach  = 0;
$written_terms   = 0;
$written_strings = 0;

// source_id => target_id, for posts written this run. Used by the parent-fixup
// pass below. Export order is not parent-first, so a parent's counterpart may
// not exist yet when its child is written -- this map lets the fixup pass run
// after every post has its counterpart.
$post_counterparts = array();
// Post hashes are held here and written only after the parent fixup, so an
// unresolved parent leaves the child dirty for the next run.
$post_hashes       = array();
$parents_unresolved = array();
// Terms get the same treatment: wp_update_term() writes parent unconditionally
// and defaults it to 0, so a translated tree is flattened on every re-import
// unless a later pass puts the mapped parent back.
$term_counterparts  = array();
$term_hashes        = array();
$term_parents_unresolved = array();
$acf_copied = 0;

foreach ( $manifest['items'] as $item ) {
	if ( 'post' === $item['kind'] ) {
		$source_id   = (int) $item['source_id'];
		$source_post = get_post( $source_id );
		$fields      = $item['fields'];
		$is_attachment = 'attachment' === $source_post->post_type;

		if ( $is_attachment ) {
			$existing_target_id = ( ! empty( $item['target_id'] ) && get_post( $item['target_id'] ) )
				? (int) $item['target_id']
				: 0;

			if ( $existing_target_id ) {
				// The counterpart already exists (a prior run created it via
				// create_media_translation()); only the translated text needs
				// updating, so a plain wp_update_post() is enough here.
				$target_id = $existing_target_id;
			} else {
				// Attachments need Polylang's own duplication path, not
				// wp_insert_post: create_media_translation() copies the
				// attachment metadata and _wp_attached_file, without which the
				// counterpart is broken media pointing at no file. It also
				// sets the language and joins the translation group itself, so
				// those two steps below are skipped for this branch.
				$target_id = PLL()->model->post->create_media_translation( $source_id, $target );

				if ( empty( $target_id ) ) {
					pllx_warn( "attachment $source_id: create_media_translation() failed" );
					continue;
				}
			}

			$update = array( 'ID' => $target_id );
			if ( isset( $fields['post_title'] ) ) {
				$update['post_title'] = $fields['post_title'];
			}
			if ( isset( $fields['post_content'] ) ) {
				$update['post_content'] = $fields['post_content'];
			}
			if ( isset( $fields['post_excerpt'] ) ) {
				$update['post_excerpt'] = $fields['post_excerpt'];
			}
			// wp_slash() is required, not cosmetic: wp_insert_post(),
			// wp_update_post(), wp_insert_term(), wp_update_term() and
			// wp_update_nav_menu_item() all wp_unslash() their payload before
			// it reaches the database (core post.php:4981,
			// taxonomy.php:2510/3301, nav-menu.php:514/531). Handing them a
			// raw string therefore strips ONE level of backslashes from real
			// content on every single write, and it compounds once per
			// export/import cycle: "C:\\Users\\test" becomes "C:Userstest".
			// Every writer below is slashed for this reason.
			$res = wp_update_post( wp_slash( $update ), true );
			if ( is_wp_error( $res ) ) {
				pllx_warn( "attachment $source_id -> $target_id: " . $res->get_error_message() );
				continue;
			}

			$post_counterparts[ $source_id ] = $target_id;
			$post_hashes[ $source_id ]       = $item['hash'];
			$written++;
			$written_attach++;
			pllx_info( "  attachment $source_id -> $target_id" );
			continue;
		}

		$postarr = array(
			'post_title'   => isset( $fields['post_title'] ) ? $fields['post_title'] : $source_post->post_title,
			'post_content' => isset( $fields['post_content'] ) ? $fields['post_content'] : '',
			'post_excerpt' => isset( $fields['post_excerpt'] ) ? $fields['post_excerpt'] : '',
			'post_name'    => isset( $fields['post_name'] ) ? sanitize_title( $fields['post_name'] ) : '',
			'post_type'    => $source_post->post_type,
			'post_status'  => $source_post->post_status,
			'post_parent'  => 0,
			'menu_order'   => $source_post->menu_order,
		);

		if ( ! empty( $item['target_id'] ) && get_post( $item['target_id'] ) ) {
			$postarr['ID'] = (int) $item['target_id'];
			$target_id     = wp_update_post( wp_slash( $postarr ), true );
		} else {
			$target_id = wp_insert_post( wp_slash( $postarr ), true );
		}

		if ( is_wp_error( $target_id ) ) {
			pllx_warn( "post $source_id: " . $target_id->get_error_message() );
			continue;
		}

		// Language first, then the complete group. pll_save_post_translations()
		// REPLACES the whole group -- it is not a merge -- so any language not
		// named in the array is silently dropped from the group even if that
		// language's post still exists. Read the existing group first and
		// merge into it rather than building a fresh two-key array.
		pll_set_post_language( $target_id, $target );
		$post_group = pll_get_post_translations( $source_id );
		$post_group[ $source ] = $source_id;
		$post_group[ $target ] = $target_id;
		pll_save_post_translations( $post_group );

		// Non-text fields are copied verbatim; only text was translated.
		$thumb = get_post_thumbnail_id( $source_id );
		if ( $thumb ) {
			set_post_thumbnail( $target_id, $thumb );
		}

		if ( function_exists( 'update_field' ) ) {
			// Before the translated values: containers arrive whole, then the
			// manifest overwrites the text keys inside them.
			$acf_copied += pllx_acf_copy_untranslated( $source_id, $target_id );
		}

		if ( ! empty( $item['acf'] ) && function_exists( 'update_field' ) ) {
			foreach ( $item['acf'] as $dotted => $value ) {
				pllx_acf_write( $target_id, $dotted, $value, $source_id );
			}
		} elseif ( ! empty( $item['acf'] ) ) {
			// #9: no silent skip. Export ran with a fields plugin active and
			// import did not, so these strings would be dropped -- and the
			// hash recorded anyway, making them unreachable on every later run.
			pllx_fail( "item {$item['id']} carries ACF values but no custom-fields plugin is active; activate ACF or SCF and re-run." );
		}

		$post_counterparts[ $source_id ] = $target_id;
		$post_hashes[ $source_id ]       = $item['hash'];
		$written++;
		$written_posts++;
		pllx_info( "  post $source_id -> $target_id" );

	} elseif ( 'term' === $item['kind'] ) {
		$source_id = (int) $item['source_id'];
		$taxonomy  = $item['taxonomy'];
		$fields    = $item['fields'];
		$name      = isset( $fields['name'] ) ? $fields['name'] : '';
		$slug      = isset( $fields['slug'] ) ? sanitize_title( $fields['slug'] ) : '';

		if ( '' === $name ) {
			pllx_warn( "term $source_id has an empty name; skipping" );
			continue;
		}

		// instanceof, not ! is_wp_error(): get_term() returns NULL for an id that
		// does not exist, so the old test was TRUE for a dangling target_id and
		// took the update branch, where wp_update_term() fails with
		// invalid_term_id and the term is skipped for good. This is the same
		// trap already documented in the validation loop above -- the post
		// branch gets it right by using get_post(), which falls through to
		// insert. A dangling id reaches here whenever Polylang's group still
		// names a term that was removed without its hooks running.
		if ( ! empty( $item['target_id'] ) && get_term( $item['target_id'], $taxonomy ) instanceof WP_Term ) {
			$target_id = (int) $item['target_id'];
			$res       = wp_update_term( $target_id, $taxonomy, wp_slash( array(
				'name'        => $name,
				'slug'        => $slug,
				'description' => isset( $fields['description'] ) ? $fields['description'] : '',
			) ) );
		} else {
			// $name is a positional argument, so it needs its own wp_slash();
			// wp_insert_term() unslashes it out of $args just the same.
			$res = wp_insert_term( wp_slash( $name ), $taxonomy, wp_slash( array(
				'slug'        => $slug,
				'description' => isset( $fields['description'] ) ? $fields['description'] : '',
			) ) );
		}

		if ( is_wp_error( $res ) ) {
			// A term already carrying this name/slug but sitting outside the
			// translation group is the single most likely way an insert fails
			// here, and it never healed itself: every re-run repeated the same
			// warning while verify kept failing. Polylang's language suffix
			// cannot rescue it either, because pll_set_term_language() runs
			// after the insert and PLL_Term_Slug needs a filter that nothing
			// supplies under wp eval-file. The id needed to fix it is already
			// in the error data, so adopt that term and let the group merge
			// below claim it.
			$existing = 'term_exists' === $res->get_error_code() ? (int) $res->get_error_data() : 0;
			if ( ! $existing ) {
				pllx_warn( "term $source_id: " . $res->get_error_message() );
				continue;
			}
			pllx_info( "  term $source_id: adopting existing term $existing ($taxonomy)" );
			$target_id = $existing;
		} else {
			$target_id = (int) $res['term_id'];
		}

		// Merge into the existing group -- see the equivalent comment in the
		// post branch above. pll_save_term_translations() also replaces rather
		// than merges.
		pll_set_term_language( $target_id, $target );
		$term_group = pll_get_term_translations( $source_id );
		$term_group[ $source ] = $source_id;
		$term_group[ $target ] = $target_id;
		pll_save_term_translations( $term_group );

		$term_counterparts[ $source_id ] = array( $target_id, $taxonomy );
		$term_hashes[ $source_id ]       = $item['hash'];
		$written++;
		$written_terms++;
		pllx_info( "  term $source_id -> $target_id ($taxonomy)" );

	} elseif ( 'string' === $item['kind'] ) {
		$value = isset( $item['fields']['value'] ) ? $item['fields']['value'] : '';
		if ( '' === $value ) {
			pllx_warn( "item {$item['id']} has an empty translated value; skipping" );
			continue;
		}
		pllx_string_translate( $item['id'], $value, $target );
		$written++;
		$written_strings++;

	} elseif ( 'menu' === $item['kind'] ) {
		$location   = $item['location'];
		$source_menu = wp_get_nav_menu_object( (int) $item['menu_id'] );
		if ( ! $source_menu ) {
			pllx_warn( "menu {$item['menu_id']} no longer exists; skipping" );
			continue;
		}

		$target_menu_name = $source_menu->name . ' (' . strtoupper( $target ) . ')';

		if ( ! empty( $item['target_id'] ) && wp_get_nav_menu_object( (int) $item['target_id'] ) ) {
			$target_menu_id = (int) $item['target_id'];
		} else {
			$existing = wp_get_nav_menu_object( $target_menu_name );
			if ( $existing ) {
				$target_menu_id = (int) $existing->term_id;
			} else {
				$created = wp_create_nav_menu( $target_menu_name );
				if ( is_wp_error( $created ) ) {
					pllx_warn( "menu: " . $created->get_error_message() );
					continue;
				}
				$target_menu_id = (int) $created;
			}
		}

		// A manifest naming the SOURCE menu as its own target would make the
		// rebuild below hard-delete every item out of a real menu and then
		// find nothing to copy back. Unrecoverable, and the validation loop
		// never looks at menu ids, so it is refused here.
		if ( $target_menu_id === (int) $item['menu_id'] ) {
			pllx_fail( "item {$item['id']} names menu {$item['menu_id']} as both source and target; refusing to empty a real menu." );
		}

		// Read BEFORE the delete loop. When these two were the other way
		// round, any path that made target and source the same menu emptied it
		// and then read zero items back.
		//
		// Reconciliation counters: every source item must land as either
		// written or skipped-with-a-reason. A translated menu silently missing
		// most of its entries is a worse outcome for a visitor than one
		// mis-pointed item, and nothing else would ever catch it -- so this is
		// asserted by the caller, not just logged.
		$source_items    = (array) wp_get_nav_menu_items( (int) $item['menu_id'] );

		// Rebuild from scratch so a re-run cannot accumulate duplicates.
		foreach ( (array) wp_get_nav_menu_items( $target_menu_id ) as $old ) {
			wp_delete_post( $old->ID, true );
		}

		$menu_source_ct  = count( $source_items );
		$menu_written_ct = 0;
		$menu_skipped_ct = 0;
		$skip_reasons    = array();

		$id_map  = array();
		// old_id => [ 'parent' => old_parent_id, 'new_id' => new_id|null ].
		// Parent links are corrected in a second pass below, once every
		// surviving item in this menu exists -- menu order is not
		// parent-first, the same reasoning as the post parent-fixup pass
		// further down this file.
		$records = array();

		foreach ( $source_items as $mi ) {
			$title = isset( $item['fields'][ 'item_' . $mi->ID ] )
				? $item['fields'][ 'item_' . $mi->ID ]
				: $mi->title;

			$args = array(
				'menu-item-title'     => $title,
				'menu-item-status'    => 'publish',
				'menu-item-type'      => $mi->type,
				'menu-item-parent-id' => 0, // corrected in the parent-fixup pass below.
				'menu-item-position'  => (int) $mi->menu_order,
			);

			$skip_reason = null;

			if ( 'post_type' === $mi->type ) {
				// The whole point: re-point at the target-language object.
				$translations = pll_get_post_translations( (int) $mi->object_id );
				if ( empty( $translations[ $target ] ) ) {
					$skip_reason = "no $target counterpart";
				} else {
					$args['menu-item-object']    = $mi->object;
					$args['menu-item-object-id'] = (int) $translations[ $target ];
				}
			} elseif ( 'taxonomy' === $mi->type ) {
				$translations = pll_get_term_translations( (int) $mi->object_id );
				if ( empty( $translations[ $target ] ) ) {
					$skip_reason = "no $target term counterpart";
				} else {
					$args['menu-item-object']    = $mi->object;
					$args['menu-item-object-id'] = (int) $translations[ $target ];
				}
			} elseif ( 'custom' === $mi->type ) {
				$args['menu-item-url'] = $mi->url;
			} elseif ( 'post_type_archive' === $mi->type ) {
				// Keyed by a post type slug, not an object id, so there is no
				// per-language counterpart to look up -- and none is needed.
				// wp_setup_nav_menu_item() resolves an archive item's URL at
				// RENDER time through get_post_type_archive_link(), and
				// Polylang localizes that against the current language.
				// Measured on Polylang 3.8.7 with force_lang=1: the same call
				// returns /tienda/ with curlang=es and /en/tienda/ with
				// curlang=en. So this item is COPIED, not re-pointed:
				// menu-item-object carries the post type slug and
				// menu-item-url is deliberately left unset, since writing
				// $mi->url would freeze the SOURCE permalink into the
				// translated menu. Skipping it, which an earlier version did,
				// silently deletes a working nav entry from every translated
				// menu.
				$args['menu-item-object'] = $mi->object;
			} else {
				$skip_reason = "unhandled menu item type '{$mi->type}'";
			}

			if ( null !== $skip_reason ) {
				pllx_warn( "  menu item '{$mi->title}' has $skip_reason; skipping" );
				$menu_skipped_ct++;
				$skip_reasons[ $skip_reason ] = isset( $skip_reasons[ $skip_reason ] ) ? $skip_reasons[ $skip_reason ] + 1 : 1;
				$records[ (int) $mi->ID ] = array( 'parent' => (int) $mi->menu_item_parent, 'new_id' => null );
				continue;
			}

			$new_id = wp_update_nav_menu_item( $target_menu_id, 0, wp_slash( $args ) );
			if ( is_wp_error( $new_id ) ) {
				pllx_warn( "  menu item '{$mi->title}': " . $new_id->get_error_message() );
				$menu_skipped_ct++;
				$skip_reasons['write error'] = isset( $skip_reasons['write error'] ) ? $skip_reasons['write error'] + 1 : 1;
				$records[ (int) $mi->ID ] = array( 'parent' => (int) $mi->menu_item_parent, 'new_id' => null );
				continue;
			}

			$id_map[ (int) $mi->ID ]  = (int) $new_id;
			$records[ (int) $mi->ID ] = array( 'parent' => (int) $mi->menu_item_parent, 'new_id' => (int) $new_id );
			$menu_written_ct++;
		}

		// Parent fixup: menu order is not parent-first, so a child item can be
		// built before its parent, in which case it would otherwise be left
		// under 'menu-item-parent-id' => 0 and the submenu would flatten.
		// Fixed the same way as the post parent-fixup pass below: correct
		// every surviving item's parent now that all of them exist.
		foreach ( $records as $rec ) {
			if ( null === $rec['new_id'] || 0 === $rec['parent'] ) {
				continue;
			}
			if ( empty( $id_map[ $rec['parent'] ] ) ) {
				continue; // Parent itself was skipped; leave at top level rather than guess.
			}
			update_post_meta( $rec['new_id'], '_menu_item_menu_item_parent', (string) $id_map[ $rec['parent'] ] );
		}

		// Per-language assignment lives in the polylang option, not theme mods.
		$theme_slug = get_stylesheet();
		$options    = get_option( 'polylang' );
		if ( ! isset( $options['nav_menus'] ) || ! is_array( $options['nav_menus'] ) ) {
			$options['nav_menus'] = array();
		}
		$options['nav_menus'][ $theme_slug ][ $location ][ $source ] = (int) $item['menu_id'];
		$options['nav_menus'][ $theme_slug ][ $location ][ $target ] = $target_menu_id;
		update_option( 'polylang', $options );

		update_term_meta( $target_menu_id, PLLX_HASH_META, $item['hash'] );
		$written++;

		$reason_summary = array();
		foreach ( $skip_reasons as $reason => $count ) {
			$reason_summary[] = "$reason: $count";
		}
		pllx_info( "  menu {$item['menu_id']} -> $target_menu_id ($location)" );
		pllx_info( sprintf(
			'  menu %s reconciliation: source=%d written=%d skipped=%d%s',
			$location,
			$menu_source_ct,
			$menu_written_ct,
			$menu_skipped_ct,
			$reason_summary ? ' (' . implode( ', ', $reason_summary ) . ')' : ''
		) );
	}
}

// ── Parent fixup ──────────────────────────────────────────────────────────
//
// Every post above was written with post_parent = 0, since export order is
// not parent-first: a child can appear before its parent in the manifest, so
// there is no way to know the parent's counterpart id while writing the
// child inline. This second pass runs only after every post counterpart in
// this run exists, so it can look each one up.
$parents_fixed = 0;
foreach ( $post_counterparts as $source_id => $target_id ) {
	$source_post = get_post( $source_id );
	if ( ! $source_post || 0 === (int) $source_post->post_parent ) {
		continue;
	}

	$source_parent_id = (int) $source_post->post_parent;
	$parent_translations = pll_get_post_translations( $source_parent_id );

	if ( empty( $parent_translations[ $target ] ) ) {
		// Parent has no counterpart yet (not in this manifest, or not yet
		// translated). Nothing to point at; leave post_parent at 0 rather
		// than guess -- but do NOT record this child's hash, or the next
		// export will consider it current and it will never be revisited.
		$parents_unresolved[ $source_id ] = true;
		continue;
	}

	$target_parent_id = (int) $parent_translations[ $target ];
	$res = wp_update_post( array(
		'ID'          => $target_id,
		'post_parent' => $target_parent_id,
	), true );

	if ( is_wp_error( $res ) ) {
		pllx_warn( "post $target_id: could not set post_parent to $target_parent_id: " . $res->get_error_message() );
		$parents_unresolved[ $source_id ] = true;
		continue;
	}

	$parents_fixed++;
}

// ── Term parent fixup ─────────────────────────────────────────────────────
//
// Core's wp_update_term() defaults 'parent' to 0 and writes it
// (taxonomy.php:3292 and :3446), so every update of a translated term reset
// its parent -- destroying a hierarchy an editor set by hand -- and
// wp_insert_term() was passed no parent either, so a source tree came out as
// a set of root terms. pllx_term_payload() carries no parent, on purpose:
// export order is not parent-first here any more than it is for posts, so the
// mapping can only be done once every counterpart in this run exists.
$term_parents_fixed = 0;
foreach ( $term_counterparts as $source_id => $pair ) {
	list( $target_id, $taxonomy ) = $pair;
	$source_term = get_term( $source_id, $taxonomy );
	if ( ! $source_term instanceof WP_Term || 0 === (int) $source_term->parent ) {
		continue;
	}

	$parent_group = pll_get_term_translations( (int) $source_term->parent );
	if ( empty( $parent_group[ $target ] ) ) {
		// Same rule as posts: nothing to point at, so leave it at the root and
		// withhold the hash so the next run retries instead of calling it done.
		$term_parents_unresolved[ $source_id ] = true;
		continue;
	}

	$res = wp_update_term( $target_id, $taxonomy, array( 'parent' => (int) $parent_group[ $target ] ) );
	if ( is_wp_error( $res ) ) {
		pllx_warn( "term $target_id: could not set parent: " . $res->get_error_message() );
		$term_parents_unresolved[ $source_id ] = true;
		continue;
	}
	$term_parents_fixed++;
}

foreach ( $term_hashes as $source_id => $hash ) {
	if ( isset( $term_parents_unresolved[ $source_id ] ) ) {
		continue;
	}
	update_term_meta( $term_counterparts[ $source_id ][0], PLLX_HASH_META, $hash );
}

// Now, and only now, are post hashes safe to record. A child written with
// post_parent = 0 whose parent turned out to have no counterpart -- because
// the parent's own write failed earlier in this run, or it simply is not
// translated yet -- is deliberately left without a hash, so the next export
// picks it up again and the fixup gets another chance. Recording it inline,
// as this used to, made that child permanently invisible: its hash matched,
// so it never re-entered a manifest, so the fixup never saw it again, and it
// sat at the site root with a changed permalink that nothing reports.
$hashes_withheld = 0;
foreach ( $post_hashes as $source_id => $hash ) {
	if ( isset( $parents_unresolved[ $source_id ] ) ) {
		$hashes_withheld++;
		continue;
	}
	update_post_meta( $post_counterparts[ $source_id ], PLLX_HASH_META, $hash );
}
if ( $hashes_withheld ) {
	pllx_warn( sprintf(
		'%d post(s) left unhashed because their parent has no %s counterpart yet; re-run after translating the parent.',
		$hashes_withheld,
		$target
	) );
}

// ── Internal link rewrite pass ──────────────────────────────────────────────
//
// A source post's content, or an ACF reference field, may point at another
// source-language post by its own permalink or id. The main loop above
// copies post_content (and reference-holding ACF field types are not part of
// the translatable payload at all -- see pllx_acf_payload()'s docblock), so
// that reference still points at the SOURCE-language post after import: a
// visitor on the English page clicks a button and lands back on the Spanish
// site. This is the same defect pll-verify.php's menu check exists to catch,
// in a different store.
//
// Scope: every TARGET-language post with a SOURCE-language counterpart, not
// only the ones (re)written by the loop above. A link's target may gain its
// own counterpart only in THIS run, on a post that hashed as unchanged and
// was therefore skipped by the main loop -- restricting this pass to
// $post_counterparts would leave that link pointing at the source language
// forever, since the linking post's hash never changes again to bring it
// back through the main loop. The pass is idempotent (each rewrite is
// compared against the current value before writing, so a second run finds
// nothing left to change) and cheap, so it runs over every post every time.
$links_rewritten    = 0;
$acf_refs_rewritten = 0;

$translated_types = array_keys( PLL()->model->get_translated_post_types() );
$candidate_ids     = get_posts( array(
	'post_type'        => $translated_types,
	'post_status'      => array( 'publish', 'draft', 'pending', 'private', 'inherit' ),
	'numberposts'      => -1,
	'fields'           => 'ids',
	'suppress_filters' => false,
) );

$has_acf = function_exists( 'get_field_objects' ) && function_exists( 'update_field' );

foreach ( $candidate_ids as $target_post_id ) {
	if ( pll_get_post_language( $target_post_id ) !== $target ) {
		continue;
	}
	$group = pll_get_post_translations( $target_post_id );
	if ( empty( $group[ $source ] ) ) {
		continue; // no source counterpart -- nothing to have inherited a stale link from.
	}
	$source_post_id = (int) $group[ $source ];

	$post = get_post( $target_post_id );
	if ( ! $post || false === strpos( (string) $post->post_content, 'href=' ) ) {
		// No href at all -- cheap skip before the regex, not a correctness
		// requirement (preg_replace_callback would simply find nothing).
	} else {
		$content     = $post->post_content;
		$new_content = preg_replace_callback(
			'/href=(["\'])([^"\']+)\1/',
			function ( $m ) use ( $target, $target_post_id ) {
				return 'href=' . $m[1] . pllx_repoint_internal_url( $m[2], $target, "post $target_post_id" ) . $m[1];
			},
			$content
		);

		if ( $new_content !== $content ) {
			$res = wp_update_post( wp_slash( array( 'ID' => $target_post_id, 'post_content' => $new_content ) ), true );
			if ( is_wp_error( $res ) ) {
				pllx_warn( "post $target_post_id: could not rewrite internal link(s): " . $res->get_error_message() );
			} else {
				$links_rewritten++;
			}
		}
	}

	if ( $has_acf ) {
		$acf_refs_rewritten += pllx_repoint_acf_refs( $source_post_id, $target_post_id, $target );
	}
}

pllx_info( sprintf(
	'Rewrote internal link(s) in %d post(s) and %d ACF reference field(s).',
	$links_rewritten,
	$acf_refs_rewritten
) );

// ── Custom menu items pointing at a post (ruling T9-F) ──────────────────────
//
// The menu branch above copies a 'custom' item's URL verbatim, on the theory
// that a custom item is an arbitrary external URL -- but that is false
// whenever the URL happens to be one of the site's own permalinks: a
// duplicated menu produces exactly this shape (a literal href, not an
// object id + type Polylang can re-point through pll_get_post_translations),
// so a stale source-language slug here is the same defect this whole task
// exists to close, in a different store. pll-verify.php's check 1 only ever
// inspected 'post_type' and 'taxonomy' items, so it could not see this at
// all. Scope: every TARGET-language menu recorded in the 'polylang' option,
// run every time, for the same reason as the pass above.
$custom_menu_items_rewritten = 0;
$theme_slug                  = get_stylesheet();
$polylang_options            = get_option( 'polylang' );
$nav_menu_locations          = isset( $polylang_options['nav_menus'][ $theme_slug ] ) ? $polylang_options['nav_menus'][ $theme_slug ] : array();

foreach ( $nav_menu_locations as $per_lang ) {
	if ( empty( $per_lang[ $target ] ) ) {
		continue;
	}
	foreach ( (array) wp_get_nav_menu_items( (int) $per_lang[ $target ] ) as $mi ) {
		if ( 'custom' !== $mi->type ) {
			continue;
		}
		$new_url = pllx_repoint_internal_url( $mi->url, $target, "menu item {$mi->ID}" );
		if ( $new_url !== $mi->url ) {
			update_post_meta( (int) $mi->ID, '_menu_item_url', $new_url );
			$custom_menu_items_rewritten++;
		}
	}
}

pllx_info( sprintf( 'Rewrote %d custom menu item URL(s).', $custom_menu_items_rewritten ) );

pllx_info( sprintf(
	'Wrote %d item(s): %d post(s), %d attachment(s), %d term(s), %d string(s).',
	$written,
	$written_posts,
	$written_attach,
	$written_terms,
	$written_strings
) );
pllx_info( sprintf( 'Fixed %d parent-child relationship(s).', $parents_fixed ) );
pllx_info( sprintf( 'Fixed %d term parent relationship(s).', $term_parents_fixed ) );
pllx_info( sprintf( 'Copied %d untranslated ACF value(s) to new counterparts.', $acf_copied ) );

/**
 * Write one flattened ACF value back.
 *
 * Dot notation mirrors pllx_acf_walk(): `name`, `group.sub`, `repeater.0.sub`,
 * and, since Task 8, `flex_field.0.sub` for flexible-content rows -- the two
 * share the same 3-part shape and this function does not distinguish them.
 *
 * $source_id is the SOURCE post (its field-having-been-walked side), used
 * only to backfill a flexible-content row's `acf_fc_layout` on first write --
 * see the comment in the 3-part branch below. Optional and unused by the
 * other branches; omit it where the caller has no source post (there is
 * currently no such caller, but the parameter defaults to 0 rather than being
 * required so a future caller without a source post does not have to fake one).
 */
function pllx_acf_write( $post_id, $dotted, $value, $source_id = 0 ) {
	$parts = explode( '.', $dotted );

	if ( 1 === count( $parts ) ) {
		update_field( $parts[0], $value, $post_id );
		return;
	}

	if ( 2 === count( $parts ) ) {
		$group = get_field( $parts[0], $post_id );
		if ( ! is_array( $group ) ) {
			$group = array();
		}
		$group[ $parts[1] ] = $value;
		update_field( $parts[0], $group, $post_id );
		return;
	}

	if ( 3 === count( $parts ) ) {
		$rows = get_field( $parts[0], $post_id );
		if ( ! is_array( $rows ) ) {
			$rows = array();
		}
		$i = (int) $parts[1];
		if ( ! isset( $rows[ $i ] ) || ! is_array( $rows[ $i ] ) ) {
			$rows[ $i ] = array();
		}
		$rows[ $i ][ $parts[2] ] = $value;

		// A repeater row is a plain associative array and tolerates being
		// built up one key at a time by this read-modify-write. A
		// flexible-content row is not: it also needs its `acf_fc_layout` tag
		// to say which layout it is, and SCF silently drops a row that lacks
		// it -- verified empirically (writing a brand-new flexible-content
		// row through this branch without the tag left the whole field
		// empty on write). A row the target ALREADY has keeps its own
		// `acf_fc_layout` untouched by the three lines above, since only
		// $parts[2] is ever set on it; only a row being created for the
		// first time (a brand-new translation counterpart) has none, so
		// backfill it from the corresponding row on the SOURCE post -- the
		// only other place that still identifies the row's layout, since
		// pllx_acf_walk() deliberately never emits `acf_fc_layout` as a
		// translatable key.
		if ( ! isset( $rows[ $i ]['acf_fc_layout'] ) && $source_id ) {
			$source_rows = get_field( $parts[0], $source_id );
			if ( is_array( $source_rows ) && isset( $source_rows[ $i ]['acf_fc_layout'] ) ) {
				$rows[ $i ]['acf_fc_layout'] = $source_rows[ $i ]['acf_fc_layout'];
			}
		}

		update_field( $parts[0], $rows, $post_id );
	}
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
		parse_str( $parts['query'], $query_args );
		unset( $query_args['p'], $query_args['page_id'], $query_args['attachment_id'] );
		$carry = http_build_query( $query_args );
		if ( '' !== $carry ) {
			$result .= ( false === strpos( $result, '?' ) ? '?' : '&' ) . $carry;
		}
	}
	if ( ! empty( $parts['fragment'] ) ) {
		$result .= '#' . $parts['fragment'];
	}

	return $result;
}

/**
 * Re-point the reference-holding ACF field types on $target_id from
 * $source_id's own field values, translated into $target_lang.
 *
 * Covers `link` (its `url` key -- `title` travels through the manifest and
 * pllx_acf_write() instead), `page_link` (a permalink string), `post_object`
 * and `relationship` (post ids, given SCF/ACF's `return_format => 'id'`;
 * see pll-acf-fixture.php on the test site and SKILL.md for what was
 * actually measured). Only top-level fields are handled, matching
 * pllx_acf_walk()'s one-level ceiling.
 *
 * Derives each value from the SOURCE post every run, but only WRITES it when
 * the target's field is still empty or still holds what this pass last put
 * there (see pllx_ref_may_write()). An earlier version claimed nothing else
 * could give the target a value, which is untrue -- an editor can set any of
 * these in wp-admin, and re-deriving them unconditionally undid that on every
 * import, with no warning. Idempotent either way: each write is compared
 * against the target's current value first, so a second run with no source
 * change makes zero writes.
 *
 * Returns the number of fields actually rewritten.
 */
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
 * Copy every ACF value the pipeline does NOT translate from source to target.
 *
 * pllx_acf_walk() only emits text/textarea/wysiwyg, so images, numbers,
 * booleans, selects, dates and plain urls never reached a new counterpart at
 * all: a freshly created translation came out with its text filled in and
 * everything else blank. pll-lib.php claimed these were "copied verbatim by
 * the importer" -- nothing did the copying.
 *
 * Only fields the target has never had set are copied, so this cannot undo an
 * editorial change, and re-runs write nothing. Reference types are skipped
 * because pllx_repoint_acf_refs() owns them: they need MAPPING to the target
 * language, not a verbatim copy that would point the translation at
 * source-language content.
 *
 * Containers (group, repeater, flexible_content) are copied whole and then
 * overwritten key by key by the manifest's translated values, which also
 * means a first-write row arrives with its structure and its acf_fc_layout
 * tag already intact.
 *
 * Ceiling: an image or file id is copied as-is rather than swapped for its
 * media translation. That matches the documented contract and what the live
 * fixture asserts; mapping media would be a separate decision.
 *
 * Returns the number of fields copied.
 */
function pllx_acf_copy_untranslated( $source_id, $target_id ) {
	$source_objects = get_field_objects( $source_id );
	if ( ! is_array( $source_objects ) ) {
		return 0;
	}

	$translated = array( 'text', 'textarea', 'wysiwyg' );
	$references = array( 'link', 'page_link', 'post_object', 'relationship' );
	$copied     = 0;

	foreach ( $source_objects as $name => $obj ) {
		$type = isset( $obj['type'] ) ? $obj['type'] : '';
		if ( in_array( $type, $translated, true ) || in_array( $type, $references, true ) ) {
			continue;
		}
		// 'clone' is skipped for the same reason pllx_acf_walk() has no branch
		// for it: with group display it is a second object over the SAME
		// underlying meta, so copying it would write the same values twice.
		if ( 'clone' === $type ) {
			continue;
		}
		// metadata_exists(), not an empty() test: false and 0 are legitimate
		// values for true_false and number, and an empty() check would keep
		// overwriting them on every run.
		if ( metadata_exists( 'post', $target_id, $name ) ) {
			continue;
		}
		if ( ! isset( $obj['value'] ) || null === $obj['value'] ) {
			continue;
		}
		update_field( $name, $obj['value'], $target_id );
		$copied++;
	}

	return $copied;
}

function pllx_repoint_acf_refs( $source_id, $target_id, $target_lang ) {
	$source_objects = get_field_objects( $source_id );
	if ( ! is_array( $source_objects ) ) {
		return 0;
	}

	$count = 0;

	foreach ( $source_objects as $name => $obj ) {
		$type = isset( $obj['type'] ) ? $obj['type'] : '';
		$val  = isset( $obj['value'] ) ? $obj['value'] : null;

		if ( 'link' === $type ) {
			if ( ! is_array( $val ) || empty( $val['url'] ) ) {
				continue;
			}
			$new_url = pllx_repoint_internal_url( $val['url'], $target_lang, "post $target_id, field '$name'" );

			$target_val = get_field( $name, $target_id );
			if ( ! is_array( $target_val ) ) {
				$target_val = array();
			}
			$current_url = isset( $target_val['url'] ) ? $target_val['url'] : '';
			if ( $current_url !== $new_url ) {
				if ( ! pllx_ref_may_write( $target_id, $name, $current_url, (string) $val['url'] ) ) {
					pllx_warn( "post $target_id, field '$name': link was changed after the last import; leaving '$current_url' alone" );
					continue;
				}
				$target_val['url'] = $new_url;
				if ( ! isset( $target_val['title'] ) ) {
					$target_val['title'] = '';
				}
				if ( ! isset( $target_val['target'] ) ) {
					$target_val['target'] = '';
				}
				update_field( $name, $target_val, $target_id );
				update_post_meta( $target_id, PLLX_REF_META . $name, $new_url );
				$count++;
			}
			continue;
		}

		if ( 'page_link' === $type ) {
			if ( ! is_string( $val ) || '' === $val ) {
				continue;
			}
			$new_url = pllx_repoint_internal_url( $val, $target_lang, "post $target_id, field '$name'" );
			$current = get_field( $name, $target_id );
			if ( $current !== $new_url ) {
				$current_norm = pllx_ref_norm( $current );
				if ( ! pllx_ref_may_write( $target_id, $name, $current_norm, (string) $val ) ) {
					pllx_warn( "post $target_id, field '$name': page_link was changed after the last import; leaving '$current_norm' alone" );
					continue;
				}
				update_field( $name, $new_url, $target_id );
				update_post_meta( $target_id, PLLX_REF_META . $name, $new_url );
				$count++;
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
				pllx_warn( "post $target_id, field '$name': post_object references post $source_post_id, which has no '$target_lang' counterpart; leaving it pointed at the source" );
				continue;
			}
			$current_id = pllx_acf_ref_id( get_field( $name, $target_id ) );
			if ( $current_id !== $new_id ) {
				$current_norm = $current_id ? (string) $current_id : '';
				if ( ! pllx_ref_may_write( $target_id, $name, $current_norm, (string) $source_post_id ) ) {
					pllx_warn( "post $target_id, field '$name': post_object was changed after the last import; leaving post $current_id alone" );
					continue;
				}
				update_field( $name, $new_id, $target_id );
				update_post_meta( $target_id, PLLX_REF_META . $name, (string) $new_id );
				$count++;
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
					pllx_warn( "post $target_id, field '$name': relationship references post $row_id, which has no '$target_lang' counterpart; leaving that entry pointed at the source" );
					$new_ids[] = $row_id; // leave pointed at the source rather than silently drop it.
					continue;
				}
				$new_ids[] = $mapped;
			}

			$current_ids = array();
			foreach ( (array) get_field( $name, $target_id ) as $row ) {
				$id = pllx_acf_ref_id( $row );
				if ( $id ) {
					$current_ids[] = $id;
				}
			}

			if ( $current_ids !== $new_ids ) {
				$current_norm = implode( ',', $current_ids );
				if ( ! pllx_ref_may_write( $target_id, $name, $current_norm, pllx_ref_norm( $val ) ) ) {
					pllx_warn( "post $target_id, field '$name': relationship was changed after the last import; leaving [$current_norm] alone" );
					continue;
				}
				update_field( $name, $new_ids, $target_id );
				update_post_meta( $target_id, PLLX_REF_META . $name, implode( ',', $new_ids ) );
				$count++;
			}
			continue;
		}
	}

	return $count;
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
 * Store a string translation in Polylang's own option.
 *
 * Polylang keeps string translations in an MO object per language, saved under
 * a post of type `polylang_mo` whose id comes from PLL_MO::get_id().
 */
/**
 * Ceiling, measured rather than guessed: this re-scans
 * PLL_Admin_Strings::get_strings() and does a full PLL_MO import/export round
 * trip per string, so it is O(n^2) in the number of registered strings. On the
 * test site n is 3 and one scan is under a millisecond, which is why it is
 * left alone. If a theme ever registers hundreds of strings, batch the round
 * trip: load the PLL_MO once, add every translation, save once.
 */
function pllx_string_translate( $item_id, $translated, $target ) {
	if ( ! class_exists( 'PLL_MO' ) ) {
		pllx_warn( 'PLL_MO is unavailable; skipping string translations.' );
		return;
	}

	// Recover the source text: the manifest id ends with md5(source), so match
	// against the registered strings rather than trying to reverse the hash.
	$source_text = null;
	if ( class_exists( 'PLL_Admin_Strings' ) ) {
		foreach ( PLL_Admin_Strings::get_strings() as $entry ) {
			$value   = isset( $entry['string'] ) ? $entry['string'] : '';
			$context = isset( $entry['context'] ) ? $entry['context'] : 'polylang';
			if ( 'string:' . $context . ':' . md5( $value ) === $item_id ) {
				$source_text = $value;
				break;
			}
		}
	}

	if ( null === $source_text ) {
		pllx_warn( "Could not match string item '$item_id' back to a registered string; skipping." );
		return;
	}

	$language = PLL()->model->get_language( $target );
	if ( ! $language ) {
		pllx_warn( "Unknown language '$target' while writing a string; skipping." );
		return;
	}

	$mo = new PLL_MO();
	$mo->import_from_db( $language );
	$mo->add_entry( $mo->make_entry( $source_text, $translated ) );
	$mo->export_to_db( $language );
}
