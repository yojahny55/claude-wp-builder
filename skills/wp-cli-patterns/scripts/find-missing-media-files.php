<?php
/**
 * Report attachments whose file — the main upload, a registered image
 * sub-size, or the pre-scale `original_image` backup — is missing on disk.
 *
 * Usage: wp eval-file find-missing-media-files.php [archive-date] [sample-size]
 *
 *   archive-date  Optional ISO 8601 date (`Y-m-d`, e.g. 2026-09-23) or full
 *                 timestamp (`Y-m-d H:i:s`, e.g. 2026-09-23 14:30:00) — the
 *                 moment the file archive was taken when this project is a
 *                 restored copy of a site that lives elsewhere (`/wp-audit`
 *                 Step 2.3 — read it before wiring this up; this script does
 *                 not detect clones itself). Every miss whose attachment
 *                 post_date is AFTER this cutoff is bucketed AFTER-ARCHIVE:
 *                 the media was uploaded after the backup was taken, so it
 *                 exists on production and this copy's archive was never
 *                 going to have it. Everything at or before the cutoff is
 *                 BEFORE-ARCHIVE — the file should already have been in the
 *                 archive, clone or not.
 *
 *                 Give the cutoff in the SITE's timezone, the same wall-clock
 *                 time post_date holds (what wp-admin shows), not the
 *                 server's. Both sides are parsed by strtotime() in the same
 *                 PHP default timezone — UTC, which WordPress sets at
 *                 bootstrap — so they share one frame and no offset is
 *                 applied to either; a cutoff taken from the server clock
 *                 of a host in another timezone is off by that difference.
 *
 *                 A bare date with no time of day (including one that
 *                 happens to parse to exactly midnight) is ambiguous for its
 *                 own calendar day: an upload made that same day compares as
 *                 "after archive" regardless of what time the archive was
 *                 actually taken, which would silently suppress a real
 *                 pre-archive loss as N/A (local clone). To stay on the safe
 *                 side, a date-only cutoff is pushed to the END of that day
 *                 (23:59:59), so nothing uploaded on the archive date itself
 *                 can be waved through as AFTER-ARCHIVE — it is reported
 *                 BEFORE-ARCHIVE instead. Pass a full `Y-m-d H:i:s` timestamp
 *                 to narrow the window to the exact time the archive was
 *                 taken and stop folding that whole day into BEFORE-ARCHIVE.
 *
 *                 Omit the argument entirely to bucket every miss UNDATED,
 *                 because without any date there is no way to tell a real
 *                 loss from an ordinary post-archive upload.
 *   sample-size   How many misses to print per bucket (default 20). Every
 *                 miss is still counted; only the printed list is capped.
 *
 * Read-only. Exits 1 when any BEFORE-ARCHIVE or UNDATED miss exists, 0 when
 * every miss is AFTER-ARCHIVE or there are none — a clone's dated gaps alone
 * should not fail anything on their own. Exits 2 when it cannot measure: an
 * unparseable archive date, a failed query, or an uploads directory that
 * wp_get_upload_dir() cannot resolve — never a list of false misses.
 *
 * WHY THIS EXISTS. `_wp_attached_file` and `_wp_attachment_metadata` are
 * database rows; they outlive the file they point at whenever an upload is
 * deleted from disk by hand, a restore skips (or only partially copies) the
 * uploads directory, or a migration drops the sub-sizes to save space.
 * WordPress serves a broken `<img>` or a 404 download and never checks —
 * there is no core notice for a thumbnail, or a purchased download, that
 * simply is not there.
 *
 * WHY THE SPLIT MATTERS. A restored local copy is commonly a database dump
 * paired with a file archive taken at a different time. Media uploaded
 * between the archive and the dump is a real, healthy file in production
 * that simply postdates this copy's archive — reporting it as a defect
 * audits the copy, not the site. A gap that predates the archive has no
 * such excuse: the file should already have been backed up, on a clone or
 * not.
 *
 * WHY BATCHED. Attachments are walked BATCH_SIZE IDs at a time instead of
 * pulling every ID with get_col() and then calling get_post_meta() and
 * get_post_field() per attachment. That per-ID pattern is 2N extra queries
 * on top of the ID list — tens of thousands of round trips on a site with
 * tens of thousands of attachments, for a report that is read-only. Each
 * batch instead pulls ID + post_date in one query and primes the meta
 * cache for that batch's IDs with update_meta_cache(), so get_post_meta()
 * and wp_get_attachment_metadata() inside the loop read cache, not the
 * database. A runtime-cache flush between batches keeps memory bounded on
 * libraries too large to hold every attachment's meta at once.
 */

