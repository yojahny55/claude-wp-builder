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
// References are matched as `uploads/<path relative to basedir>`: true on a single site whose
// uploads URL ends in /uploads. Anything else would match nothing and let verify pass.
$wm_url_path = (string) wp_parse_url( $wm_uploads['baseurl'], PHP_URL_PATH );
if ( is_multisite() || 'uploads' !== basename( untrailingslashit( $wm_url_path ) ) ) {
	WP_CLI::error( 'webp-migrate: only a single site whose uploads URL ends in /uploads is supported (this one: ' . $wm_url_path . ')' );
}
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

const WEBP_MIGRATE_PATTERN = '~uploads(\\\\?/)((?:[^"\'\s<>()\\\\]|\\\\/)+?\.png)(?![\w.-])~i';

/**
 * Replace every uploads/<old> in a string, plain or JSON-escaped. A match must end the file
 * name: uploads/x.png inside uploads/x.png.webp (Robin's sibling) is not a match. Returns null
 * when PCRE fails, so the caller leaves the value alone instead of writing a lost one.
 */
function webp_migrate_replace_string( $value, $map, &$hits ) {
	$result = preg_replace_callback(
		WEBP_MIGRATE_PATTERN,
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
	return null === $result ? null : $result;
}

/**
 * Walk a decoded value. Strings that are themselves serialized (double serialization) are
 * decoded and re-encoded in turn, so their inner lengths stay right. Any object, any string
 * that will not decode, and any PCRE failure sets $unsafe: the caller then writes nothing.
 */
function webp_migrate_replace_value( $value, $map, &$hits, &$unsafe ) {
	if ( is_string( $value ) ) {
		if ( is_serialized( $value ) ) {
			$inner = @unserialize( $value, array( 'allowed_classes' => false ) );
			if ( false === $inner && 'b:0;' !== $value ) {
				$unsafe = true;
				return $value;
			}
			$before = $hits;
			$inner  = webp_migrate_replace_value( $inner, $map, $hits, $unsafe );
			return $hits > $before ? serialize( $inner ) : $value;
		}
		$r = webp_migrate_replace_string( $value, $map, $hits );
		if ( null === $r ) {
			$unsafe = true;
			return $value;
		}
		return $r;
	}
	if ( is_array( $value ) ) {
		foreach ( $value as $k => $v ) {
			$value[ $k ] = webp_migrate_replace_value( $v, $map, $hits, $unsafe );
		}
		return $value;
	}
	if ( is_object( $value ) ) {
		// Decoded without its class (allowed_classes false): serializing it again could drop
		// what a Serializable class kept in its own format. Never rewrite a value holding one.
		$unsafe = true;
	}
	return $value;
}

/**
 * One database value. Returns [ new value or null when nothing changes, unresolved ]:
 * unresolved means the value names an old file but cannot be rewritten safely (a broken or
 * object-holding serialization, a PCRE failure). It is left as it is and reported, and verify,
 * which reads the raw value, keeps failing until someone fixes it by hand.
 */
function webp_migrate_replace_cell( $raw, $map ) {
	$hits   = 0;
	$unsafe = false;
	if ( is_serialized( $raw ) ) {
		$data = @unserialize( $raw, array( 'allowed_classes' => false ) );
		if ( false === $data && 'b:0;' !== $raw ) {
			$unsafe = true;
			$new    = $raw;
		} else {
			$new = serialize( webp_migrate_replace_value( $data, $map, $hits, $unsafe ) );
		}
	} else {
		$new = webp_migrate_replace_value( $raw, $map, $hits, $unsafe );
	}
	if ( $unsafe ) {
		static $patterns = null;
		if ( null === $patterns ) {
			$patterns = webp_migrate_verify_patterns( $map );
		}
		return array( null, webp_migrate_names_old( $raw, $patterns ) );
	}
	return array( ( $hits > 0 && $new !== $raw ) ? $new : null, false );
}

/**
 * The text columns this procedure reads: every char/text column of the prefixed tables, less
 * posts.guid, Robin's queue and session tables. Each entry: table, column, primary key (or ''
 * when the table has no single-column one), and the extra WHERE for options (no transients).
 */
function webp_migrate_columns() {
	global $wpdb;
	$cols = $wpdb->get_results( $wpdb->prepare(
		"SELECT TABLE_NAME AS t, COLUMN_NAME AS c FROM information_schema.COLUMNS
		 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME LIKE %s
		 AND DATA_TYPE IN ('char','varchar','tinytext','text','mediumtext','longtext')",
		$wpdb->esc_like( $wpdb->prefix ) . '%'
	) );
	webp_migrate_db_ok( 'information_schema' );
	if ( ! $cols ) {
		WP_CLI::error( 'webp-migrate: found no text columns in the prefixed tables; refusing to report a clean database' );
	}
	$pks = array();
	$out = array();
	foreach ( $cols as $col ) {
		$t = $col->t;
		$c = $col->c;
		if ( ( $t === $wpdb->posts && 'guid' === $c ) || preg_match( '/(rio_process_queue|_sessions)$/', $t ) ) {
			continue;
		}
		if ( ! isset( $pks[ $t ] ) ) {
			$pk         = $wpdb->get_col( "SHOW KEYS FROM `$t` WHERE Key_name = 'PRIMARY'", 4 );
			webp_migrate_db_ok( "keys of $t" );
			$pks[ $t ] = 1 === count( $pk ) ? $pk[0] : '';
		}
		$where = "`$c` LIKE '%.png%'";
		if ( $t === $wpdb->options && 'option_value' === $c ) {
			$where .= " AND option_name NOT LIKE '\\_transient\\_%' AND option_name NOT LIKE '\\_site\\_transient\\_%'";
		}
		$out[] = array( $t, $c, $pks[ $t ], $where );
	}
	return $out;
}

/**
 * Rewrite every reference. Returns [ rows changed (or to change), per column, unresolved per
 * column ]. A table with no single-column key cannot be updated row by row: each of its rows
 * that names an old file is counted unresolved.
 */
function webp_migrate_replace_all( $map, $dry ) {
	global $wpdb;
	$total      = 0;
	$per        = array();
	$unresolved = array();
	foreach ( webp_migrate_columns() as list( $t, $c, $pk, $where ) ) {
		if ( '' === $pk ) {
			$n = webp_migrate_scan_column( $t, $c, '', $where, webp_migrate_verify_patterns( $map ) );
			if ( $n ) {
				$unresolved[ "$t.$c" ] = $n;
			}
			continue;
		}
		$last = null;
		do {
			$sql  = "SELECT `$pk` AS k, `$c` AS v FROM `$t` WHERE $where" . ( null === $last ? '' : $wpdb->prepare( " AND `$pk` > %s", $last ) ) . " ORDER BY `$pk` LIMIT 500";
			$rows = $wpdb->get_results( $sql );
			webp_migrate_db_ok( "$t.$c" );
			$rows = (array) $rows;
			foreach ( $rows as $row ) {
				$last = $row->k;
				list( $new, $stuck ) = webp_migrate_replace_cell( (string) $row->v, $map );
				if ( $stuck ) {
					$unresolved[ "$t.$c" ] = isset( $unresolved[ "$t.$c" ] ) ? $unresolved[ "$t.$c" ] + 1 : 1;
				}
				if ( null === $new ) {
					continue;
				}
				$total++;
				$per[ "$t.$c" ] = isset( $per[ "$t.$c" ] ) ? $per[ "$t.$c" ] + 1 : 1;
				if ( ! $dry ) {
					if ( false === $wpdb->update( $t, array( $c => $new ), array( $pk => $row->k ) ) ) {
						WP_CLI::error( "webp-migrate: could not update $t.$c row " . $row->k . ': ' . $wpdb->last_error );
					}
				}
			}
		} while ( count( $rows ) === 500 );
	}
	if ( ! $dry && $total ) {
		wp_cache_flush();
	}
	return array( $total, $per, $unresolved );
}

/** Stop on a failed query: an empty result read as "no rows" would let verify pass. */
function webp_migrate_db_ok( $what ) {
	global $wpdb;
	if ( '' !== (string) $wpdb->last_error ) {
		WP_CLI::error( 'webp-migrate: query failed (' . $what . '): ' . $wpdb->last_error );
	}
}

/**
 * Verify's matcher, deliberately not replace's pattern: any occurrence of an old file's base
 * name, plain or percent-encoded, in any surrounding (JSON escaped twice, a trailing dot,
 * spaces, brackets), except as Robin's `<name>.png.webp` sibling. A base name shared with a
 * file outside the map also matches: a false alarm is fixable, a false all-clear moves files
 * that are still in use. Returns a list of regexes over chunks of the names.
 */
function webp_migrate_verify_patterns( $map, $skip_siblings = true ) {
	$names = array();
	foreach ( array_keys( $map ) as $rel ) {
		foreach ( webp_migrate_name_forms( basename( $rel ) ) as $form ) {
			$names[ preg_quote( $form, '~' ) ] = true;
		}
	}
	$patterns = array();
	foreach ( array_chunk( array_keys( $names ), 400 ) as $chunk ) {
		$patterns[] = '~(?:' . implode( '|', $chunk ) . ')' . ( $skip_siblings ? '(?!\.webp)' : '' ) . '~i';
	}
	return $patterns;
}

/**
 * Every spelling a stored value can give one file name: as is, percent-encoded both ways
 * (`%20` and `+`), JSON-escaped (`\u00e9` for a non-ASCII byte, `\/` cannot occur in a base
 * name), and HTML-escaped (`&amp;`).
 *
 * @return string[]
 */
function webp_migrate_name_forms( $base ) {
	$forms = array( $base, rawurlencode( $base ), urlencode( $base ), htmlspecialchars( $base, ENT_QUOTES ), htmlentities( $base, ENT_QUOTES, 'UTF-8' ) );
	$json  = json_encode( $base );
	if ( is_string( $json ) ) {
		$forms[] = substr( $json, 1, -1 );
	}
	return array_values( array_unique( array_filter( $forms, 'strlen' ) ) );
}

function webp_migrate_names_old( $raw, $patterns ) {
	foreach ( $patterns as $re ) {
		$hit = preg_match( $re, $raw );
		if ( 0 !== $hit ) {
			return true; // a match, or PCRE gave up (false): count it either way
		}
	}
	return false;
}

/**
 * Rows of one column that still name an old file. Read-only. Keyset pages by the primary key
 * when there is one; a table without one is read in a single query, so no page can skip a row.
 */
function webp_migrate_scan_column( $t, $c, $pk, $where, $patterns ) {
	global $wpdb;
	$n = 0;
	if ( '' === $pk ) {
		$vals = $wpdb->get_col( "SELECT `$c` FROM `$t` WHERE $where" );
		webp_migrate_db_ok( "$t.$c" );
		foreach ( (array) $vals as $v ) {
			if ( webp_migrate_names_old( (string) $v, $patterns ) ) {
				$n++;
			}
		}
		return $n;
	}
	$last = null;
	do {
		$rows = $wpdb->get_results( "SELECT `$pk` AS k, `$c` AS v FROM `$t` WHERE $where" . ( null === $last ? '' : $wpdb->prepare( " AND `$pk` > %s", $last ) ) . " ORDER BY `$pk` LIMIT 500" );
		webp_migrate_db_ok( "$t.$c" );
		$rows = (array) $rows;
		foreach ( $rows as $row ) {
			$last = $row->k;
			if ( webp_migrate_names_old( (string) $row->v, $patterns ) ) {
				$n++;
			}
		}
	} while ( count( $rows ) === 500 );
	return $n;
}

/**
 * Verify's database half: rows whose raw value still names an old file, per column. It reads
 * the stored bytes with its own matcher and never decodes them, so a value replace could not
 * rewrite, or a reference replace's pattern does not see, still counts.
 */
function webp_migrate_scan_all( $map, $skip_siblings = true ) {
	$patterns = webp_migrate_verify_patterns( $map, $skip_siblings );
	$total    = 0;
	$per      = array();
	foreach ( webp_migrate_columns() as list( $t, $c, $pk, $where ) ) {
		$n = webp_migrate_scan_column( $t, $c, $pk, $where, $patterns );
		if ( $n ) {
			$per[ "$t.$c" ] = $n;
			$total         += $n;
		}
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
			// A shutdown function, not `finally`: WP_CLI::error() exits, and exit skips finally.
			register_shutdown_function( function () use ( $robin_key, $robin_old ) {
				update_option( $robin_key, $robin_old );
			} );
		}
		$done   = 0;
		$failed = 0;
		{
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

				// From here the attachment is half done until its map rows are written. No marker,
				// no change: an unrecorded half-done attachment is the one trap with no repair.
				if ( false === file_put_contents( $wm_progress, wp_json_encode( array( 'id' => $id, 'attached' => $attached, 'meta' => $meta ) ) ) ) {
					@unlink( $target );
					WP_CLI::error( 'webp-migrate: cannot write ' . $wm_progress . '; nothing was changed for attachment ' . $id );
				}
				update_attached_file( $id, $target );
				$wpdb->update( $wpdb->posts, array( 'post_mime_type' => 'image/webp' ), array( 'ID' => $id ) );
				clean_post_cache( $id );
				$new_meta = wp_create_image_subsizes( $target, $id );
				if ( ! is_array( $new_meta ) || empty( $new_meta['file'] ) ) {
					// The marker stays: the next run stops, and Traps says how to finish it.
					WP_CLI::error( 'webp-migrate: attachment ' . $id . ' has no sizes after conversion' . ( is_wp_error( $new_meta ) ? ' (' . $new_meta->get_error_message() . ')' : '' ) . '; ' . $wm_progress . ' left in place' );
				}
				$new_rel = (string) get_post_meta( $id, '_wp_attached_file', true );
				$lines   = '';
				foreach ( webp_migrate_rows( $old, $new_meta, $new_rel ) as $from => $to ) {
					if ( $from !== $to ) {
						$lines .= $from . "\t" . $to . "\t" . $id . "\n";
					}
				}
				if ( false === file_put_contents( $wm_map_file, $lines, FILE_APPEND | LOCK_EX ) ) {
					WP_CLI::error( 'webp-migrate: cannot append to ' . $wm_map_file . ' for attachment ' . $id . '; ' . $wm_progress . ' left in place' );
				}
				unlink( $wm_progress );
				webp_migrate_out( array( 'id' => $id, 'action' => 'converted', 'file' => $new_rel, 'sizes' => isset( $new_meta['sizes'] ) ? count( $new_meta['sizes'] ) : 0 ) );
				$done++;
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
		list( $total, $per, $stuck ) = webp_migrate_replace_all( $map, $wm_dry );
		webp_migrate_out( array( 'summary' => 'replace', 'rows' => $total, 'columns' => $per, 'unresolved' => $stuck, 'dry_run' => $wm_dry ) );
		if ( $stuck ) {
			WP_CLI::warning( 'webp-migrate: some rows name old files but cannot be rewritten safely (an object or a broken serialization, or a table with no single-column key); fix them by hand, verify will fail until then' );
		}
		break;

	case 'verify':
	case 'move-aside':
		$map = webp_migrate_load_map( $wm_map_file );
		if ( ! $map ) {
			WP_CLI::error( 'webp-migrate: the map is empty; run convert first' );
		}
		$missing        = webp_migrate_missing( $map, $wm_base );
		list( $refs, $per ) = webp_migrate_scan_all( $map );
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
		// Robin's <name>.png.webp siblings move with their PNG only when nothing stored names
		// them: verify's own matcher skips them on purpose, so they get their own scan here.
		$siblings = array();
		foreach ( array_keys( $map ) as $rel ) {
			if ( file_exists( $wm_base . '/' . $rel . '.webp' ) ) {
				$siblings[ $rel . '.webp' ] = $rel . '.webp';
			}
		}
		$keep_siblings = false;
		if ( $siblings ) {
			list( $sib_refs ) = webp_migrate_scan_all( $siblings, false );
			if ( $sib_refs ) {
				$keep_siblings = true;
				WP_CLI::warning( "webp-migrate: $sib_refs rows name Robin's .png.webp siblings; the siblings stay in uploads" );
			}
		}
		foreach ( array_keys( $map ) as $rel ) {
			$files = $keep_siblings ? array( $rel ) : array( $rel, $rel . '.webp' );
			foreach ( $files as $f ) {
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
		webp_migrate_out( array( 'summary' => 'move-aside', 'moved' => $moved, 'bytes' => $bytes, 'kept_siblings' => $keep_siblings, 'backup' => $wm_backup, 'dry_run' => $wm_dry ) );
		break;
}
