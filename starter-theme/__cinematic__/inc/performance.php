<?php
/**
 * Performance hardening — generic across themes built by claude-wp-builder.
 *
 * @package __starter__
 */

defined('ABSPATH') || exit;

// Remove WP bloat.
remove_action('wp_head', 'print_emoji_detection_script', 7);
remove_action('wp_print_styles', 'print_emoji_styles');
remove_action('wp_head', 'wp_generator');
remove_action('wp_head', 'wlwmanifest_link');

// Slow heartbeat to reduce admin-ajax churn.
add_filter('heartbeat_settings', function ($settings) {
    $settings['interval'] = 60;
    return $settings;
});

// RSD link, XML-RPC and REST user routes: see inc/security.php.

/**
 * Stop WordPress 404-ing its own sitemap.
 *
 * `WP::handle_404()` clears the 404 only when the default query matched posts. A
 * site whose content is all custom post types (this starter ships no blog) gets an
 * empty query on `/wp-sitemap.xml`, so core sends a 404 status line and then
 * prints a valid sitemap body anyway — crawlers read that as "no sitemap" while
 * robots.txt advertises the URL. Same guard as the tailwind starter's
 * inc/theme-setup.php; keep the two in step.
 */
add_filter('pre_handle_404', function ($preempt, $query) {
    if ($preempt) {
        return $preempt;
    }
    return ($query->get('sitemap') || $query->get('sitemap-stylesheet')) ? true : $preempt;
}, 10, 2);
