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
    // inc/theme-setup.php registers one location per language (primary-en,
    // primary-es, …), never a bare `primary`, which would render nothing here.
    wp_nav_menu( array(
        'theme_location' => 'primary-' . __starter___get_current_lang(),
        'container' => false,
        'menu_class' => 'primary-menu',
        'items_wrap' => '<ul role="menubar">%3$s</ul>',
        'fallback_cb' => false,
    ) );
    ?>
</nav>
