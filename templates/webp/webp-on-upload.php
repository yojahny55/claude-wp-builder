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
 * A JPEG whose EXIF says it is rotated is kept as it is (WebP would lose the tag and the sizes
 * would come out sideways), and so is a JPEG whose EXIF cannot be parsed. Images over 40 megapixels are kept, and each encode is killed after 30 seconds.
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
 * The command is an argument array, so no shell parses it (PHP 7.4 takes an array). Output
 * is read without blocking until the process exits or the deadline passes; at the deadline
 * the encoder is killed and the candidate fails, so a huge image cannot hang the upload.
 *
 * @param string   $src   local source path
 * @param string   $dst   local destination path
 * @param string[] $flags encoder flags
 * @return float|null
 */
function webp_on_upload_encode( $src, $dst, $flags ) {
	$cmd   = array_merge( array( webp_on_upload_cwebp() ), $flags, array( '-mt', '-print_psnr', $src, '-o', $dst ) );
	$pipes = array();
	$proc  = proc_open( $cmd, array( 0 => array( 'file', '/dev/null', 'r' ), 1 => array( 'pipe', 'w' ), 2 => array( 'pipe', 'w' ) ), $pipes );
	if ( ! is_resource( $proc ) ) {
		return null;
	}
	stream_set_blocking( $pipes[1], false );
	stream_set_blocking( $pipes[2], false );
	$deadline = microtime( true ) + (float) apply_filters( 'webp_on_upload_timeout', 30 );
	$out      = '';
	$open     = array( $pipes[1], $pipes[2] );
	while ( $open ) {
		$left = $deadline - microtime( true );
		if ( $left <= 0 ) {
			proc_terminate( $proc, 9 );
			break;
		}
		$read   = $open;
		$write  = null;
		$except = null;
		if ( false === stream_select( $read, $write, $except, (int) $left, 200000 ) ) {
			break;
		}
		foreach ( $read as $r ) {
			$chunk = fread( $r, 8192 );
			if ( false === $chunk || ( '' === $chunk && feof( $r ) ) ) {
				$open = array_filter( $open, function ( $o ) use ( $r ) {
					return $o !== $r;
				} );
				continue;
			}
			$out .= $chunk;
		}
	}
	$timed_out = microtime( true ) >= $deadline;
	fclose( $pipes[1] );
	fclose( $pipes[2] );
	$code = proc_close( $proc );
	if ( $timed_out || 0 !== $code || ! is_file( $dst ) || ! filesize( $dst ) ) {
		@unlink( $dst );
		return null;
	}
	return preg_match( '/Total:\s*([0-9.]+)/', $out, $m ) ? (float) $m[1] : null;
}

/**
 * Whether a local file is one this plugin should not touch: a JPEG whose EXIF says it is
 * rotated (cwebp would drop the tag, and WordPress rotates sizes from it, so the WebP would
 * come out sideways), a JPEG whose EXIF cannot be parsed, or an image over the pixel cap.
 *
 * @param string $src  local source path
 * @param string $mime image/png or image/jpeg
 * @return bool
 */
function webp_on_upload_skip( $src, $mime ) {
	$info = @getimagesize( $src );
	if ( ! $info ) {
		return true;
	}
	$cap = (int) apply_filters( 'webp_on_upload_max_pixels', 40000000 );
	if ( $cap > 0 && $info[0] * $info[1] > $cap ) {
		return true;
	}
	if ( 'image/jpeg' === $mime ) {
		$orientation = webp_on_upload_orientation( $src );
		if ( null === $orientation || $orientation > 1 ) {
			return true;
		}
	}
	return false;
}

/**
 * The EXIF Orientation of a JPEG: 1 when it has none, null when its EXIF cannot be parsed.
 * Read from the APP1 segment directly, so it does not depend on PHP's exif extension.
 *
 * @param string $src local JPEG path
 * @return int|null
 */
function webp_on_upload_orientation( $src ) {
	$head = @file_get_contents( $src, false, null, 0, 262144 );
	if ( ! is_string( $head ) || "\xFF\xD8" !== substr( $head, 0, 2 ) ) {
		return null;
	}
	$pos = 2;
	$len = strlen( $head );
	while ( $pos + 4 <= $len && "\xFF" === $head[ $pos ] ) {
		$marker = ord( $head[ $pos + 1 ] );
		$size   = unpack( 'n', substr( $head, $pos + 2, 2 ) )[1];
		if ( 0xDA === $marker || $size < 2 ) {
			return 1; // start of scan: no EXIF before the image data
		}
		if ( 0xE1 === $marker && "Exif\0\0" === substr( $head, $pos + 4, 6 ) ) {
			$tiff = substr( $head, $pos + 10, $size - 8 );
			$le   = 'II' === substr( $tiff, 0, 2 );
			if ( ! $le && 'MM' !== substr( $tiff, 0, 2 ) ) {
				return null;
			}
			$u16 = function ( $at ) use ( $tiff, $le ) {
				$b = substr( $tiff, $at, 2 );
				return 2 === strlen( $b ) ? unpack( $le ? 'v' : 'n', $b )[1] : null;
			};
			$u32 = function ( $at ) use ( $tiff, $le ) {
				$b = substr( $tiff, $at, 4 );
				return 4 === strlen( $b ) ? unpack( $le ? 'V' : 'N', $b )[1] : null;
			};
			$ifd   = $u32( 4 );
			$count = null === $ifd ? null : $u16( $ifd );
			if ( null === $count ) {
				return null;
			}
			for ( $i = 0; $i < $count; $i++ ) {
				$entry = $ifd + 2 + 12 * $i;
				$tag   = $u16( $entry );
				if ( null === $tag ) {
					return null;
				}
				if ( 0x0112 === $tag ) {
					$value = $u16( $entry + 8 );
					return null === $value ? null : (int) $value;
				}
			}
			return 1;
		}
		$pos += 2 + $size;
	}
	return 1;
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
	if ( webp_on_upload_skip( $src, $mime ) ) {
		return null;
	}
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
