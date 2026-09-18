<?php
/**
 * Report every database row that carries the development host.
 *
 * Usage: wp eval-file check-dev-host.php [host]
 *
 * With no argument the needle is derived from `home_url()`, which is what the
 * local install actually answers on. Pass a host to sweep for a different one —
 * an old staging domain that outlived its machine, for example.
 *
 * Read-only. Exits 1 when it finds anything, 0 when it does not, so it can gate
 * a deploy from a shell script without an agent reading its output.
 *
 * WHY THIS EXISTS. An audit swept `wp_options` for the development host, found 7
 * occurrences, fixed them and called the database clean. It was not: the same
 * needle across `postmeta`, `posts` and `termmeta` found 18 more, and those are
 * the ones that reach the page. A `custom` menu item stores its target in
 * `postmeta._menu_item_url` verbatim, so after a push it is a navigation link
 * that leaves the live site for a machine nobody outside the office can reach.
 * An absolute URL an editor pasted into `post_content` is the same defect inside
 * an article body. `wp_options` is the table that holds the least of this and it
 * was the only one anybody looked at.
 *
 * `home` and `siteurl` are excluded: they are expected to hold the development
 * host and are what makes the local site work. A `guid` match is reported
 * separately because WordPress treats a `guid` as a historical identifier and
 * never resolves it as a URL, so it is a lower-severity finding than a row whose
 * value is printed into markup.
 */

global $wpdb;

$argv_in = isset( $args ) ? $args : array();
$host    = ! empty( $argv_in[0] ) ? $argv_in[0] : home_url();
$needle  = preg_replace( '#^https?://#', '', rtrim( $host, '/' ) );

if ( '' === $needle ) {
	fwrite( STDERR, "check-dev-host.php: could not determine a host to search for\n" );
	exit( 2 );
}

$like = '%' . $wpdb->esc_like( $needle ) . '%';

/*
 * Each entry is [ sql, placeholder_count, label ]. The SQL selects exactly two
 * columns named `id` and `label` so one loop can print all four tables.
 */
$sweeps = array(
	'options'  => array(
		"SELECT option_name AS id, 'option_value' AS label FROM {$wpdb->options}
		  WHERE option_value LIKE %s AND option_name NOT IN ('home','siteurl')",
		1,
	),
	'postmeta' => array(
		"SELECT post_id AS id, meta_key AS label FROM {$wpdb->postmeta}
		  WHERE meta_value LIKE %s",
		1,
	),
	'posts'    => array(
		"SELECT ID AS id, 'post_content' AS label FROM {$wpdb->posts}
		  WHERE post_content LIKE %s",
		1,
	),
	'termmeta' => array(
		"SELECT term_id AS id, meta_key AS label FROM {$wpdb->termmeta}
		  WHERE meta_value LIKE %s",
		1,
	),
);

$total = 0;

echo "Searching for '{$needle}'\n\n";

foreach ( $sweeps as $table => $sweep ) {
	list( $sql, $placeholders ) = $sweep;

	$rows = $wpdb->get_results(
		$wpdb->prepare( $sql, array_fill( 0, $placeholders, $like ) )
	);

	printf( "%-9s %d\n", $table, count( $rows ) );

	foreach ( $rows as $row ) {
		printf( "          %s — %s\n", $row->id, $row->label );
	}

	$total += count( $rows );
}

/*
 * guid is swept on its own so its count never inflates the number that gates a
 * deploy. Rewriting a guid changes the identifier feed readers key on, so this
 * is reported for the record, not for fixing.
 */
$guids = $wpdb->get_col( $wpdb->prepare( "SELECT ID FROM {$wpdb->posts} WHERE guid LIKE %s", $like ) );

if ( $guids ) {
	printf( "\nguid      %d (historical identifiers, not printed as links — do not rewrite)\n", count( $guids ) );
}

printf( "\n%d rows carry the development host\n", $total );

exit( $total > 0 ? 1 : 0 );
