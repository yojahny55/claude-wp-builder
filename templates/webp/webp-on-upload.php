<?php
/**
 * Plugin Name: WebP on upload
 * Description: Converts PNG and JPEG uploads to WebP before WordPress makes their sizes, so every size is born WebP. Installed by /wp-webp.
 *
 * Must-use plugin. PHP 7.4 floor.
 *
 * It runs on `wp_handle_upload` and `wp_handle_sideload` at priority 5: the file is in the
 * uploads directory but no attachment, metadata or size exists yet, so swapping the file here
 * means WordPress makes every size from the WebP. Media library uploads, the block editor,
 * REST and `wp media import` all pass through one of the two filters.
 *
 * It encodes with `cwebp`, climbing a quality ladder and keeping the first candidate whose PSNR
 * against the original reaches the threshold (40 dB by default) and whose file is smaller than
 * the original. A PNG also gets a lossless candidate. When no candidate qualifies, the original
 * is kept untouched: this plugin never trades visible quality for bytes.
 *
 * Stream wrappers (S3 Uploads' `s3://`) are handled by copying to a local temporary file,
 * because `cwebp` reads and writes only real paths, and copying the result back.
 *
 * Without `cwebp`, without `proc_open`, or without an image editor that can write WebP sizes,
 * it does nothing and the upload goes through as before. Define WEBP_ON_UPLOAD_DISABLE as true
 * to switch it off without removing the file.
 */

defined( 'ABSPATH' ) || exit;

/**
 * The cwebp binary, or '' when there is none. WEBP_ON_UPLOAD_CWEBP overrides the lookup.
 */
function webp_on_upload_cwebp() {
	if ( defined( 'WEBP_ON_UPLOAD_CWEBP' ) ) {
		return is_executable( WEBP_ON_UPLOAD_CWEBP ) ? WEBP_ON_UPLOAD_CWEBP : '';
	}
	foreach ( array( '/usr/bin/cwebp', '/usr/local/bin/cwebp', '/opt/homebrew/bin/cwebp' ) as $path ) {
		if ( is_executable( $path ) ) {
			return $path;
		}
	}
	return '';
}

/**
 * Why the plugin would not convert right now, or '' when it would. /wp-webp status prints it.
 */
function webp_on_upload_blocker() {
	if ( defined( 'WEBP_ON_UPLOAD_DISABLE' ) && WEBP_ON_UPLOAD_DISABLE ) {
		return 'disabled by WEBP_ON_UPLOAD_DISABLE';
	}
	if ( ! function_exists( 'proc_open' ) ) {
		return 'proc_open is disabled';
	}
	if ( '' === webp_on_upload_cwebp() ) {
		return 'cwebp not found';
	}
	if ( function_exists( 'wp_image_editor_supports' ) && ! wp_image_editor_supports( array( 'mime_type' => 'image/webp' ) ) ) {
		return 'no image editor can write WebP sizes';
	}
	return '';
}

/**
 * Run cwebp once. Returns the PSNR (Total, dB) it reports, or null on failure.
 *
 * @param string   $src   local source path
 * @param string   $dst   local destination path
 * @param string[] $flags encoder flags
 * @return float|null
 */
function webp_on_upload_encode( $src, $dst, $flags ) {
	$cmd   = array_merge( array( webp_on_upload_cwebp() ), $flags, array( '-mt', '-print_psnr', $src, '-o', $dst ) );
	$line  = implode( ' ', array_map( 'escapeshellarg', $cmd ) );
	$pipes = array();
	$proc  = proc_open( $line, array( 1 => array( 'pipe', 'w' ), 2 => array( 'pipe', 'w' ) ), $pipes );
	if ( ! is_resource( $proc ) ) {
		return null;
	}
	$out = stream_get_contents( $pipes[1] ) . stream_get_contents( $pipes[2] );
	fclose( $pipes[1] );
	fclose( $pipes[2] );
	if ( 0 !== proc_close( $proc ) || ! is_file( $dst ) || ! filesize( $dst ) ) {
		return null;
	}
	return preg_match( '/Total:\s*([0-9.]+)/', $out, $m ) ? (float) $m[1] : null;
}

