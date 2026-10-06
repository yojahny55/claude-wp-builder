<?php
/**
 * webp-gd.php -- robin-fix.sh's last-resort WebP converter, when neither ImageMagick nor
 * cwebp is installed. Called by robin-fix.sh; never run by hand.
 *
 * Usage: php webp-gd.php <source> <destination> <quality>
 * Exit 0 when <destination> was written, 1 otherwise.
 *
 * PNG, JPEG and GIF -- every format robin-fix.sh queues (`allowed_formats`). It used to be
 * inline PHP in the script using `match`, which is a parse error before PHP 8.0, and it had
 * no GIF branch, so every GIF failed. PHP 7.4 floor.
 */

if ( $argc < 4 || ! function_exists( 'imagewebp' ) ) {
	exit( 1 );
}
list( , $src, $dst, $quality ) = $argv;

$info = @getimagesize( $src );
if ( ! $info ) {
	exit( 1 );
}
$readers = array(
	'image/png'  => 'imagecreatefrompng',
	'image/jpeg' => 'imagecreatefromjpeg',
	'image/gif'  => 'imagecreatefromgif',
);
if ( ! isset( $readers[ $info['mime'] ] ) ) {
	exit( 1 );
}
$img = @call_user_func( $readers[ $info['mime'] ], $src );
if ( ! $img ) {
	exit( 1 );
}
// imagewebp() refuses a palette image, which is what every GIF and many PNGs are.
imagepalettetotruecolor( $img );
imagealphablending( $img, false );
imagesavealpha( $img, true );
$ok = @imagewebp( $img, $dst, (int) $quality );
imagedestroy( $img );
exit( $ok && is_file( $dst ) && filesize( $dst ) > 0 ? 0 : 1 );
