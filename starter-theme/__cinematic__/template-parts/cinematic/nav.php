<?php
/**
 * Cinematic nav: lockup + hamburger + motion-toggle.
 *
 * @package __starter__
 */

defined('ABSPATH') || exit;

$location = __starter___nav_location('primary'); // primary-<lang>, or bare under Polylang
$logo     = __starter___setting('site_logo');
?>
<nav class="nav" aria-label="<?php echo esc_attr__('Primary', '__starter__'); ?>">
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
        <button class="nav__motion-toggle" type="button" data-state="play" data-label-pause="<?php echo esc_attr(__starter___b('Pause motion', 'Pausar movimiento')); ?>" data-label-play="<?php echo esc_attr(__starter___b('Play motion', 'Reproducir movimiento')); ?>">
            <?php echo esc_html(__starter___b('Pause motion', 'Pausar movimiento')); ?>
        </button>
    </div>

    <button class="nav__hamburger" type="button" aria-expanded="false" aria-controls="mobile-menu" aria-label="<?php echo esc_attr__('Open menu', '__starter__'); ?>">
        <span class="nav__hamburger-bars" aria-hidden="true"></span>
    </button>
</nav>

<div id="mobile-menu" class="mobile-menu" role="dialog" aria-modal="true" aria-hidden="true" inert>
    <button class="mobile-menu__close" type="button" aria-label="<?php echo esc_attr__('Close menu', '__starter__'); ?>">×</button>

    <nav class="mobile-menu__nav" aria-label="<?php echo esc_attr__('Mobile primary', '__starter__'); ?>">
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
            <?php foreach (__starter___lang_switcher() as $item) : ?>
                <a class="mobile-menu__lang-item<?php echo $item['active'] ? ' is-active' : ''; ?>" href="<?php echo esc_url($item['url']); ?>"><?php echo esc_html($item['label']); ?></a>
            <?php endforeach; ?>
        </div>
        <button class="nav__motion-toggle mobile-menu__motion-btn" type="button" data-state="play" data-label-pause="<?php echo esc_attr(__starter___b('Pause motion', 'Pausar movimiento')); ?>" data-label-play="<?php echo esc_attr(__starter___b('Play motion', 'Reproducir movimiento')); ?>">
            <?php echo esc_html(__starter___b('Pause motion', 'Pausar movimiento')); ?>
        </button>
    </div>
</div>
