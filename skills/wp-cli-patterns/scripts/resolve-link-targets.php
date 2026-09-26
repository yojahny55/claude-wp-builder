<?php
/**
 * Resolve internal link targets through the database, so only the rest need HTTP.
 *
 * Usage: wp eval-file resolve-link-targets.php <links.txt> <resolved.json> > http.txt
 *
 *   links.txt      one href per line, optionally TAB + the page it was found on
 *   resolved.json  written: the links the database answered, with what answered them
 *   stdout         the links that still need a request, as `href TAB page TAB group`,
 *                  ready for bin/link-sweep.mjs --urls
 *
 * Read-only. Exits 0 unless the input cannot be read.
 *
 * WHY THIS EXISTS. Whether a post or a term exists and is published is a query, not a
 * page render. An audit that answered it over HTTP rendered hundreds of uncached store
 * archives, 25 at a time, and held MariaDB at ~18 cores on a shared dev machine. See
 * "Link and page sweeps against a site" in skills/wp-audit-standards/SKILL.md.
 *
 * A LINK IS RESOLVED ONLY WHEN THE DATABASE IS SURE. `url_to_postid()` is lenient: it
 * maps a wrong parent path, or a slug under the wrong base, to a real post that then
 * answers with a redirect or a 404. So a match counts only when the object's own
 * canonical URL (`get_permalink()`, `get_term_link()`, `get_post_type_archive_link()`)
 * has the same path as the link. A published post, an existing term and a post type
 * archive are resolved; a draft, a private post, a query string, an author archive,
 * a paginated URL and anything unmatched go to HTTP. Never the other way round: this
 * script may send a good link to HTTP, and must never mark a broken one resolved.
 *
 * THE GROUP COLUMN is what link-sweep.mjs samples by: `tax:<taxonomy>` for a URL under a
 * taxonomy's base, `type:<post_type>` for a URL that matched a post, empty otherwise
 * (link-sweep then falls back to the first path segment). It is how "20 per taxonomy"
 * becomes per taxonomy rather than per guess.
 *
 * Links on other hosts, fragments and non-http schemes pass through unchanged; relative
 * hrefs that are not root-relative pass through with their page, and link-sweep resolves
 * them. PHP 7.4 floor.
 */

if ( ! isset( $args ) || count( $args ) < 2 ) {
	fwrite( STDERR, "usage: wp eval-file resolve-link-targets.php <links.txt> <resolved.json>\n" );
	exit( 2 );
}
$in_file  = $args[0];
$out_file = $args[1];
$lines    = @file( $in_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES );
if ( false === $lines ) {
	fwrite( STDERR, "resolve-link-targets: cannot read $in_file\n" );
	exit( 2 );
}

$home       = wp_parse_url( home_url( '/' ) );
$home_host  = strtolower( preg_replace( '/^www\./i', '', isset( $home['host'] ) ? $home['host'] : '' ) );
$home_host .= isset( $home['port'] ) ? ':' . $home['port'] : '';
$home_path  = isset( $home['path'] ) ? rtrim( $home['path'], '/' ) : '';
$origin     = home_url();

/** Path of a URL, with a trailing slash, for comparing a link to a canonical URL. */
function rlt_path( $url ) {
	$p = wp_parse_url( $url, PHP_URL_PATH );
	$p = is_string( $p ) && '' !== $p ? $p : '/';
	return '/' === substr( $p, -1 ) ? $p : $p . '/';
}

/** Host of a URL as this script compares hosts: lower case, no www., port kept. */
function rlt_host( $url ) {
	$u = wp_parse_url( $url );
	if ( ! is_array( $u ) || empty( $u['host'] ) ) {
		return '';
	}
	$h = strtolower( preg_replace( '/^www\./i', '', $u['host'] ) );
	return $h . ( isset( $u['port'] ) ? ':' . $u['port'] : '' );
}

$tax_bases = array();
foreach ( get_taxonomies( array( 'public' => true ), 'objects' ) as $tax ) {
	if ( ! empty( $tax->rewrite['slug'] ) ) {
		$tax_bases[ $tax->name ] = trim( $tax->rewrite['slug'], '/' );
	}
}

$resolved = array();
$http     = array();