/**
 * Compute the effective archive-date cutoff from the raw CLI argument.
 *
 * Returns false when no date was given. Also returns false — indistinguishable
 * from "no date given" — when $archive_arg is set but strtotime() cannot parse
 * it; the caller checks $archive_arg itself to tell the two apart. Otherwise
 * returns an int Unix timestamp: the cutoff BEFORE-ARCHIVE/AFTER-ARCHIVE
 * buckets a miss against.
 *
 * A cutoff that lands on exact midnight — what a bare "Y-m-d" date parses to,
 * and also what an explicit "...00:00:00" timestamp parses to — is ambiguous
 * for its own calendar day: an upload later that same day would otherwise
 * compare as "after archive" no matter what time the archive was actually
 * taken, silently suppressing a real pre-archive loss as N/A (local clone).
 * The cutoff is pushed to the end of that day instead, so the whole archive
 * day reads BEFORE-ARCHIVE rather than being guessed at. Pass a full
 * "Y-m-d H:i:s" timestamp other than midnight to narrow the window to the
 * exact moment the archive was taken.
 */
function mmf_compute_archive_cutoff( $archive_arg ) {
	$archive_ts = '' !== $archive_arg ? strtotime( $archive_arg ) : false;

	if ( false !== $archive_ts && '00:00:00' === date( 'H:i:s', $archive_ts ) ) {
		$archive_ts = strtotime( date( 'Y-m-d', $archive_ts ) . ' 23:59:59' );
	}

	return $archive_ts;
}

/**
 * Bucket a dated miss against the archive cutoff. Only called once $archive_ts
 * is known not to be false — the caller decides UNDATED when there is no
 * cutoff. A post_date strtotime() cannot parse (empty, zeroed or corrupt) is
 * UNDATED too: comparing false against the cutoff would read it as 0 and file
 * the miss as BEFORE-ARCHIVE on no evidence.
 */
function mmf_bucket_for( $post_date, $archive_ts ) {
	$post_ts = strtotime( (string) $post_date );
	if ( false === $post_ts || $post_ts <= 0 ) {
		return 'UNDATED';
	}
	return ( $post_ts > $archive_ts ) ? 'AFTER-ARCHIVE' : 'BEFORE-ARCHIVE';
}

global $wpdb;

$argv_in     = isset( $args ) ? $args : ( isset( $GLOBALS['args'] ) ? $GLOBALS['args'] : array() );
$archive_arg = isset( $argv_in[0] ) && '' !== trim( (string) $argv_in[0] ) ? trim( (string) $argv_in[0] ) : '';
$sample_size = isset( $argv_in[1] ) && is_numeric( $argv_in[1] ) ? (int) $argv_in[1] : 20;

$archive_ts = mmf_compute_archive_cutoff( $archive_arg );
if ( '' !== $archive_arg && false === $archive_ts ) {
	fwrite( STDERR, "find-missing-media-files.php: '{$archive_arg}' is not a parseable date\n" );
	exit( 2 );
}

if ( false !== $archive_ts ) {
	printf( "Archive cutoff: %s (BEFORE-ARCHIVE at or before, AFTER-ARCHIVE strictly after)\n", date( 'Y-m-d H:i:s', $archive_ts ) );
}

$upload_dir = wp_get_upload_dir();
$basedir    = $upload_dir['basedir'];
// basedir comes back false (with 'error' set) when the uploads directory cannot
// be resolved or created. Every path joined to it would then be missing, and the
// report would be a wall of false misses instead of one clear failure.
if ( empty( $basedir ) || ! is_dir( $basedir ) ) {
	$reason = ! empty( $upload_dir['error'] ) ? $upload_dir['error'] : 'not a directory: ' . var_export( $basedir, true );
	fwrite( STDERR, 'find-missing-media-files.php: uploads directory unavailable — ' . $reason . "\n" );
	exit( 2 );
}

$buckets = array(
	'BEFORE-ARCHIVE' => array(),
	'AFTER-ARCHIVE'  => array(),
	'UNDATED'        => array(),
);

const BATCH_SIZE = 1000;

$last_id          = 0;
$attachment_count = 0;

