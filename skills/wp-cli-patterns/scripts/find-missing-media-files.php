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
 *                 A bare date with no time of day is ambiguous for its
 *                 own calendar day: an upload made that same day compares as
 *                 "after archive" regardless of what time the archive was
 *                 actually taken, which would silently suppress a real
 *                 pre-archive loss as N/A (local clone). To stay on the safe
 *                 side, a date-only cutoff is pushed to the END of that day
 *                 (23:59:59), so nothing uploaded on the archive date itself
 *                 can be waved through as AFTER-ARCHIVE — it is reported
 *                 BEFORE-ARCHIVE instead. Pass a full `Y-m-d H:i:s` timestamp
 *                 to narrow the window to the exact time the archive was
 *                 taken and stop folding that whole day into BEFORE-ARCHIVE;
 *                 an explicit time is used as given, 00:00:00 included.
 *
 *                 Omit the argument entirely to bucket every miss UNDATED,
 *                 because without any date there is no way to tell a real
 *                 loss from an ordinary post-archive upload.
 *   sample-size   How many misses to print per bucket (default 20), as a
 *                 non-negative integer; anything else exits 2. Every miss is
 *                 still counted; only the printed list is capped.
 *
 * Read-only. Exits 1 when any BEFORE-ARCHIVE or UNDATED miss exists, 0 when
 * every miss is AFTER-ARCHIVE or there are none — a clone's dated gaps alone
 * should not fail anything on their own. Exits 2 when it cannot measure: an
 * archive date or sample size it does not accept, a failed query, or an uploads directory that
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
 * libraries too large to hold every attachment's meta at once, and only a
 * sample of each bucket is kept in memory, next to its exact count.
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
 * A bare `Y-m-d` date with no time of day — "2026-09-23" — parses to
 * midnight, which is ambiguous for its own calendar day: an upload later that
 * same day would otherwise compare as "after archive" no matter what time the
 * archive was actually taken, silently suppressing a real pre-archive loss as
 * N/A (local clone). Such a cutoff is pushed to the end of that day instead,
 * so the whole archive day reads BEFORE-ARCHIVE rather than being guessed at.
 * Only the two documented shapes are accepted — `Y-m-d`, or `Y-m-d H:i:s`
 * with a space or `T` between date and time (seconds optional). Anything
 * else (a written-out date, "yesterday", a timezone suffix) returns false
 * and the caller exits 2, because each extra format is another place where
 * "was a time given?" could be read wrong. Whether a time was given is read
 * from the argument's shape, not from the parsed timestamp, so an explicit
 * "...00:00:00" is a real time and is used exactly as given.
 */
