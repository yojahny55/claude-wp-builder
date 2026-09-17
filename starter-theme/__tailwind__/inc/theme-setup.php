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
function __starter___allow_svg_upload($mimes, $user = null) {
    // `get_allowed_mime_types()` passes the user the list is being built FOR, which
    // is not always the current one: a CLI or programmatic upload runs on behalf of
    // another account. Resolve the capability the same way core does one line above
    // this filter, or the gate answers for the wrong user in both directions.
    $allowed = $user ? user_can($user, 'unfiltered_html') : current_user_can('unfiltered_html');
    if (!$allowed) {
        return $mimes;
    }
    $mimes['svg'] = 'image/svg+xml';
    $mimes['svgz'] = 'image/svg+xml';
    return $mimes;
}
add_filter('upload_mimes', '__starter___allow_svg_upload', 10, 2);

// Body classes (lang / template / front-page) are added by __starter___body_classes()
// in inc/template-functions.php — kept in one place to avoid a duplicate-declaration fatal.

/**
 * Stop WordPress 404-ing its own sitemap.
 *
 * `WP::handle_404()` clears the 404 only when the query matched something: it
 * exempts admin, robots and favicon by name, and otherwise wants `$wp_query->posts`
 * to be non-empty. A sitemap route carries no post query of its own, so on a site
 * that publishes the built-in `post` type it survives by accident — the default
 * "latest posts" query behind it returns those posts. A project with no native
 * `post` content at all (everything modeled as a custom post type) gets an empty
 * query, core marks the request 404, and `WP_Sitemaps::render_sitemaps()` goes on
 * to print a perfectly valid sitemap on `template_redirect` immediately afterwards.
 * The result is a correct XML body served under a 404 status line, which every
 * crawler reads as "no sitemap" — and robots.txt is advertising that URL.
 *
 * `pre_handle_404` is core's own escape hatch for exactly this, so the fix reaches
 * for it rather than into `WP::handle_404()` or a routing plugin. Also exempts the
 * per-sitemap stylesheet route for the same reason.
 */
add_filter('pre_handle_404', function ($preempt, $query) {
    if ($preempt) {
        return $preempt;
    }
    return ($query->get('sitemap') || $query->get('sitemap-stylesheet')) ? true : $preempt;
}, 10, 2);