foreach ( $lines as $line ) {
	$parts = explode( "\t", $line );
	$href  = trim( $parts[0] );
	$page  = isset( $parts[1] ) ? trim( $parts[1] ) : '';
	if ( '' === $href ) {
		continue;
	}
	$pass = array( $href, $page, '' );

	// Fragments, other schemes and page-relative hrefs are link-sweep's to classify.
	if ( '#' === $href[0] || ( preg_match( '#^[a-z][a-z0-9+.-]*:#i', $href ) && ! preg_match( '#^https?:#i', $href ) ) ) {
		$http[] = $pass;
		continue;
	}
	if ( 0 === strpos( $href, '//' ) ) {
		$url = ( isset( $home['scheme'] ) ? $home['scheme'] : 'https' ) . ':' . $href;
	} elseif ( '/' === $href[0] ) {
		// On a subdirectory install a root-relative href outside the install's path points
		// at the bare host, not at this WordPress; resolving it here could mark a 404 resolved.
		if ( '' !== $home_path && 0 !== strpos( $href, $home_path . '/' ) ) {
			$http[] = $pass;
			continue;
		}
		$url = $origin . ( '' !== $home_path ? substr( $href, strlen( $home_path ) ) : $href );
	} elseif ( preg_match( '#^https?://#i', $href ) ) {
		$url = $href;
	} else {
		$http[] = $pass;
		continue;
	}
	if ( rlt_host( $url ) !== $home_host ) {
		$http[] = $pass;
		continue;
	}
	$url  = preg_replace( '/#.*$/', '', $url );
	$path = rlt_path( $url );
	$rel  = '' !== $home_path && 0 === strpos( $path, $home_path . '/' ) ? substr( $path, strlen( $home_path ) ) : $path;

	// The group is worked out first: a link that goes to HTTP still needs it for sampling.
	$group = '';
	foreach ( $tax_bases as $name => $base ) {
		if ( 0 === strpos( ltrim( $rel, '/' ), $base . '/' ) ) {
			$group = 'tax:' . $name;
			break;
		}
	}

	$hit = null;
	if ( false === strpos( $url, '?' ) && ! preg_match( '#/page/\d+/$#', $path ) ) {
		if ( '/' === $rel ) {
			$hit = array( 'kind' => 'home' );
		}
		if ( ! $hit ) {
			$id = url_to_postid( $url );
			if ( $id ) {
				$post = get_post( $id );
				if ( ! $post ) {
					$http[] = array( $href, $page, $group );
					continue;
				}
				$group = '' !== $group ? $group : 'type:' . $post->post_type;
				if ( 'publish' === $post->post_status && '' === $post->post_password
					&& rlt_path( get_permalink( $post ) ) === $path ) {
					$hit = array( 'kind' => 'post', 'id' => $id, 'type' => $post->post_type );
				}
			}
		}
		if ( ! $hit && 0 === strpos( $group, 'tax:' ) ) {
			$tax  = substr( $group, 4 );
			$slug = basename( untrailingslashit( $rel ) );
			$term = get_term_by( 'slug', urldecode( $slug ), $tax );
			if ( $term ) {
				$link = get_term_link( $term );
				if ( ! is_wp_error( $link ) && rlt_path( $link ) === $path ) {
					$hit = array( 'kind' => 'term', 'id' => (int) $term->term_id, 'taxonomy' => $tax );
				}
			}
		}
		if ( ! $hit ) {
			foreach ( get_post_types( array( 'public' => true, 'has_archive' => true ) ) as $pt ) {
				$link = get_post_type_archive_link( $pt );
				if ( $link && rlt_path( $link ) === $path ) {
					$hit = array( 'kind' => 'archive', 'type' => $pt );
					break;
				}
			}
		}
	}

	if ( $hit ) {
		$key = $path;
		if ( ! isset( $resolved[ $key ] ) ) {
			$resolved[ $key ] = array_merge( array( 'url' => $url, 'pages' => array() ), $hit );
		}
		if ( '' !== $page && ! in_array( $page, $resolved[ $key ]['pages'], true ) ) {
			$resolved[ $key ]['pages'][] = $page;
		}
		continue;
	}
	$http[] = array( $href, $page, $group );
}

if ( false === file_put_contents( $out_file, wp_json_encode( array_values( $resolved ), JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES ) . "\n" ) ) {
	fwrite( STDERR, "resolve-link-targets: cannot write $out_file\n" );
	exit( 2 );
}
foreach ( $http as $row ) {
	echo implode( "\t", $row ) . "\n";
}
fwrite( STDERR, sprintf( "resolve-link-targets: %d resolved by the database, %d need HTTP\n", count( $resolved ), count( $http ) ) );
