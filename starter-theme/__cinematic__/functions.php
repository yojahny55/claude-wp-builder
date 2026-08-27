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

// Field groups use ACF/SCF Local JSON (acf-json/) as the single source of truth
// so they stay editable in the dashboard AND versioned in code. fields/*.php are
// a one-time bootstrap: registered on first load with no JSON yet, then persisted
// to acf-json/. Once JSON exists it is the only source loaded (re-running the PHP
// would re-register the same keys as read-only PHP-local groups).
add_action('acf/init', function () {
    $json_dir   = __STARTER___THEME_DIR . '/acf-json';
    $fields_dir = __STARTER___THEME_DIR . '/fields';
    if (!is_dir($fields_dir)) { return; }
    if (!is_dir($json_dir)) { wp_mkdir_p($json_dir); }

    // Bootstrap each group from PHP only if it isn't already Local JSON. A group
    // that has a acf-json/<key>.json is the source of truth (dashboard edits sync
    // there); re-running its PHP would re-register it read-only and shadow edits.
    $bootstrapped = false;
    foreach (glob($fields_dir . '/*.php') as $f) {
        if (!is_readable($f)) { continue; }
        $src = file_get_contents($f);
        if (preg_match_all("/'key'\\s*=>\\s*'(group_[A-Za-z0-9_]+)'/", $src, $m)) {
            $pending = false;
            foreach ($m[1] as $key) {
                if (!file_exists("$json_dir/$key.json")) { $pending = true; break; }
            }
            if (!$pending) { continue; }
        }
        require_once $f;
        $bootstrapped = true;
    }

    // Steady state — every group already has JSON: nothing to persist, so skip
    // the scan entirely. An unwritable acf-json/ degrades to read-only PHP
    // groups instead of emitting warnings on every request.
    if (!$bootstrapped || !is_writable($json_dir)) { return; }

    // One writer at a time: two concurrent first loads would both write the same
    // files, and a half-written JSON reads back as a corrupt field group.
    $lock = fopen($json_dir . '/.bootstrap.lock', 'c');
    if (!$lock || !flock($lock, LOCK_EX | LOCK_NB)) { return; }

    // Persist any freshly-registered PHP-local group to Local JSON (editable).
    foreach (acf_get_field_groups() as $g) {
        if (($g['local'] ?? '') !== 'php') { continue; }
        if (file_exists("$json_dir/{$g['key']}.json")) { continue; }
        $g['fields'] = acf_get_fields($g);
        acf_write_json_field_group(acf_prepare_field_group_for_export($g));
    }

    flock($lock, LOCK_UN);
    fclose($lock);
});
