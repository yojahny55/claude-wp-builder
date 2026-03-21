<?php
/**
 * Main Navigation
 *
 * @package __starter__
 */
?>
<nav class="main-navigation" role="navigation" aria-label="<?php esc_attr_e('Main menu', '__starter__'); ?>">
    <?php
    wp_nav_menu( array(
        'theme_location' => 'primary',
        'container' => false,
        'menu_class' => 'primary-menu',
        'items_wrap' => '<ul role="menubar">%3$s</ul>',
        'fallback_cb' => false,
    ) );
    ?>
</nav>
