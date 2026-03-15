<?php
/**
 * Theme Setup
 *
 * @package __STARTER_NAME__
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

/**
 * Sets up theme defaults and registers support for various WordPress features.
 */
function __starter___setup() {
    // Add default posts and comments RSS feed links to head.
    add_theme_support('automatic-feed-links');

    // Let WordPress manage the document title.
    add_theme_support('title-tag');

    // Enable support for Post Thumbnails on posts and pages.
    add_theme_support('post-thumbnails');

    // Custom logo support
    add_theme_support('custom-logo', array(
        'height'      => 100,
        'width'       => 340,
        'flex-height' => true,
        'flex-width'  => true,
    ));

    // Switch default core markup to output valid HTML5.
    add_theme_support('html5', array(
        'search-form',
        'comment-form',
        'comment-list',
        'gallery',
        'caption',
        'style',
        'script',
    ));

    // Add theme support for selective refresh for widgets.
    add_theme_support('customize-selective-refresh-widgets');

    // Register navigation menus (per-language)
    register_nav_menus(array(
        'primary-en'   => __('Primary Navigation (EN)', '__starter__'),
        'primary-es'   => __('Primary Navigation (ES)', '__starter__'),
        'mobile-en'    => __('Mobile Navigation (EN)', '__starter__'),
        'mobile-es'    => __('Mobile Navigation (ES)', '__starter__'),
        'footer-links' => __('Footer Links', '__starter__'),
    ));
}
add_action('after_setup_theme', '__starter___setup');

/**
 * Set the content width in pixels
 */
function __starter___content_width() {
    $GLOBALS['content_width'] = apply_filters('__starter___content_width', 1280);
}
add_action('after_setup_theme', '__starter___content_width', 0);

/**
 * Remove WordPress emoji scripts for performance
 */
function __starter___disable_emojis() {
    remove_action('wp_head', 'print_emoji_detection_script', 7);
    remove_action('admin_print_scripts', 'print_emoji_detection_script');
    remove_action('wp_print_styles', 'print_emoji_styles');
    remove_action('admin_print_styles', 'print_emoji_styles');
    remove_filter('the_content_feed', 'wp_staticize_emoji');
    remove_filter('comment_text_rss', 'wp_staticize_emoji');
    remove_filter('wp_mail', 'wp_staticize_emoji_for_email');
}
add_action('init', '__starter___disable_emojis');

/**
 * Remove WordPress version from head
 */
remove_action('wp_head', 'wp_generator');

/**
 * Allow SVG uploads
 */
function __starter___allow_svg_upload($mimes) {
    $mimes['svg'] = 'image/svg+xml';
    $mimes['svgz'] = 'image/svg+xml';
    return $mimes;
}
add_filter('upload_mimes', '__starter___allow_svg_upload');

/**
 * Add custom body classes
 */
function __starter___body_classes($classes) {
    // Add language class
    if (function_exists('__starter___get_current_lang')) {
        $classes[] = 'lang-' . __starter___get_current_lang();
    }

    // Add page template class
    if (is_page_template()) {
        $template = get_page_template_slug();
        $template_class = str_replace(array('.php', '/'), array('', '-'), $template);
        $classes[] = 'template-' . $template_class;
    }

    if (is_front_page()) {
        $classes[] = 'home-page';
    }

    return $classes;
}
add_filter('body_class', '__starter___body_classes');
