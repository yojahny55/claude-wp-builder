<?php
/**
 * product-seed.php -- create a store's products from a demo or a client's products file.
 *
 * Usage: wp eval-file product-seed.php <project-path> <products-file> [dry-run] [force]
 *   <products-file>  JSON: an object with a `products` list (demo/.yolo-manifest.json, or a
 *                    client's products.json), or the list itself. Relative image paths resolve
 *                    against this file's directory. The entry shape is in product-lib.php.
 *   dry-run          print what would happen, write nothing
 *   force            also overwrite a field the client edited in WooCommerce, on a product this
 *                    script created; never a product it did not create
 *   The flags are bare words: `wp eval-file` refuses a --flag it does not know.
 *
 * Every product is resolved before anything is written, the way /wp-seed resolves its records:
 *   - identity is the sku, or the seed key (`key`, else the name slugified) with no sku;
 *   - a product with that identity carrying `_<prefix>_seeded_content` is this script's: it is
 *     updated field by field against the digests recorded in `_<prefix>_seeded_digest`, so a
 *     field the client edited is left alone;
 *   - a product with that sku, or that exact name, without the marker is the client's: it is
 *     reported and never touched, and no second product is created beside it;
 *   - nothing found: the product is created, marker, key and digests in the same save.
 *
 * One line per product, `<status> <key>[: detail]`:
 *   create / would-create   new product (`: draft, has options Size` when it has options)
 *   update / would-update   fields written: `: regular_price, image`
 *   ok                      already what the source says
 *   conflict                left alone: `: exists without the seed marker`, or a field the
 *                           client edited (`: regular_price edited in WooCommerce`), or a type
 *                           change (`: type is simple, the source says external`)
 *   degraded                written, but part of it could not be: an image that did not import
 *   review                  written, and a person must finish it: options become no variations
 * then, before the summary, an `invalid <name>: <why>` line for every entry refused, and last
 * `products: 2 created, 1 updated, 4 unchanged, 1 conflict, 0 degraded`.
 *
 * Exit 0 when every product was resolved (conflicts and degraded lines allowed). Exit 1 refused,
 * with a `refused:` line, before anything is written: WooCommerce inactive, no readable
 * manifest, no prefix or administrator, an unreadable products file, or any invalid entry.
 *
 * It reads the products file and images from the host's filesystem, so it needs WP-CLI that
 * sees the project's paths (`environment.engine` native), like woo-setup.php. PHP 7.4 floor.
 */

require_once __DIR__ . '/product-lib.php';

function prodseed_refuse( $message ) {
	WP_CLI::line( 'refused: ' . $message );
	WP_CLI::halt( 1 );
}

if ( ! function_exists( 'wc_get_product' ) ) {
	prodseed_refuse( 'WooCommerce is not active; run /wp-woo-setup' );
}

