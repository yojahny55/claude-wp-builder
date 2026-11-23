<?php
/**
 * webp-migrate.php -- convert a library's PNG attachments to WebP in place, the procedure in
 * skills/wp-robin/references/png-to-webp-conversion.md as a script. Run by /wp-webp migrate,
 * never by hand. PHP 7.4 floor.
 *
 * Usage: $WP eval-file webp-migrate.php <action> <workdir> [dry-run] [limit=N] [backup=<dir>]
 *
 * <workdir> is a folder outside the WordPress root. It holds map.tsv (old file, new file,
 * attachment ID; uploads-relative) and in-progress.json while an attachment is being
 * converted. Actions, in the order the command runs them:
 *
 *   plan        counts PNG attachments and their bytes; says whether WebP can be written
 *   convert     each image/png attachment, one at a time: <name>.webp (or <name>-png.webp on a
 *               clash) from the unscaled original at quality 90, attached file, mime type and
 *               sizes regenerated without deleting the old ones, map rows appended.
 *               Idempotent: it selects image/png only, so a second run resumes.
 *   replace     every text column of the prefixed tables: each uploads/<old> in the map, plain
 *               or with JSON-escaped slashes, becomes uploads/<new>; serialized values are
 *               unserialized, replaced and serialized again. Skips posts.guid, Robin's queue,
 *               transients and sessions.
 *   verify      every new file exists and no row still names an old one. Exit 1 otherwise.
 *   move-aside  verify again, then move every old file (and Robin's <file>.png.webp sibling)
 *               to backup=<dir>, outside uploads. Nothing is deleted.
 *
 * Every action takes dry-run. Output is one JSON object per line; the last is the summary.
 */

defined( 'ABSPATH' ) || exit;

$wm_args   = isset( $args ) && is_array( $args ) ? $args : array();
$wm_action = isset( $wm_args[0] ) ? (string) $wm_args[0] : '';
$wm_work   = isset( $wm_args[1] ) ? rtrim( (string) $wm_args[1], '/' ) : '';
$wm_dry    = in_array( 'dry-run', $wm_args, true );
$wm_limit  = 0;
$wm_backup = '';
foreach ( $wm_args as $a ) {
	if ( 0 === strpos( $a, 'limit=' ) ) {
		$wm_limit = max( 0, (int) substr( $a, 6 ) );
	}
	if ( 0 === strpos( $a, 'backup=' ) ) {
		$wm_backup = rtrim( substr( $a, 7 ), '/' );
	}
}

$wm_actions = array( 'plan', 'convert', 'replace', 'verify', 'move-aside' );
if ( ! in_array( $wm_action, $wm_actions, true ) || '' === $wm_work ) {
	WP_CLI::error( 'usage: webp-migrate.php <' . implode( '|', $wm_actions ) . '> <workdir> [dry-run] [limit=N] [backup=<dir>]' );
}

$wm_uploads = wp_upload_dir( null, false );
$wm_base    = rtrim( $wm_uploads['basedir'], '/' );
if ( wp_is_stream( $wm_base ) ) {
	WP_CLI::error( 'webp-migrate: uploads live behind a stream wrapper (' . $wm_base . '); convert on a local copy of the library, not through the bucket' );
}

/**
 * Whether $path is $dir or under it, after resolving what exists of it.
 */
function webp_migrate_inside( $path, $dir ) {
	$real_dir = realpath( $dir );
	$probe    = $path;
	while ( ! file_exists( $probe ) && dirname( $probe ) !== $probe ) {
		$probe = dirname( $probe );
	}
	$real = realpath( $probe );
	if ( false === $real_dir || false === $real ) {
		return false;
	}
	return $real === $real_dir || 0 === strpos( $real . '/', rtrim( $real_dir, '/' ) . '/' );
}

if ( webp_migrate_inside( $wm_work, ABSPATH ) || webp_migrate_inside( $wm_work, $wm_base ) ) {
	WP_CLI::error( 'webp-migrate: the workdir must be outside the WordPress root and uploads' );
}
if ( ! $wm_dry && ! is_dir( $wm_work ) && ! wp_mkdir_p( $wm_work ) ) {
	WP_CLI::error( 'webp-migrate: cannot create the workdir ' . $wm_work );
}
$wm_map_file = $wm_work . '/map.tsv';
$wm_progress = $wm_work . '/in-progress.json';

