<?php
/**
 * Security baseline — the hardening a delivered site needs whatever server it lands on.
 *
 * Lives in the theme because wp-config.php constants (DISALLOW_FILE_EDIT) and server
 * headers are not in the repository. Same rules as the tailwind starter's
 * inc/security.php; keep the two in step.
 *
 * @package __starter__
 */

defined('ABSPATH') || exit;

// XML-RPC off, pingbacks included: `xmlrpc_enabled` alone leaves pingback.ping callable.
add_filter('xmlrpc_enabled', '__return_false');
add_filter('xmlrpc_methods', '__return_empty_array');

// No RSD link and no X-Pingback header advertising the endpoint.
remove_action('wp_head', 'rsd_link');
add_filter('wp_headers', function ($headers) {
    unset($headers['X-Pingback']);
    return $headers;
});

// REST user routes hidden from anyone who cannot write posts. `edit_posts`, not
// `list_users`: the block editor's author selector reads them, and an Editor has no list_users.
add_filter('rest_endpoints', function ($endpoints) {
    if (current_user_can('edit_posts')) {
        return $endpoints;
    }
    foreach (array_keys($endpoints) as $route) {
        if (strpos($route, '/wp/v2/users') === 0) {
            unset($endpoints[$route]);
        }
    }
    return $endpoints;
});

// `?author=N` and author archives 404 instead of redirecting to /author/<login>/.
// Priority 1: redirect_canonical (priority 10) is what performs that redirect.
add_action('template_redirect', function () {
    if (is_admin() || (!is_author() && !isset($_GET['author']))) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
        return;
    }
    global $wp_query;
    $wp_query->set_404();
    status_header(404);
    nocache_headers();
}, 1);

// No theme/plugin file editor: wp-config.php is not deployed with the repository.
add_filter('map_meta_cap', function ($caps, $cap) {
    if (in_array($cap, ['edit_themes', 'edit_plugins', 'edit_files'], true)) {
        $caps[] = 'do_not_allow';
    }
    return $caps;
}, 10, 2);

// Front-end response headers. Geolocation is left alone: an embedded map may use it.
// A vhost that also sets them sends two copies; check the live response, keep one source.
add_action('send_headers', function () {
    if (headers_sent()) {
        return;
    }
    header('X-Content-Type-Options: nosniff');
    header('X-Frame-Options: SAMEORIGIN');
    header('Referrer-Policy: strict-origin-when-cross-origin');
    header('Permissions-Policy: camera=(), microphone=(), payment=(), usb=()');
    header_remove('X-Powered-By');
});