$prodseed_args  = isset( $args ) && is_array( $args ) ? array_values( $args ) : array();
$prodseed_root  = isset( $prodseed_args[0] ) ? rtrim( $prodseed_args[0], '/' ) : '';
$prodseed_file  = isset( $prodseed_args[1] ) ? $prodseed_args[1] : '';
$prodseed_flags = array_slice( $prodseed_args, 2 );
$prodseed_dry   = in_array( 'dry-run', $prodseed_flags, true );
$prodseed_force = in_array( 'force', $prodseed_flags, true );
$prodseed_bad   = array_diff( $prodseed_flags, array( 'dry-run', 'force' ) );
if ( '' === $prodseed_root || '' === $prodseed_file || $prodseed_bad ) {
	prodseed_refuse( 'usage: wp eval-file product-seed.php <project-path> <products-file> [dry-run] [force]' );
}
if ( ! is_readable( $prodseed_root . '/.wp-create.json' ) ) {
	prodseed_refuse( 'no readable .wp-create.json at "' . $prodseed_root . '" (WP-CLI must see the project\'s paths: engine native)' );
}
$prodseed_manifest = json_decode( (string) file_get_contents( $prodseed_root . '/.wp-create.json' ), true );
$prodseed_prefix   = is_array( $prodseed_manifest ) && isset( $prodseed_manifest['project']['prefix'] ) ? rtrim( (string) $prodseed_manifest['project']['prefix'], '_' ) : '';
if ( 1 !== preg_match( '/^[a-z][a-z0-9_]*$/', $prodseed_prefix ) ) {
	prodseed_refuse( '.wp-create.json has no project.prefix to name the seed marker with' );
}
if ( '/' !== substr( $prodseed_file, 0, 1 ) ) {
	$prodseed_file = $prodseed_root . '/' . $prodseed_file;
}
if ( ! is_readable( $prodseed_file ) ) {
	prodseed_refuse( 'no readable products file at "' . $prodseed_file . '"' );
}
$prodseed_json = json_decode( (string) file_get_contents( $prodseed_file ), true );
if ( ! is_array( $prodseed_json ) ) {
	prodseed_refuse( $prodseed_file . ' is not valid JSON' );
}
$prodseed_list = isset( $prodseed_json['products'] ) ? $prodseed_json['products'] : ( array_keys( $prodseed_json ) === range( 0, count( $prodseed_json ) - 1 ) ? $prodseed_json : array() );
if ( ! is_array( $prodseed_list ) ) {
	prodseed_refuse( 'products in ' . $prodseed_file . ' is not a list' );
}
$prodseed_norm = prodseed_normalize_all( $prodseed_list, dirname( $prodseed_file ) );
if ( $prodseed_norm['errors'] ) {
	foreach ( $prodseed_norm['errors'] as $prodseed_error ) {
		WP_CLI::line( 'invalid ' . $prodseed_error );
	}
	prodseed_refuse( count( $prodseed_norm['errors'] ) . ' invalid product(s) in ' . $prodseed_file . '; fix them and run again' );
}
if ( ! $prodseed_norm['entries'] ) {
	WP_CLI::line( 'products: none in ' . $prodseed_file );
	return;
}
$prodseed_admins = get_users(
	array(
		'role'   => 'administrator',
		'number' => 1,
		'fields' => 'ID',
	)
);
if ( ! $prodseed_admins ) {
	prodseed_refuse( 'no administrator to own the products and their images' );
}
$prodseed_author = (int) $prodseed_admins[0];
wp_set_current_user( $prodseed_author );

// `wp eval-file` runs this file inside a function, so its variables are not globals: the meta
// keys the functions below need travel in $GLOBALS.
$prodseed_marker = '_' . $prodseed_prefix . '_seeded_content';
$prodseed_keymk  = '_' . $prodseed_prefix . '_seeded_key';
$prodseed_dgmk   = '_' . $prodseed_prefix . '_seeded_digest';
$GLOBALS['prodseed_meta'] = array(
	'marker' => $prodseed_marker,
	'key'    => $prodseed_keymk,
	'source' => '_' . $prodseed_prefix . '_seeded_source',
);

/** Product ids with a meta value, any status. */
function prodseed_ids_by_meta( $key, $value ) {
	return get_posts(
		array(
			'post_type'      => 'product',
			'post_status'    => 'any',
			'meta_key'       => $key,
			'meta_value'     => $value,
			'fields'         => 'ids',
			'posts_per_page' => -1,
		)
	);
}

/** Resolve an entry: array( 'id' => int, 'ours' => bool ), id 0 when nothing is found. */
function prodseed_resolve( $entry ) {
	global $wpdb;
	$ids = prodseed_ids_by_meta( $GLOBALS['prodseed_meta']['key'], $entry['key'] );
	if ( $ids ) {
		return array(
			'id'   => (int) $ids[0],
			'ours' => (bool) get_post_meta( $ids[0], $GLOBALS['prodseed_meta']['marker'], true ),
		);
	}
	if ( '' !== $entry['sku'] ) {
		$id = (int) wc_get_product_id_by_sku( $entry['sku'] );
		if ( $id > 0 ) {
			return array(
				'id'   => $id,
				'ours' => false,
			);
		}
	}
	$id = (int) $wpdb->get_var( $wpdb->prepare( "SELECT ID FROM {$wpdb->posts} WHERE post_type = 'product' AND post_status NOT IN ('trash', 'auto-draft') AND post_title = %s LIMIT 1", $entry['name'] ) );
	return array(
		'id'   => $id,
		'ours' => false,
	);
}

/** The seed source of an attachment, or `attachment:<id>` for one this script did not import. */
function prodseed_source_of( $attachment_id ) {
	if ( ! $attachment_id ) {
		return '';
	}
	$src = (string) get_post_meta( $attachment_id, $GLOBALS['prodseed_meta']['source'], true );
	return '' !== $src ? $src : 'attachment:' . (int) $attachment_id;
}