while ( true ) {
	$rows = $wpdb->get_results(
		$wpdb->prepare(
			"SELECT ID, post_date FROM {$wpdb->posts}
			  WHERE post_type = 'attachment' AND ID > %d
			  ORDER BY ID LIMIT %d",
			$last_id,
			BATCH_SIZE
		)
	);

	// get_results() returns [] both for "no more rows" and for a failed query
	// (flush() clears last_result to [] before the query runs and only fills
	// it back in on success) — last_error is what tells the two apart. Left
	// unchecked, a typo'd table or column would read back as "0 attachments",
	// not as the query failure it is.
	if ( '' !== $wpdb->last_error ) {
		fwrite( STDERR, "find-missing-media-files.php: attachment query failed — {$wpdb->last_error}\n" );
		exit( 2 );
	}

	if ( empty( $rows ) ) {
		break;
	}

	$batch_ids = wp_list_pluck( $rows, 'ID' );
	update_meta_cache( 'post', $batch_ids );

	if ( '' !== $wpdb->last_error ) {
		fwrite( STDERR, "find-missing-media-files.php: meta cache query failed — {$wpdb->last_error}\n" );
		exit( 2 );
	}

	foreach ( $rows as $row ) {
		$id            = (int) $row->ID;
		$attached_file = get_post_meta( $id, '_wp_attached_file', true );

		// No _wp_attached_file at all: an attachment for an external/remote URL
		// (e.g. sideloaded from a CDN reference). Nothing on this server's disk
		// to check, and reporting it missing would be a false positive.
		if ( '' === $attached_file ) {
			continue;
		}

		$rel_dir   = dirname( $attached_file ); // '.' when the file sits at basedir root.
		$post_date = $row->post_date;

		// label => path relative to $basedir.
		$targets = array( 'file' => $attached_file );

		$meta = wp_get_attachment_metadata( $id );
		if ( is_array( $meta ) ) {
			if ( ! empty( $meta['sizes'] ) && is_array( $meta['sizes'] ) ) {
				foreach ( $meta['sizes'] as $size_name => $size_info ) {
					if ( ! empty( $size_info['file'] ) ) {
						$targets[ 'size:' . $size_name ] = ( '.' === $rel_dir )
							? $size_info['file']
							: $rel_dir . '/' . $size_info['file'];
					}
				}
			}
			if ( ! empty( $meta['original_image'] ) ) {
				$targets['original_image'] = ( '.' === $rel_dir )
					? $meta['original_image']
					: $rel_dir . '/' . $meta['original_image'];
			}
		}

		foreach ( $targets as $label => $relative_path ) {
			if ( file_exists( path_join( $basedir, $relative_path ) ) ) {
				continue;
			}

			if ( 'file' === $label ) {
				$code = 'WP-060';
			} elseif ( 0 === strpos( $label, 'size:' ) ) {
				$code = 'WP-061';
			} else {
				$code = 'WP-062';
			}

			$bucket = ( false === $archive_ts ) ? 'UNDATED' : mmf_bucket_for( $post_date, $archive_ts );

			$buckets[ $bucket ][] = array(
				'code'  => $code,
				'id'    => $id,
				'label' => $label,
				'path'  => $relative_path,
				'date'  => $post_date,
			);
		}
	}

	$attachment_count += count( $rows );
	$last_id            = (int) end( $batch_ids );

	if ( count( $rows ) < BATCH_SIZE ) {
		break;
	}

	// Drop this batch's primed meta (and anything else cached this request)
	// before pulling the next one, so memory stays bounded on large libraries.
	// wp_cache_flush_runtime() is core since WordPress 6.0 (wp-includes/cache.php,
	// with a cache-compat.php shim for object-cache drop-ins); the guard only
	// skips the flush on older cores, and never calls the full wp_cache_flush(),
	// which would also empty a persistent object cache shared with the live site.
	if ( function_exists( 'wp_cache_flush_runtime' ) ) {
		wp_cache_flush_runtime();
	}
}

$total = 0;
foreach ( $buckets as $bucket_name => $items ) {
	$count  = count( $items );
	$total += $count;

	printf( "\n%s: %d missing\n", $bucket_name, $count );

	foreach ( array_slice( $items, 0, $sample_size ) as $item ) {
		printf(
			"  %s attachment %d [%s] %s (post_date %s)\n",
			$item['code'],
			$item['id'],
			$item['label'],
			$item['path'],
			$item['date']
		);
	}

	if ( $count > $sample_size ) {
		printf( "  … %d more not shown\n", $count - $sample_size );
	}
}

printf(
	"\n%d attachment file(s) missing on disk out of %d attachment(s) checked\n",
	$total,
	$attachment_count
);

exit( ( count( $buckets['BEFORE-ARCHIVE'] ) > 0 || count( $buckets['UNDATED'] ) > 0 ) ? 1 : 0 );