function webp_migrate_out( $row ) {
	echo wp_json_encode( $row ) . "\n";
}

/**
 * The map: old uploads-relative path => new one.
 *
 * @return array<string,string>
 */
function webp_migrate_load_map( $file ) {
	$map = array();
	if ( ! is_readable( $file ) ) {
		return $map;
	}
	foreach ( file( $file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES ) as $line ) {
		$cols = explode( "\t", $line );
		if ( count( $cols ) >= 2 && '' !== $cols[0] && '' !== $cols[1] ) {
			$map[ $cols[0] ] = $cols[1];
		}
	}
	return $map;
}

/**
 * Old files of one attachment, by role, uploads-relative, read from its metadata before it changes.
 */
function webp_migrate_old_files( $id, $meta, $attached ) {
	$files = array( 'attached' => $attached );
	if ( ! empty( $meta['file'] ) ) {
		$files['file'] = $meta['file'];
	}
	$dir = ( ! empty( $meta['file'] ) && false !== strpos( $meta['file'], '/' ) ) ? dirname( $meta['file'] ) . '/' : '';
	if ( ! empty( $meta['original_image'] ) ) {
		$files['original'] = $dir . $meta['original_image'];
	}
	if ( ! empty( $meta['sizes'] ) && is_array( $meta['sizes'] ) ) {
		foreach ( $meta['sizes'] as $name => $size ) {
			if ( ! empty( $size['file'] ) ) {
				$files[ 'size:' . $name ] = $dir . $size['file'];
			}
		}
	}
	return $files;
}

/**
 * Old file => new file for one converted attachment. A size the new image no longer has (it is
 * smaller than that size) maps to the new full image, so its old URL still lands on a picture.
 */
function webp_migrate_rows( $old, $new_meta, $new_attached ) {
	$dir  = ( ! empty( $new_meta['file'] ) && false !== strpos( $new_meta['file'], '/' ) ) ? dirname( $new_meta['file'] ) . '/' : '';
	$full = ! empty( $new_meta['file'] ) ? $new_meta['file'] : $new_attached;
	$orig = ! empty( $new_meta['original_image'] ) ? $dir . $new_meta['original_image'] : $full;
	$rows = array();
	foreach ( $old as $role => $path ) {
		if ( 'attached' === $role ) {
			$rows[ $path ] = $new_attached;
		} elseif ( 'file' === $role ) {
			$rows[ $path ] = $full;
		} elseif ( 'original' === $role ) {
			$rows[ $path ] = $orig;
		} else {
			$name          = substr( $role, 5 );
			$rows[ $path ] = isset( $new_meta['sizes'][ $name ]['file'] ) ? $dir . $new_meta['sizes'][ $name ]['file'] : $full;
		}
	}
	return $rows;
}

/**
 * Replace every uploads/<old> in a string, plain or JSON-escaped. A match must end the file
 * name: uploads/x.png inside uploads/x.png.webp (Robin's sibling) is not a match.
 */
function webp_migrate_replace_string( $value, $map, &$hits ) {
	return preg_replace_callback(
		'~uploads(\\\\?/)((?:[^"\'\s<>()\\\\]|\\\\/)+?\.png)(?![\w.-])~i',
		function ( $m ) use ( $map, &$hits ) {
			$escaped = '\\/' === $m[1];
			$rel     = str_replace( '\\/', '/', $m[2] );
			if ( ! isset( $map[ $rel ] ) ) {
				return $m[0];
			}
			$hits++;
			$new = $map[ $rel ];
			return 'uploads' . $m[1] . ( $escaped ? str_replace( '/', '\\/', $new ) : $new );
		},
		$value
	);
}

function webp_migrate_replace_value( $value, $map, &$hits ) {
	if ( is_string( $value ) ) {
		return webp_migrate_replace_string( $value, $map, $hits );
	}
	if ( is_array( $value ) ) {
		foreach ( $value as $k => $v ) {
			$value[ $k ] = webp_migrate_replace_value( $v, $map, $hits );
		}
		return $value;
	}
	if ( is_object( $value ) && ! ( $value instanceof __PHP_Incomplete_Class ) ) {
		foreach ( get_object_vars( $value ) as $k => $v ) {
			$value->$k = webp_migrate_replace_value( $v, $map, $hits );
		}
	}
	return $value;
}

