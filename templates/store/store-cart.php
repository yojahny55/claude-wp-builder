<?php
/**
 * Store cart: the header's link to the cart, with the number of items in it.
 * Copied by /wp-woo-setup to the theme's template-parts/header/store-cart.php, with its script,
 * templates/store/store-cart.js, copied to assets/js/store-cart.js. PHP 7.4 floor.
 *
 * header.php calls it where the demo draws its cart, or beside the menu toggle, never inside
 * the menu the toggle hides:
 *
 *   get_template_part( 'template-parts/header/store-cart', null, array(
 *       'link_class'  => '<the demo cart link's classes>',
 *       'count_class' => '<the demo count badge's classes>',
 *       'icon'        => '<the demo cart icon, an inline <svg>>',
 *   ) );
 *
 * Every key is optional. Until this file is installed the call renders nothing, and so does
 * the file itself without WooCommerce or while store-kit's catalog mode is on: a catalog has
 * no cart.
 *
 * The count comes from the server. WooCommerce's cart fragments are not used (an uncached
 * request on every page view); the script re-reads the count from the Store API only when
 * WooCommerce says the cart changed: added_to_cart and removed_from_cart (classic buttons,
 * jQuery events), wc-blocks_added_to_cart (block buttons) and wc-blocks_store_sync_required
 * (the cart and checkout blocks' quantity and remove controls).
 */

defined( 'ABSPATH' ) || exit;

if ( ! function_exists( 'WC' ) || ! function_exists( 'wc_get_cart_url' ) || null === WC()->cart ) {
	return;
}
if ( function_exists( 'store_kit_catalog_mode' ) && store_kit_catalog_mode() ) {
	return;
}

$store_cart = wp_parse_args(
	isset( $args ) && is_array( $args ) ? $args : array(),
	array(
		'link_class'  => '',
		'count_class' => '',
		'icon'        => '',
	)
);

$store_cart_count = (int) WC()->cart->get_cart_contents_count();
/* translators: %d: number of items in the cart. */
$store_cart_one = __( 'Cart, %d item', '__textdomain__' );
/* translators: %d: number of items in the cart. */
$store_cart_many = __( 'Cart, %d items', '__textdomain__' );

// An inline SVG from the demo, and nothing else.
$store_cart_svg_attrs = array(
	'class'           => true,
	'fill'            => true,
	'stroke'          => true,
	'stroke-width'    => true,
	'stroke-linecap'  => true,
	'stroke-linejoin' => true,
	'fill-rule'       => true,
	'clip-rule'       => true,
	'transform'       => true,
);
$store_cart_svg_tags  = array(
	'svg'      => $store_cart_svg_attrs + array(
		'xmlns'       => true,
		'viewbox'     => true,
		'width'       => true,
		'height'      => true,
		'aria-hidden' => true,
		'focusable'   => true,
	),
	'g'        => $store_cart_svg_attrs,
	'path'     => $store_cart_svg_attrs + array( 'd' => true ),
	'circle'   => $store_cart_svg_attrs + array(
		'cx' => true,
		'cy' => true,
		'r'  => true,
	),
	'rect'     => $store_cart_svg_attrs + array(
		'x'      => true,
		'y'      => true,
		'width'  => true,
		'height' => true,
		'rx'     => true,
	),
	'line'     => $store_cart_svg_attrs + array(
		'x1' => true,
		'y1' => true,
		'x2' => true,
		'y2' => true,
	),
	'polyline' => $store_cart_svg_attrs + array( 'points' => true ),
	'polygon'  => $store_cart_svg_attrs + array( 'points' => true ),
);
$store_cart_icon = trim( wp_kses( (string) $store_cart['icon'], $store_cart_svg_tags ) );
if ( '' === $store_cart_icon ) {
	$store_cart_icon = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><circle cx="9" cy="21" r="1"/><circle cx="20" cy="21" r="1"/><path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"/></svg>';
}

$store_cart_script = get_theme_file_path( 'assets/js/store-cart.js' );
if ( file_exists( $store_cart_script ) ) {
	wp_enqueue_script( '__textdomain__-store-cart', get_theme_file_uri( 'assets/js/store-cart.js' ), array(), (string) filemtime( $store_cart_script ), true );
}
?>
<a class="store-cart <?php echo esc_attr( $store_cart['link_class'] ); ?>" href="<?php echo esc_url( wc_get_cart_url() ); ?>"
	aria-label="<?php echo esc_attr( sprintf( 1 === $store_cart_count ? $store_cart_one : $store_cart_many, $store_cart_count ) ); ?>"
	data-store-cart="<?php echo esc_url( rest_url( 'wc/store/v1/cart' ) ); ?>"
	data-label-one="<?php echo esc_attr( $store_cart_one ); ?>" data-label-many="<?php echo esc_attr( $store_cart_many ); ?>">
	<?php echo $store_cart_icon; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- wp_kses() above, or the fixed default. ?>
	<span class="store-cart__count <?php echo esc_attr( $store_cart['count_class'] ); ?>" data-store-cart-count<?php echo 0 === $store_cart_count ? ' hidden' : ''; ?>><?php echo esc_html( (string) $store_cart_count ); ?></span>
</a>
