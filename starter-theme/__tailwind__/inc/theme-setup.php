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
        'footer-en'    => __('Footer Links (EN)', '__starter__'),
        'footer-es'    => __('Footer Links (ES)', '__starter__'),
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
 * Allow SVG uploads — administrators only.
 *
 * WordPress serves an uploaded SVG straight from the uploads directory, so a
 * browser opening one executes any script it carries in the site's OWN origin.
 * Granting the mime type to everyone who can upload media therefore hands
 * stored XSS to the Author role. `unfiltered_html` is the capability WordPress
 * already uses for "may post markup that is trusted verbatim".
 */
function __starter___allow_svg_upload($mimes) {
    if (!current_user_can('unfiltered_html')) {
        return $mimes;
    }
    $mimes['svg'] = 'image/svg+xml';
    $mimes['svgz'] = 'image/svg+xml';
    return $mimes;
}
add_filter('upload_mimes', '__starter___allow_svg_upload');

// Body classes (lang / template / front-page) are added by __starter___body_classes()
// in inc/template-functions.php — kept in one place to avoid a duplicate-declaration fatal.
