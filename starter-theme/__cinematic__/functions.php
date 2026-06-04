<?php
/**
 * __starter__ theme bootstrap.
 *
 * Cinematic scroll-driven theme. Most heavy lifting lives in inc/.
 *
 * @package __starter__
 */

defined('ABSPATH') || exit;

define('__STARTER___VERSION', '__VERSION__');
define('__STARTER___THEME_DIR', get_template_directory());
define('__STARTER___THEME_URI', get_template_directory_uri());

// Core theme supports + nav menus.
add_action('after_setup_theme', function () {
    add_theme_support('title-tag');
    add_theme_support('post-thumbnails');
    add_theme_support('html5', ['search-form', 'comment-form', 'comment-list', 'gallery', 'caption', 'style', 'script']);
    add_theme_support('responsive-embeds');
    add_theme_support('automatic-feed-links');

    load_theme_textdomain('__TEXTDOMAIN__', __STARTER___THEME_DIR . '/languages');

    register_nav_menus([
        'primary-en' => __('Primary Navigation (EN)', '__TEXTDOMAIN__'),
        'primary-es' => __('Primary Navigation (ES)', '__TEXTDOMAIN__'),
        'footer-en'  => __('Footer Navigation (EN)', '__TEXTDOMAIN__'),
        'footer-es'  => __('Footer Navigation (ES)', '__TEXTDOMAIN__'),
    ]);
});

// Includes — order matters: i18n first, then loaders that depend on it.
require_once __STARTER___THEME_DIR . '/inc/i18n.php';
require_once __STARTER___THEME_DIR . '/inc/cinematic-loader.php';
require_once __STARTER___THEME_DIR . '/inc/scenes-renderer.php';
require_once __STARTER___THEME_DIR . '/inc/performance.php';

// ACF auto-loader (drops in fields/*.php).
if (function_exists('acf_add_local_field_group')) {
    foreach (glob(__STARTER___THEME_DIR . '/fields/*.php') as $f) {
        require_once $f;
    }
}