/** What WooCommerce holds now, in the entry's shape. */
function prodseed_current( $product ) {
	// WooCommerce files a product with no category under its default one on save: that is not a
	// category anybody chose, so it does not count as an edit.
	$cats    = array();
	$default = (int) get_option( 'default_product_cat', 0 );
	foreach ( $product->get_category_ids( 'edit' ) as $cat_id ) {
		if ( (int) $cat_id === $default ) {
			continue;
		}
		$term = get_term( $cat_id, 'product_cat' );
		if ( $term && ! is_wp_error( $term ) ) {
			$cats[] = $term->name;
		}
	}
	sort( $cats, SORT_STRING );
	$external = $product->is_type( 'external' );
	return array(
		'name'              => $product->get_name( 'edit' ),
		'regular_price'     => (string) $product->get_regular_price( 'edit' ),
		'sale_price'        => (string) $product->get_sale_price( 'edit' ),
		'short_description' => $product->get_short_description( 'edit' ),
		'description'       => $product->get_description( 'edit' ),
		'categories'        => $cats,
		'image'             => prodseed_source_of( (int) $product->get_image_id( 'edit' ) ),
		'gallery'           => array_map( 'prodseed_source_of', array_map( 'intval', $product->get_gallery_image_ids( 'edit' ) ) ),
		'external_url'      => $external ? $product->get_product_url( 'edit' ) : '',
		'button_text'       => $external ? $product->get_button_text( 'edit' ) : '',
	);
}

/**
 * The attachment for an image reference, imported once and found again by its source.
 * Returns array( 'id' => int ) or array( 'error' => why ).
 */
function prodseed_attachment( $ref, $title ) {
	$meta  = $GLOBALS['prodseed_meta'];
	$found = get_posts(
		array(
			'post_type'      => 'attachment',
			'post_status'    => 'any',
			'meta_key'       => $meta['source'],
			'meta_value'     => $ref,
			'fields'         => 'ids',
			'posts_per_page' => 1,
		)
	);
	if ( $found ) {
		return array( 'id' => (int) $found[0] );
	}
	require_once ABSPATH . 'wp-admin/includes/file.php';
	require_once ABSPATH . 'wp-admin/includes/media.php';
	require_once ABSPATH . 'wp-admin/includes/image.php';
	if ( 1 === preg_match( '#^https?://#i', $ref ) ) {
		$tmp = download_url( $ref );
		if ( is_wp_error( $tmp ) ) {
			return array( 'error' => $tmp->get_error_message() );
		}
		$name = basename( (string) wp_parse_url( $ref, PHP_URL_PATH ) );
	} else {
		if ( ! is_readable( $ref ) ) {
			return array( 'error' => 'no readable file' );
		}
		// media_handle_sideload() moves the file: give it a copy, never the demo's own.
		$tmp = wp_tempnam( basename( $ref ) );
		if ( ! $tmp || ! copy( $ref, $tmp ) ) {
			return array( 'error' => 'could not copy it to a temporary file' );
		}
		$name = basename( $ref );
	}
	$id = media_handle_sideload(
		array(
			'name'     => '' !== $name ? $name : 'product-image',
			'tmp_name' => $tmp,
		),
		0,
		$title
	);
	if ( is_wp_error( $id ) ) {
		if ( file_exists( $tmp ) ) {
			wp_delete_file( $tmp );
		}
		return array( 'error' => $id->get_error_message() );
	}
	update_post_meta( $id, $meta['marker'], 1 );
	update_post_meta( $id, $meta['source'], $ref );
	return array( 'id' => (int) $id );
}

/** Category ids for names, created when missing. */
function prodseed_category_ids( $names ) {
	$ids = array();
	foreach ( $names as $name ) {
		$term = get_term_by( 'name', $name, 'product_cat' );
		if ( ! $term ) {
			$made = wp_insert_term( $name, 'product_cat' );
			if ( is_wp_error( $made ) ) {
				$existing = $made->get_error_data( 'term_exists' );
				if ( ! $existing ) {
					continue;
				}
				$ids[] = (int) $existing;
				continue;
			}
			$ids[] = (int) $made['term_id'];
			continue;
		}
		$ids[] = (int) $term->term_id;
	}
	return $ids;
}

/**
 * Write one field to the product. Returns the value now held (what the digest records): for an
 * image that did not import, the value before, so the next run tries again.
 */
