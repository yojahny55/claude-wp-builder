<?php
/**
 * Fixture template for tests/checks/theme-template-check.sh.
 *
 * @package fixture
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}
?>
<div class="flex mt-4 md:grid card__title js-toggle text-block">
	<button class="group" aria-expanded="false">
		<span class="group-aria-[expanded=false]:rotate-90 bg-brand">+</span>
	</button>
	<p class="<?php echo esc_attr( $classes ); ?>">runtime</p>
</div>
<?php
echo '<a class="flex ' . esc_attr( $extra ) . '">x</a>';