function mmf_compute_archive_cutoff( $archive_arg ) {
	if ( '' === $archive_arg ) {
		return false;
	}

	if ( ! preg_match( '/^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?$/', $archive_arg, $m ) ) {
		return false;
	}
	if ( ! checkdate( (int) $m[2], (int) $m[3], (int) $m[1] ) ) {
		return false;
	}

	$has_time = isset( $m[4] ) && '' !== $m[4];
	if ( $has_time && ( (int) $m[4] > 23 || (int) $m[5] > 59 || ( isset( $m[6] ) && (int) $m[6] > 59 ) ) ) {
		return false;
	}

	$time = $has_time
		? sprintf( '%s:%s:%s', $m[4], $m[5], isset( $m[6] ) && '' !== $m[6] ? $m[6] : '00' )
		: '23:59:59';

	return strtotime( "{$m[1]}-{$m[2]}-{$m[3]} {$time}" );
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
$sample_arg  = isset( $argv_in[1] ) ? trim( (string) $argv_in[1] ) : '';
if ( '' !== $sample_arg && ! ctype_digit( $sample_arg ) ) {
	fwrite( STDERR, "find-missing-media-files.php: sample-size '{$sample_arg}' is not a non-negative integer\n" );
	exit( 2 );
}
$sample_size = '' !== $sample_arg ? (int) $sample_arg : 20;

$archive_ts = mmf_compute_archive_cutoff( $archive_arg );
if ( '' !== $archive_arg && false === $archive_ts ) {
	fwrite( STDERR, "find-missing-media-files.php: '{$archive_arg}' is not a Y-m-d or Y-m-d H:i:s date\n" );
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
// Exact totals per bucket. $buckets keeps only the first $sample_size misses of
// each, so a restore that lost most of a large library does not hold hundreds
// of thousands of records in memory just to print twenty of them.
$bucket_counts = array_fill_keys( array_keys( $buckets ), 0 );

const BATCH_SIZE = 1000;

$last_id          = 0;
$attachment_count = 0;
$skipped_count    = 0;

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

	// wp_get_attachment_metadata() below calls get_post(), which reads the post
	// object cache; the batch query above bypasses it, so without this every
	// attachment would cost its own SELECT * — the per-ID pattern batching exists
	// to remove. Priming keeps the wp_get_attachment_metadata filter in play for
	// offload plugins that rewrite the metadata.
	if ( function_exists( '_prime_post_caches' ) ) {
		_prime_post_caches( $batch_ids, false, false );
	}

	foreach ( $rows as $row ) {
		$id            = (int) $row->ID;
		$attached_file = get_post_meta( $id, '_wp_attached_file', true );

		// An absolute path is fine as it is: path_join() returns an absolute
		// $path untouched instead of prefixing $basedir, and dirname() of it is
		// the right directory for the sub-sizes too.
		//
		// Only a plain filesystem path can be checked on this server's disk. No
		// _wp_attached_file at all, a remote URL stored there by an offsite-media
		// or import plugin (`https://cdn.example.com/...`), or a corrupt non-string
		// value is skipped: joined to basedir, a URL would read as a false miss for
		// the file and every sub-size, and dirname() on an array is a TypeError
		// that would abort the whole run.
		if ( ! is_string( $attached_file ) || '' === $attached_file
			|| preg_match( '#^[a-z][a-z0-9+.\-]*://#i', $attached_file ) ) {
			$skipped_count++;
			continue;
		}
		$attachment_count++;

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

			$bucket_counts[ $bucket ]++;
			if ( count( $buckets[ $bucket ] ) < $sample_size ) {
				$buckets[ $bucket ][] = array(
					'code'  => $code,
					'id'    => $id,
					'label' => $label,
					'path'  => $relative_path,
					'date'  => $post_date,
				);
			}
		}
	}

	$last_id            = (int) end( $batch_ids );

	if ( count( $rows ) < BATCH_SIZE ) {
		break;
	}

	// Drop this batch's primed post meta before pulling the next one, so memory
	// stays bounded on large libraries. A runtime flush (WP 6.1+, when the cache
	// supports it) clears only this process's copies and never touches a
	// persistent backend shared with the live site. Without it, the batch's own
	// 'post_meta' keys are deleted instead — the only keys update_meta_cache()
	// wrote — which on a persistent cache also evicts them from the backend.
	$flushed = function_exists( 'wp_cache_supports' ) && wp_cache_supports( 'flush_runtime' )
		&& function_exists( 'wp_cache_flush_runtime' ) && wp_cache_flush_runtime();
	if ( ! $flushed ) {
		if ( function_exists( 'wp_cache_delete_multiple' ) ) {
			wp_cache_delete_multiple( $batch_ids, 'post_meta' );
		} else {
			foreach ( $batch_ids as $batch_id ) {
				wp_cache_delete( $batch_id, 'post_meta' );
			}
		}
	}
}

$total = 0;
foreach ( $buckets as $bucket_name => $items ) {
	$count  = $bucket_counts[ $bucket_name ];
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
// A skipped attachment was never compared against disk. Saying so keeps a library
// that is entirely offloaded from reading as a clean pass over every attachment.
if ( $skipped_count > 0 ) {
	printf(
		"%d attachment(s) skipped, not checked: no local file path (remote URL, empty or corrupt _wp_attached_file)\n",
		$skipped_count
	);
}

exit( ( $bucket_counts['BEFORE-ARCHIVE'] > 0 || $bucket_counts['UNDATED'] > 0 ) ? 1 : 0 );
