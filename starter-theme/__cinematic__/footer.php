<?php
/**
 * @package __starter__
 */

defined('ABSPATH') || exit;
?>
<footer class="site-footer" role="contentinfo">
    <div class="site-footer__inner">
        <p class="site-footer__credit">
            &copy; <?php echo esc_html((string) gmdate('Y')); ?> <?php bloginfo('name'); ?>
        </p>
        <?php
        $loc = __starter___nav_location('footer'); // footer-<lang>, or bare under Polylang
        if (has_nav_menu($loc)) {
            wp_nav_menu([
                'theme_location' => $loc,
                'container'      => false,
                'menu_class'     => 'site-footer__menu',
                'depth'          => 1,
            ]);
        }
        ?>
    </div>
</footer>
<?php wp_footer(); ?>
</body>
</html>