/**
 * One database value: serialized data is unserialized, replaced and serialized again so every
 * string length stays right. Returns the new value, or null when nothing in it changes.
 */
function webp_migrate_replace_cell( $raw, $map ) {
	$hits = 0;
	if ( is_serialized( $raw ) ) {
		$data = @unserialize( $raw, array( 'allowed_classes' => false ) );
		if ( false === $data && 'b:0;' !== $raw ) {
			return null; // unreadable serialization: leave it, never rewrite it as a string
		}
		$new = serialize( webp_migrate_replace_value( $data, $map, $hits ) );
	} else {
		$new = webp_migrate_replace_string( $raw, $map, $hits );
	}
	return ( $hits > 0 && $new !== $raw ) ? $new : null;
}

/**
 * Walk every text column of the prefixed tables. Returns [ rows changed (or to change), cells ].
 */
function webp_migrate_replace_all( $map, $dry ) {
	global $wpdb;
	$like   = $wpdb->esc_like( $wpdb->prefix ) . '%';
	$cols   = $wpdb->get_results( $wpdb->prepare(
		"SELECT TABLE_NAME AS t, COLUMN_NAME AS c FROM information_schema.COLUMNS
		 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME LIKE %s
		 AND DATA_TYPE IN ('char','varchar','tinytext','text','mediumtext','longtext')",
		$like
	) );
	$total = 0;
	$per   = array();
	foreach ( $cols as $col ) {
		$t = $col->t;
		$c = $col->c;
		if ( ( $t === $wpdb->posts && 'guid' === $c ) || preg_match( '/(rio_process_queue|_sessions)$/', $t ) ) {
			continue;
		}
		$pk = $wpdb->get_col( "SHOW KEYS FROM `$t` WHERE Key_name = 'PRIMARY'", 4 );
		if ( 1 !== count( $pk ) ) {
			webp_migrate_out( array( 'skipped_table' => $t, 'reason' => 'no single-column primary key' ) );
			continue;
		}
		$pk    = $pk[0];
		$where = "`$c` LIKE '%.png%'";
		if ( $t === $wpdb->options && 'option_value' === $c ) {
			$where .= " AND option_name NOT LIKE '\\_transient\\_%' AND option_name NOT LIKE '\\_site\\_transient\\_%'";
		}
		$last = null;
		do {
			$sql  = "SELECT `$pk` AS k, `$c` AS v FROM `$t` WHERE $where" . ( null === $last ? '' : $wpdb->prepare( " AND `$pk` > %s", $last ) ) . " ORDER BY `$pk` LIMIT 500";
			$rows = $wpdb->get_results( $sql );
			foreach ( $rows as $row ) {
				$last = $row->k;
				$new  = webp_migrate_replace_cell( (string) $row->v, $map );
				if ( null === $new ) {
					continue;
				}
				$total++;
				$per[ "$t.$c" ] = isset( $per[ "$t.$c" ] ) ? $per[ "$t.$c" ] + 1 : 1;
				if ( ! $dry ) {
					$wpdb->update( $t, array( $c => $new ), array( $pk => $row->k ) );
				}
			}
		} while ( count( $rows ) === 500 );
	}
	if ( ! $dry && $total ) {
		wp_cache_flush();
	}
	return array( $total, $per );
}

/**
 * New files the map names that are not on disk.
 */
function webp_migrate_missing( $map, $base ) {
	$missing = array();
	foreach ( array_unique( array_values( $map ) ) as $rel ) {
		if ( ! file_exists( $base . '/' . $rel ) ) {
			$missing[] = $rel;
		}
	}
	return $missing;
}

