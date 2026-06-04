<?php
/**
 * Cinematic engine loader.
 *
 * - Detects cinematic pages and adds body classes
 * - Enqueues stage CSS + engine JS with proper deferral
 * - Declares jsDelivr preconnect for GSAP/Lenis CDN
 * - Server-side mobile hint via UA sniff (re-evaluated client-side on resize)
 * - Reduced-motion: engine never enqueues if user prefers reduced motion
 *
 * @package __starter__
 */

defined('ABSPATH') || exit;

/**
 * True when current request renders cinematic content.
 * Override via filter: `__starter___is_cinematic`.
 */
function __starter___is_cinematic(): bool {
    $is = is_front_page() || is_page_template('templates/cinematic.php');
    return (bool) apply_filters('__starter___is_cinematic', $is);
}

add_filter('body_class', function (array $classes): array {
    if (! __starter___is_cinematic()) {
        return $classes;
    }
    $classes[] = 'has-cinematic';

    // Server-side mobile hint — engine re-evaluates on client resize.
    $ua = isset($_SERVER['HTTP_USER_AGENT']) ? sanitize_text_field(wp_unslash($_SERVER['HTTP_USER_AGENT'])) : '';
    if ($ua && preg_match('/Mobile|Android|iPhone|iPad/i', $ua)) {
        $classes[] = 'is-mobile-cinematic';
    }

    // Hybrid pages carry trailing flex sections.
    if (function_exists('have_rows') && have_rows('trailing_sections')) {
        $classes[] = 'has-trailing';
    }

    return $classes;
});

add_action('wp_head', function () {
    if (! __starter___is_cinematic()) {
        return;
    }
    echo '<link rel="preconnect" href="https://cdn.jsdelivr.net" crossorigin>' . "\n";
    // Inline reduced-motion guard runs BEFORE engine JS so we can bail early.
    echo "<script>(function(){if(window.matchMedia&&matchMedia('(prefers-reduced-motion: reduce)').matches){document.documentElement.classList.add('prefers-reduced-motion');}})();</script>\n";
}, 1);

add_action('wp_enqueue_scripts', function () {
    wp_enqueue_style(
        '__starter__-cinematic',
        __STARTER___THEME_URI . '/assets/css/cinematic.css',
        [],
        __STARTER___VERSION
    );

    if (! __starter___is_cinematic()) {
        return;
    }

    // Engine is loaded deferred. The script itself decides whether to boot
    // (skips on prefers-reduced-motion and on mobile, where it uses IO instead).
    wp_enqueue_script(
        '__starter__-cinematic-engine',
        __STARTER___THEME_URI . '/assets/js/cinematic-engine.js',
        [],
        __STARTER___VERSION,
        true
    );
});

// Defer the engine script (vs. async — we want execution after DOMContentLoaded).
add_filter('script_loader_tag', function ($tag, $handle) {
    if ($handle === '__starter__-cinematic-engine' && strpos($tag, ' defer') === false) {
        return str_replace(' src=', ' defer src=', $tag);
    }
    return $tag;
}, 10, 2);