function prodseed_apply( $product, $field, $entry, &$problems ) {
	switch ( $field ) {
		case 'name':
			$product->set_name( $entry['name'] );
			break;
		case 'regular_price':
			$product->set_regular_price( $entry['regular_price'] );
			break;
		case 'sale_price':
			$product->set_sale_price( $entry['sale_price'] );
			break;
		case 'short_description':
			$product->set_short_description( $entry['short_description'] );
			break;
		case 'description':
			$product->set_description( $entry['description'] );
			break;
		case 'categories':
			$product->set_category_ids( prodseed_category_ids( $entry['categories'] ) );
			break;
		case 'image':
			if ( '' === $entry['image'] ) {
				$product->set_image_id( 0 );
				break;
			}
			$got = prodseed_attachment( $entry['image'], $entry['name'] );
			if ( isset( $got['error'] ) ) {
				$problems[] = 'image ' . $entry['image'] . ' did not import (' . $got['error'] . ')';
				return prodseed_source_of( (int) $product->get_image_id( 'edit' ) );
			}
			$product->set_image_id( $got['id'] );
			break;
		case 'gallery':
			$ids  = array();
			$held = array();
			foreach ( $entry['gallery'] as $ref ) {
				$got = prodseed_attachment( $ref, $entry['name'] );
				if ( isset( $got['error'] ) ) {
					$problems[] = 'gallery image ' . $ref . ' did not import (' . $got['error'] . ')';
					continue;
				}
				$ids[]  = $got['id'];
				$held[] = $ref;
			}
			$product->set_gallery_image_ids( $ids );
			return $held;
		case 'external_url':
			if ( $product->is_type( 'external' ) ) {
				$product->set_product_url( $entry['external_url'] );
			}
			break;
		case 'button_text':
			if ( $product->is_type( 'external' ) ) {
				$product->set_button_text( $entry['button_text'] );
			}
			break;
	}
	return $entry[ $field ];
}

$prodseed_count = array(
	'created'   => 0,
	'updated'   => 0,
	'unchanged' => 0,
	'conflict'  => 0,
	'degraded'  => 0,
);

