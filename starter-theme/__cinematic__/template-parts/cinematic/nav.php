<?php
/**
 * Cinematic nav: lockup + hamburger + motion-toggle.
 *
 * @package __starter__
 */

defined('ABSPATH') || exit;

$lang     = __starter___current_lang();
$location = 'primary-' . $lang;
$logo     = __starter___setting('site_logo');
?>
<nav class="nav" aria-label="<?php echo esc_attr__('Primary', '__TEXTDOMAIN__'); ?>">
    <a class="nav__lockup" href="<?php echo esc_url(home_url('/')); ?>" aria-label="<?php echo esc_attr(get_bloginfo('name')); ?>">
        <?php if ($logo) : ?>
            <img src="<?php echo esc_url($logo); ?>" alt="<?php echo esc_attr(get_bloginfo('name')); ?>" width="600" height="160">
        <?php else : ?>
            <span class="nav__wordmark"><?php bloginfo('name'); ?></span>
        <?php endif; ?>
    </a>

    <div class="nav__links" role="navigation">
        <?php
        if (has_nav_menu($location)) {
            wp_nav_menu([
                'theme_location' => $location,
                'container'      => false,
                'menu_class'     => 'nav__menu',
                'depth'          => 1,
            ]);
        }
        ?>
    </div>

    <button class="nav__hamburger" type="button" aria-expanded="false" aria-controls="mobile-menu" aria-label="<?php echo esc_attr__('Open menu', '__TEXTDOMAIN__'); ?>">
        <span class="nav__hamburger-bars" aria-hidden="true"></span>
    </button>
</nav>

<div id="mobile-menu" class="mobile-menu" role="dialog" aria-modal="true" aria-hidden="true">
    <button class="mobile-menu__close" type="button" aria-label="<?php echo esc_attr__('Close menu', '__TEXTDOMAIN__'); ?>">×</button>

    <nav class="mobile-menu__nav" aria-label="<?php echo esc_attr__('Mobile primary', '__TEXTDOMAIN__'); ?>">
        <?php
        if (has_nav_menu($location)) {
            wp_nav_menu([
                'theme_location' => $location,
                'container'      => false,
                'menu_class'     => 'mobile-menu__list',
                'depth'          => 1,
            ]);
        }
        ?>
    </nav>

    <div class="mobile-menu__controls">
        <div class="mobile-menu__lang-row">
            <a class="mobile-menu__lang-item<?php echo $lang === 'en' ? ' is-active' : ''; ?>" href="<?php echo esc_url(add_query_arg('lang', 'en')); ?>">EN</a>
            <a class="mobile-menu__lang-item<?php echo $lang === 'es' ? ' is-active' : ''; ?>" href="<?php echo esc_url(add_query_arg('lang', 'es')); ?>">ES</a>
        </div>
        <button class="nav__motion-toggle mobile-menu__motion-btn" type="button" data-state="play">
            <?php echo esc_html(__starter___b('Pause motion', 'Pausar movimiento')); ?>
        </button>
    </div>
</div>