/**
 * Pick the WebP to keep for a local PNG or JPEG, or null to keep the original.
 * Candidates are tried smallest first; the first that reaches the PSNR threshold and is
 * smaller than the original wins.
 *
 * @param string $src  local source path
 * @param string $mime image/png or image/jpeg
 * @return string|null local path of the chosen WebP (the caller removes it), or null
 */
function webp_on_upload_choose( $src, $mime ) {
	$threshold = (float) apply_filters( 'webp_on_upload_psnr', 40.0 );
	$ladder    = (array) apply_filters( 'webp_on_upload_qualities', array( 75, 82, 90 ) );
	$limit     = (int) filesize( $src );
	$tmp       = tempnam( sys_get_temp_dir(), 'webp' );
	if ( false === $tmp ) {
		return null;
	}
	@unlink( $tmp );

	$candidates = array();
	foreach ( $ladder as $q ) {
		$candidates[] = array( '-q', (string) (int) $q, '-metadata', 'icc' );
	}
	if ( 'image/png' === $mime ) {
		$candidates[] = array( '-lossless', '-z', '6', '-metadata', 'icc' );
	}

	foreach ( $candidates as $i => $flags ) {
		$dst  = $tmp . '-' . $i . '.webp';
		$psnr = webp_on_upload_encode( $src, $dst, $flags );
		$size = is_file( $dst ) ? (int) filesize( $dst ) : 0;
		if ( null !== $psnr && $psnr >= $threshold && $size > 0 && $size < $limit ) {
			return $dst;
		}
		@unlink( $dst );
	}
	return null;
}

/**
 * The filter. Swaps a PNG or JPEG upload for its WebP, or returns it untouched.
 *
 * @param array $upload { file, url, type } from _wp_handle_upload()
 * @return array
 */
function webp_on_upload( $upload ) {
	if ( ! is_array( $upload ) || ! empty( $upload['error'] ) || empty( $upload['file'] ) || empty( $upload['type'] ) ) {
		return $upload;
	}
	$mime = $upload['type'];
	if ( 'image/png' !== $mime && 'image/jpeg' !== $mime ) {
		return $upload;
	}
	if ( '' !== webp_on_upload_blocker() ) {
		return $upload;
	}

	$file   = $upload['file'];
	$stream = function_exists( 'wp_is_stream' ) && wp_is_stream( $file );
	$local  = $file;
	if ( $stream ) {
		$local = tempnam( sys_get_temp_dir(), 'webpsrc' );
		if ( false === $local || ! copy( $file, $local ) ) {
			if ( $local ) {
				@unlink( $local );
			}
			return $upload;
		}
	}

	$webp = webp_on_upload_choose( $local, $mime );
	if ( $stream ) {
		@unlink( $local );
	}
	if ( null === $webp ) {
		return $upload;
	}

	// Not dirname(): on a wrapper path such as s3://bucket/x.jpg it can drop a slash of the
	// scheme. Everything before the last slash is the directory, local or remote.
	$dir    = substr( $file, 0, (int) strrpos( $file, '/' ) );
	$name   = wp_unique_filename( $dir, pathinfo( $file, PATHINFO_FILENAME ) . '.webp' );
	$target = $dir . '/' . $name;
	$moved  = $stream ? copy( $webp, $target ) : rename( $webp, $target );
	@unlink( $webp );
	if ( ! $moved || ! file_exists( $target ) ) {
		return $upload; // the original is still in place
	}
	if ( ! $stream ) {
		$stat = @stat( $dir );
		if ( $stat ) {
			@chmod( $target, $stat['mode'] & 0000666 );
		}
	}
	@unlink( $file );

	$upload['file'] = $target;
	$upload['url']  = trailingslashit( dirname( $upload['url'] ) ) . rawurlencode( $name );
	$upload['type'] = 'image/webp';
	return $upload;
}
add_filter( 'wp_handle_upload', 'webp_on_upload', 5 );
add_filter( 'wp_handle_sideload', 'webp_on_upload', 5 );
