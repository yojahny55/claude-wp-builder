<?php
/**
 * Main Navigation
 *
 * @package __starter__
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}
?>
<nav class="main-navigation" role="navigation" aria-label="<?php esc_attr_e('Main menu', '__starter__'); ?>">
    <?php
    // The registered name depends on the i18n strategy (primary-en under the
    // suffix model, a bare `primary` under Polylang); inc/i18n.php knows which.
    // A name built here instead renders nothing on the other strategy.
    wp_nav_menu( array(
        'theme_location' => __starter___nav_location( 'primary' ),
        'container' => false,
        'menu_class' => 'primary-menu',
        'items_wrap' => '<ul role="menubar">%3$s</ul>',
        'fallback_cb' => false,
    ) );
    ?>
</nav>