foreach ( $prodseed_norm['entries'] as $prodseed_entry ) {
	$prodseed_key = $prodseed_entry['key'];
	$prodseed_at  = prodseed_resolve( $prodseed_entry );

	if ( $prodseed_at['id'] > 0 && ! $prodseed_at['ours'] ) {
		WP_CLI::line( 'conflict ' . $prodseed_key . ': exists without the seed marker (product ' . $prodseed_at['id'] . '); left alone' );
		++$prodseed_count['conflict'];
		continue;
	}

	if ( 0 === $prodseed_at['id'] ) {
		$prodseed_note = $prodseed_entry['has_options'] ? ': draft, has options ' . implode( ', ', $prodseed_entry['options'] ) : '';
		if ( $prodseed_dry ) {
			WP_CLI::line( 'would-create ' . $prodseed_key . $prodseed_note );
			++$prodseed_count['created'];
			continue;
		}
		$prodseed_product = 'external' === $prodseed_entry['type'] ? new WC_Product_External() : new WC_Product_Simple();
		$prodseed_product->set_status( $prodseed_entry['has_options'] ? 'draft' : 'publish' );
		if ( '' !== $prodseed_entry['sku'] ) {
			try {
				$prodseed_product->set_sku( $prodseed_entry['sku'] );
			} catch ( WC_Data_Exception $prodseed_e ) {
				WP_CLI::line( 'conflict ' . $prodseed_key . ': ' . $prodseed_e->getMessage() . '; left alone' );
				++$prodseed_count['conflict'];
				continue;
			}
		}
		$prodseed_problems = array();
		$prodseed_digests  = array();
		foreach ( prodseed_fields() as $prodseed_field ) {
			$prodseed_digests[ $prodseed_field ] = prodseed_digest( prodseed_apply( $prodseed_product, $prodseed_field, $prodseed_entry, $prodseed_problems ) );
		}
		// Marker, identity and digests go in the same save as the product: a product saved
		// without them could never be recognised again, and the next run would leave it alone.
		$prodseed_product->update_meta_data( $prodseed_marker, 1 );
		$prodseed_product->update_meta_data( $prodseed_keymk, $prodseed_key );
		$prodseed_product->update_meta_data( $prodseed_dgmk, $prodseed_digests );
		// The author is the current user, set to the administrator above.
		$prodseed_id = $prodseed_product->save();
		WP_CLI::line( 'create ' . $prodseed_key . ': product ' . $prodseed_id . ( '' !== $prodseed_note ? ', ' . substr( $prodseed_note, 2 ) : '' ) );
		++$prodseed_count['created'];
		if ( $prodseed_problems ) {
			WP_CLI::line( 'degraded ' . $prodseed_key . ': ' . implode( '; ', $prodseed_problems ) );
			++$prodseed_count['degraded'];
		}
		if ( $prodseed_entry['has_options'] ) {
			WP_CLI::line( 'review ' . $prodseed_key . ': options ' . implode( ', ', $prodseed_entry['options'] ) . ' are not built as variations; the product stays a draft until they are' );
		}
		continue;
	}

	$prodseed_product = wc_get_product( $prodseed_at['id'] );
	if ( ! $prodseed_product ) {
		WP_CLI::line( 'conflict ' . $prodseed_key . ': product ' . $prodseed_at['id'] . ' could not be loaded; left alone' );
		++$prodseed_count['conflict'];
		continue;
	}
	$prodseed_type = $prodseed_product->get_type();
	if ( $prodseed_type !== $prodseed_entry['type'] ) {
		WP_CLI::line( 'conflict ' . $prodseed_key . ': type is ' . $prodseed_type . ', the source says ' . $prodseed_entry['type'] . '; change it in WooCommerce' );
		++$prodseed_count['conflict'];
		continue;
	}
	$prodseed_last = $prodseed_product->get_meta( $prodseed_dgmk, true, 'edit' );
	$prodseed_last = is_array( $prodseed_last ) ? $prodseed_last : array();
	$prodseed_now  = prodseed_current( $prodseed_product );
	$prodseed_upd  = array();
	$prodseed_conf = array();
	$prodseed_dig  = $prodseed_last;
	foreach ( prodseed_fields() as $prodseed_field ) {
		$prodseed_was = isset( $prodseed_last[ $prodseed_field ] ) ? $prodseed_last[ $prodseed_field ] : null;
		$prodseed_dec = prodseed_decide( $prodseed_now[ $prodseed_field ], $prodseed_was, $prodseed_entry[ $prodseed_field ], $prodseed_force );
		if ( 'update' === $prodseed_dec ) {
			$prodseed_upd[] = $prodseed_field;
		} elseif ( 'conflict' === $prodseed_dec ) {
			$prodseed_conf[] = $prodseed_field;
		} else {
			$prodseed_dig[ $prodseed_field ] = prodseed_digest( $prodseed_entry[ $prodseed_field ] );
		}
	}
	if ( $prodseed_conf ) {
		WP_CLI::line( 'conflict ' . $prodseed_key . ': ' . implode( ', ', $prodseed_conf ) . ' edited in WooCommerce; left alone (force overwrites)' );
		++$prodseed_count['conflict'];
	}
	if ( ! $prodseed_upd ) {
		if ( ! $prodseed_conf ) {
			WP_CLI::line( 'ok ' . $prodseed_key );
			++$prodseed_count['unchanged'];
		}
		if ( ! $prodseed_dry && $prodseed_dig !== $prodseed_last ) {
			$prodseed_product->update_meta_data( $prodseed_dgmk, $prodseed_dig );
			$prodseed_product->save();
		}
		continue;
	}
	if ( $prodseed_dry ) {
		WP_CLI::line( 'would-update ' . $prodseed_key . ': ' . implode( ', ', $prodseed_upd ) );
		++$prodseed_count['updated'];
		continue;
	}
	$prodseed_problems = array();
	foreach ( $prodseed_upd as $prodseed_field ) {
		$prodseed_dig[ $prodseed_field ] = prodseed_digest( prodseed_apply( $prodseed_product, $prodseed_field, $prodseed_entry, $prodseed_problems ) );
	}
	$prodseed_product->update_meta_data( $prodseed_dgmk, $prodseed_dig );
	$prodseed_product->save();
	WP_CLI::line( 'update ' . $prodseed_key . ': ' . implode( ', ', $prodseed_upd ) );
	++$prodseed_count['updated'];
	if ( $prodseed_problems ) {
		WP_CLI::line( 'degraded ' . $prodseed_key . ': ' . implode( '; ', $prodseed_problems ) );
		++$prodseed_count['degraded'];
	}
}

WP_CLI::line(
	sprintf(
		'products: %d %s, %d %s, %d unchanged, %d conflict, %d degraded',
		$prodseed_count['created'],
		$prodseed_dry ? 'to create' : 'created',
		$prodseed_count['updated'],
		$prodseed_dry ? 'to update' : 'updated',
		$prodseed_count['unchanged'],
		$prodseed_count['conflict'],
		$prodseed_count['degraded']
	)
);
