<?php
/**
 * Report attachments whose file — the main upload, a registered image
 * sub-size, or the pre-scale `original_image` backup — is missing on disk.
 *
 * Usage: wp eval-file find-missing-media-files.php [archive-date] [sample-size]
 *
 *   archive-date  Optional ISO 8601 date (e.g. 2026-09-23), the date the file
 *                 archive was taken when this project is a restored copy of a
 *                 site that lives elsewhere (`/wp-audit` Step 2.3 — read it
 *                 before wiring this up; this script does not detect clones
 *                 itself). Every miss whose attachment post_date is AFTER
 *                 this date is bucketed AFTER-ARCHIVE: the media was
 *                 uploaded after the backup was taken, so it exists on
 *                 production and this copy's archive was never going to
 *                 have it. Everything at or before the date is
 *                 BEFORE-ARCHIVE — the file should already have been in the
 *                 archive, clone or not. Omit the argument to bucket every
 *                 miss UNDATED, because without a date there is no way to
 *                 tell a real loss from an ordinary post-archive upload.
 *   sample-size   How many misses to print per bucket (default 20). Every
 *                 miss is still counted; only the printed list is capped.
 *
 * Read-only. Exits 1 when any BEFORE-ARCHIVE or UNDATED miss exists, 0 when
 * every miss is AFTER-ARCHIVE or there are none — a clone's dated gaps alone
 * should not fail anything on their own.
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
 */

global $wpdb;

$argv_in     = isset( $args ) ? $args : ( isset( $GLOBALS['args'] ) ? $GLOBALS['args'] : array() );
$archive_arg = isset( $argv_in[0] ) && '' !== trim( (string) $argv_in[0] ) ? trim( (string) $argv_in[0] ) : '';
$sample_size = isset( $argv_in[1] ) && is_numeric( $argv_in[1] ) ? (int) $argv_in[1] : 20;

$archive_ts = '' !== $archive_arg ? strtotime( $archive_arg ) : false;
if ( '' !== $archive_arg && false === $archive_ts ) {
	fwrite( STDERR, "find-missing-media-files.php: '{$archive_arg}' is not a parseable date\n" );
	exit( 2 );
}

$upload_dir = wp_get_upload_dir();
$basedir    = $upload_dir['basedir'];

$attachment_ids = $wpdb->get_col(
	"SELECT ID FROM {$wpdb->posts} WHERE post_type = 'attachment'"
);

$buckets = array(
	'BEFORE-ARCHIVE' => array(),
	'AFTER-ARCHIVE'  => array(),
	'UNDATED'        => array(),
);

foreach ( $attachment_ids as $id ) {
	$id            = (int) $id;
	$attached_file = get_post_meta( $id, '_wp_attached_file', true );

	// No _wp_attached_file at all: an attachment for an external/remote URL
	// (e.g. sideloaded from a CDN reference). Nothing on this server's disk
	// to check, and reporting it missing would be a false positive.
	if ( '' === $attached_file ) {
		continue;
	}

	$rel_dir   = dirname( $attached_file ); // '.' when the file sits at basedir root.
	$post_date = get_post_field( 'post_date', $id );

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

		if ( false === $archive_ts ) {
			$bucket = 'UNDATED';
		} else {
			$bucket = ( strtotime( $post_date ) > $archive_ts ) ? 'AFTER-ARCHIVE' : 'BEFORE-ARCHIVE';
		}

		$buckets[ $bucket ][] = array(
			'code'  => $code,
			'id'    => $id,
			'label' => $label,
			'path'  => $relative_path,
			'date'  => $post_date,
		);
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
	count( $attachment_ids )
);

exit( ( count( $buckets['BEFORE-ARCHIVE'] ) > 0 || count( $buckets['UNDATED'] ) > 0 ) ? 1 : 0 );
