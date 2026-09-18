<?php
/**
 * Report post IDs stored in relationship and post-object fields that no longer resolve.
 *
 * Usage: wp eval-file find-orphan-acf-ids.php [theme-path]
 *
 * With a theme path, the report is split: a field name some template reads with
 * get_field() is reported as REACHES-TEMPLATE, everything else as DEAD-DATA.
 * Without one, every orphan is reported as UNCLASSIFIED.
 *
 * Read-only. Exits 1 when any orphan reaches a template, 0 otherwise — dead data
 * is worth cleaning and is not worth failing a deploy over.
 *
 * WHY THIS EXISTS. Deleting a post from wp-admin does not clear its ID out of the
 * fields that point at it. The ID stays in postmeta verbatim. On an audited site a
 * template iterated such a field and printed one card per ID, so a deleted post
 * became a visible card with no title, no terms and an empty href. The same defect
 * was present in production, inherited rather than introduced, and nothing in the
 * theme could reveal it: the code was correct, the data was not.
 *
 * WHY THE SPLIT MATTERS. The first sweep of that site found 70 orphaned IDs.
 * Exactly 1 reached the HTML; the other 69 lived in fields no template reads.
 * A report of 70 warnings buries the one that is visible, so this script asks the
 * theme which field names it actually reads before it decides a severity.
 *
 * Revisions are excluded. ACF can write field values onto revision posts, and an
 * orphan there is a copy of the parent's: the operator cannot fix a revision, and
 * fixing the parent fixes both. Only revisions are excluded, not every
 * non-publish parent — a draft or private page is real content whose fields do
 * reach a template on preview, so dropping those would hide live findings.
 *
 * A non-publish status is the same defect with a different cause and is reported
 * too. get_post_status() answers 'draft' or 'trash' rather than false, so a check
 * that only tests get_post() for null misses it — and a trashed post still has a
 * permalink a template will print.
 */

global $wpdb;

$argv_in = isset( $args ) ? $args : ( isset( $GLOBALS['args'] ) ? $GLOBALS['args'] : array() );
$theme   = ! empty( $argv_in[0] ) ? rtrim( $argv_in[0], '/' ) : '';

/*
 * A path that does not resolve would leave the read-field list empty, and every
 * orphan would then be labelled DEAD-DATA — the script would print a reassuring
 * summary and exit 0 while the classification had never run. Refuse instead.
 */
if ( '' !== $theme && ! is_dir( $theme ) ) {
	fwrite( STDERR, "find-orphan-acf-ids.php: '{$theme}' is not a directory\n" );
	exit( 2 );
}

if ( ! function_exists( 'acf_get_field' ) ) {
	fwrite( STDERR, "find-orphan-acf-ids.php: ACF is not active, so field types cannot be resolved\n" );
	exit( 2 );
}

/*
 * ACF stores a relationship value as a serialized array of IDs and a post-object
 * value as a single ID, both under the field's own meta_key, with the field key
 * under '_' . meta_key. The '_' row is what makes the field's type knowable.
 *
 * The type must be checked, not inferred from the value. A date field holds
 * 20250910 and a number field holds 142; both are numeric, neither is a post ID,
 * and get_post_status() answers false for both. A first version of this script
 * skipped the type lookup and reported 248 orphans on a site that had 70 — every
 * date and number field in the database, each one a false positive that a reader
 * would have had to dismiss by hand.
 */
$rows = $wpdb->get_results(
	"SELECT pm.post_id, pm.meta_key, pm.meta_value, fk.meta_value AS field_key
	   FROM {$wpdb->postmeta} pm
	   JOIN {$wpdb->postmeta} fk
	     ON fk.post_id = pm.post_id
	    AND fk.meta_key = CONCAT('_', pm.meta_key)
	   JOIN {$wpdb->posts} p
	     ON p.ID = pm.post_id
	  WHERE fk.meta_value LIKE 'field_%'
	    AND pm.meta_value <> ''
	    AND p.post_type <> 'revision'"
);

// The only field types whose stored value is a post ID.
$id_types = array( 'relationship' => true, 'post_object' => true, 'page_link' => true );
$types    = array();

/*
 * Field names the theme reads. A field nobody reads cannot print a broken card,
 * however wrong its stored value is.
 */
$read = array();
if ( $theme && is_dir( $theme ) ) {
	$files = new RecursiveIteratorIterator( new RecursiveDirectoryIterator( $theme ) );
	foreach ( $files as $file ) {
		if ( 'php' !== strtolower( $file->getExtension() ) ) {
			continue;
		}
		// Both quoting styles. A get_field( $var ) call cannot be resolved statically;
		// a field read only that way is classified DEAD-DATA, which under-reports.
		if ( preg_match_all( "/get_field\(\s*['\"]([a-z0-9_]+)['\"]/i", (string) file_get_contents( $file->getPathname() ), $m ) ) {
			foreach ( $m[1] as $name ) {
				$read[ $name ] = true;
			}
		}
	}
}

$reaching = 0;
$dead     = 0;

foreach ( $rows as $row ) {
	if ( ! array_key_exists( $row->field_key, $types ) ) {
		$field                    = acf_get_field( $row->field_key );
		$types[ $row->field_key ] = ( $field && isset( $field['type'] ) ) ? $field['type'] : '';
	}

	if ( ! isset( $id_types[ $types[ $row->field_key ] ] ) ) {
		continue;
	}

	$value = maybe_unserialize( $row->meta_value );
	$ids   = array();

	foreach ( (array) $value as $candidate ) {
		// A relationship array holds IDs; anything else in this meta_key is not one.
		if ( is_numeric( $candidate ) ) {
			$ids[] = (int) $candidate;
		}
	}

	foreach ( $ids as $id ) {
		$status = get_post_status( $id );

		if ( 'publish' === $status ) {
			continue;
		}

		$why = ( false === $status ) ? 'deleted' : "status={$status}";

		if ( $theme ) {
			$bucket = isset( $read[ $row->meta_key ] ) ? 'REACHES-TEMPLATE' : 'DEAD-DATA';
		} else {
			$bucket = 'UNCLASSIFIED';
		}

		printf(
			"%-17s post %d field '%s' points at %d (%s)\n",
			$bucket,
			$row->post_id,
			$row->meta_key,
			$id,
			$why
		);

		if ( 'DEAD-DATA' === $bucket ) {
			$dead++;
		} else {
			$reaching++;
		}
	}
}

printf( "\n%d orphaned IDs reach a template, %d are dead data\n", $reaching, $dead );

if ( ! $theme ) {
	echo "Pass a theme path to split these by whether a template reads the field.\n";
}

exit( $reaching > 0 ? 1 : 0 );
