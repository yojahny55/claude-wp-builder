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
remove_action('wp_head', 'rsd_link');

// Slow heartbeat to reduce admin-ajax churn.
add_filter('heartbeat_settings', function ($settings) {
    $settings['interval'] = 60;
    return $settings;
});

// Block REST user enumeration.
add_filter('rest_endpoints', function ($endpoints) {
    if (isset($endpoints['/wp/v2/users'])) {
        unset($endpoints['/wp/v2/users']);
    }
    if (isset($endpoints['/wp/v2/users/(?P<id>[\d]+)'])) {
        unset($endpoints['/wp/v2/users/(?P<id>[\d]+)']);
    }
    return $endpoints;
});

// XML-RPC off (cinematic sites have no need for it).
add_filter('xmlrpc_enabled', '__return_false');