switch ( $wm_action ) {
	case 'plan':
		global $wpdb;
		$ids   = $wpdb->get_col( "SELECT ID FROM {$wpdb->posts} WHERE post_type = 'attachment' AND post_mime_type = 'image/png'" );
		$bytes = 0;
		foreach ( $ids as $id ) {
			$p = wp_get_original_image_path( (int) $id );
			if ( $p && file_exists( $p ) ) {
				$bytes += (int) filesize( $p );
			}
		}
		webp_migrate_out( array(
			'png_attachments' => count( $ids ),
			'original_bytes'  => $bytes,
			'webp_editor'     => wp_image_editor_supports( array( 'mime_type' => 'image/webp' ) ),
			'in_progress'     => file_exists( $wm_progress ),
			'mapped_files'    => count( webp_migrate_load_map( $wm_map_file ) ),
		) );
		break;

	case 'convert':
		if ( file_exists( $wm_progress ) ) {
			WP_CLI::error( 'webp-migrate: ' . $wm_progress . ' exists, so a run stopped halfway through one attachment. Repair it first (png-to-webp-conversion.md, Traps), then delete the file.' );
		}
		if ( ! wp_image_editor_supports( array( 'mime_type' => 'image/webp' ) ) ) {
			WP_CLI::error( 'webp-migrate: no image editor can write WebP' );
		}
		require_once ABSPATH . 'wp-admin/includes/image.php';
		global $wpdb;
		$ids = $wpdb->get_col( "SELECT ID FROM {$wpdb->posts} WHERE post_type = 'attachment' AND post_mime_type = 'image/png' ORDER BY ID" );
		if ( $wm_limit ) {
			$ids = array_slice( $ids, 0, $wm_limit );
		}
		// Robin would queue every size this run writes; off for the run, restored after.
		$robin_key = 'wbcr_io_auto_optimize_when_upload';
		$robin_old = get_option( $robin_key, null );
		if ( ! $wm_dry && null !== $robin_old ) {
			update_option( $robin_key, 0 );
		}
		$done   = 0;
		$failed = 0;
		try {
			foreach ( $ids as $id ) {
				$id       = (int) $id;
				$meta     = wp_get_attachment_metadata( $id );
				$attached = (string) get_post_meta( $id, '_wp_attached_file', true );
				$src      = wp_get_original_image_path( $id );
				if ( ! is_array( $meta ) || '' === $attached || ! $src || ! file_exists( $src ) ) {
					webp_migrate_out( array( 'id' => $id, 'action' => 'skipped', 'reason' => 'no metadata or no original on disk' ) );
					$failed++;
					continue;
				}
				$dir    = dirname( $src );
				$name   = pathinfo( $src, PATHINFO_FILENAME );
				$target = $dir . '/' . $name . '.webp';
				if ( file_exists( $target ) ) {
					$target = $dir . '/' . $name . '-png.webp';
				}
				if ( file_exists( $target ) ) {
					webp_migrate_out( array( 'id' => $id, 'action' => 'skipped', 'reason' => 'both ' . $name . '.webp and ' . $name . '-png.webp exist' ) );
					$failed++;
					continue;
				}
				$old = webp_migrate_old_files( $id, $meta, $attached );
				if ( $wm_dry ) {
					webp_migrate_out( array( 'id' => $id, 'action' => 'would-convert', 'target' => basename( $target ), 'old_files' => count( $old ) ) );
					continue;
				}

				$editor = wp_get_image_editor( $src );
				if ( is_wp_error( $editor ) ) {
					webp_migrate_out( array( 'id' => $id, 'action' => 'skipped', 'reason' => $editor->get_error_message() ) );
					$failed++;
					continue;
				}
				$editor->set_quality( 90 );
				$saved = $editor->save( $target, 'image/webp' );
				if ( is_wp_error( $saved ) || ! file_exists( $target ) ) {
					webp_migrate_out( array( 'id' => $id, 'action' => 'skipped', 'reason' => is_wp_error( $saved ) ? $saved->get_error_message() : 'nothing written' ) );
					$failed++;
					continue;
				}

				// From here the attachment is half done until its map rows are written.
				file_put_contents( $wm_progress, wp_json_encode( array( 'id' => $id, 'attached' => $attached, 'meta' => $meta ) ) );
				update_attached_file( $id, $target );
				$wpdb->update( $wpdb->posts, array( 'post_mime_type' => 'image/webp' ), array( 'ID' => $id ) );
				clean_post_cache( $id );
				$new_meta = wp_create_image_subsizes( $target, $id );
				$new_rel  = (string) get_post_meta( $id, '_wp_attached_file', true );
				$lines    = '';
				foreach ( webp_migrate_rows( $old, is_array( $new_meta ) ? $new_meta : array(), $new_rel ) as $from => $to ) {
					if ( $from !== $to ) {
						$lines .= $from . "\t" . $to . "\t" . $id . "\n";
					}
				}
				file_put_contents( $wm_map_file, $lines, FILE_APPEND | LOCK_EX );
				unlink( $wm_progress );
				webp_migrate_out( array( 'id' => $id, 'action' => 'converted', 'file' => $new_rel, 'sizes' => isset( $new_meta['sizes'] ) ? count( $new_meta['sizes'] ) : 0 ) );
				$done++;
			}
		} finally {
			if ( ! $wm_dry && null !== $robin_old ) {
				update_option( $robin_key, $robin_old );
			}
		}
		webp_migrate_out( array( 'summary' => 'convert', 'converted' => $done, 'skipped' => $failed, 'remaining_png' => (int) $wpdb->get_var( "SELECT COUNT(*) FROM {$wpdb->posts} WHERE post_type = 'attachment' AND post_mime_type = 'image/png'" ), 'dry_run' => $wm_dry ) );
		if ( $failed ) {
			WP_CLI::halt( 1 );
		}
		break;

	case 'replace':
		$map = webp_migrate_load_map( $wm_map_file );
		if ( ! $map ) {
			WP_CLI::error( 'webp-migrate: the map is empty; run convert first' );
		}
		list( $total, $per ) = webp_migrate_replace_all( $map, $wm_dry );
		webp_migrate_out( array( 'summary' => 'replace', 'rows' => $total, 'columns' => $per, 'dry_run' => $wm_dry ) );
		break;

	case 'verify':
	case 'move-aside':
		$map = webp_migrate_load_map( $wm_map_file );
		if ( ! $map ) {
			WP_CLI::error( 'webp-migrate: the map is empty; run convert first' );
		}
		$missing        = webp_migrate_missing( $map, $wm_base );
		list( $refs, $per ) = webp_migrate_replace_all( $map, true );
		$ok             = ! $missing && 0 === $refs && ! file_exists( $wm_progress );
		webp_migrate_out( array( 'summary' => 'verify', 'ok' => $ok, 'missing_new' => array_slice( $missing, 0, 20 ), 'missing_count' => count( $missing ), 'rows_still_naming_old' => $refs, 'columns' => $per, 'in_progress' => file_exists( $wm_progress ) ) );
		if ( ! $ok ) {
			WP_CLI::halt( 1 );
		}
		if ( 'verify' === $wm_action ) {
			break;
		}
		if ( '' === $wm_backup ) {
			WP_CLI::error( 'webp-migrate: move-aside needs backup=<dir>' );
		}
		if ( webp_migrate_inside( $wm_backup, $wm_base ) || webp_migrate_inside( $wm_backup, ABSPATH ) ) {
			WP_CLI::error( 'webp-migrate: the backup folder must be outside uploads and the WordPress root' );
		}
		$new_files = array_flip( array_values( $map ) );
		$moved     = 0;
		$bytes     = 0;
		foreach ( array_keys( $map ) as $rel ) {
			foreach ( array( $rel, $rel . '.webp' ) as $f ) {
				if ( isset( $new_files[ $f ] ) || ! file_exists( $wm_base . '/' . $f ) ) {
					continue;
				}
				$bytes += (int) filesize( $wm_base . '/' . $f );
				if ( ! $wm_dry ) {
					$dest = $wm_backup . '/' . $f;
					wp_mkdir_p( dirname( $dest ) );
					if ( ! rename( $wm_base . '/' . $f, $dest ) ) {
						WP_CLI::error( 'webp-migrate: could not move ' . $f );
					}
				}
				$moved++;
			}
		}
		webp_migrate_out( array( 'summary' => 'move-aside', 'moved' => $moved, 'bytes' => $bytes, 'backup' => $wm_backup, 'dry_run' => $wm_dry ) );
		break;
}
