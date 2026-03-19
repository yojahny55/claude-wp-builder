<?php
/**
 * __STARTER_NAME__ Theme Functions
 *
 * @package __STARTER_NAME__
 * @version 1.0.0
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

// Theme setup
require get_template_directory() . '/inc/theme-setup.php';

// Internationalization (i18n) - must load before field definitions
require get_template_directory() . '/inc/i18n.php';

// Contact Form 7 helpers (placeholder resolution in email templates)
require get_template_directory() . '/inc/cf7-helpers.php';

// Custom nav walker
require get_template_directory() . '/inc/nav-walker.php';

/**
 * Auto-load ACF field definitions from fields/ directory
 */
function __starter___load_acf_fields() {
    $field_files = glob(get_template_directory() . '/fields/*.php');
    if ($field_files) {
        foreach ($field_files as $field_file) {
            require_once $field_file;
        }
    }
}
add_action('acf/init', '__starter___load_acf_fields');

/**
 * Register ACF Options Page for site settings
 */
function __starter___register_options_page() {
    if (function_exists('acf_add_options_page')) {
        acf_add_options_page(array(
            'page_title'    => '__STARTER_NAME__ Settings',
            'menu_title'    => '__STARTER_NAME__ Settings',
            'menu_slug'     => '__starter__-settings',
            'capability'    => 'manage_options',
            'redirect'      => false,
            'icon_url'      => 'dashicons-admin-generic',
            'position'      => 30,
        ));
    }
}
add_action('acf/init', '__starter___register_options_page');

/**
 * Admin notice if SCF/ACF is not active
 */
function __starter___scf_dependency_notice() {
    if (!function_exists('acf_add_local_field_group')) {
        echo '<div class="notice notice-error"><p>';
        echo '<strong>__STARTER_NAME__</strong> requires <a href="https://wordpress.org/plugins/secure-custom-fields/" target="_blank">Secure Custom Fields</a> (or ACF) to be installed and activated.';
        echo '</p></div>';
    }
}
add_action('admin_notices', '__starter___scf_dependency_notice');

/**
 * Enqueue scripts and styles
 */
function __starter___scripts() {
    // Main stylesheet
    wp_enqueue_style(
        '__starter__-style',
        get_template_directory_uri() . '/assets/css/styles.css',
        array(),
        filemtime(get_template_directory() . '/assets/css/styles.css')
    );

    // Main JavaScript
    wp_enqueue_script(
        '__starter__-main',
        get_template_directory_uri() . '/assets/js/main.js',
        array(),
        filemtime(get_template_directory() . '/assets/js/main.js'),
        true
    );

    // Pass theme data to JS
    wp_localize_script('__starter__-main', 'themeData', array(
        'lang'    => function_exists('__starter___get_current_lang') ? __starter___get_current_lang() : 'en',
        'langs'   => array('en', 'es'),
        'ajaxUrl' => admin_url('admin-ajax.php'),
    ));
}
add_action('wp_enqueue_scripts', '__starter___scripts');

/**
 * Add meta description for SEO
 */
function __starter___add_meta_description() {
    // Skip if Yoast or RankMath is handling this
    if (defined('WPSEO_VERSION') || defined('RANK_MATH_VERSION')) {
        return;
    }

    $description = '';

    if (is_front_page()) {
        $description = get_bloginfo('description');
    } elseif (is_singular()) {
        $post = get_post();
        if ($post) {
            $description = has_excerpt($post->ID)
                ? get_the_excerpt($post)
                : wp_trim_words(strip_tags($post->post_content), 30, '...');
        }
    }

    if ($description) {
        echo '<meta name="description" content="' . esc_attr($description) . '">' . "\n";
    }
}
add_action('wp_head', '__starter___add_meta_description', 1);

/**
 * Add font preconnect for performance
 */
function __starter___add_preconnect() {
    echo '<link rel="preconnect" href="https://fonts.googleapis.com">' . "\n";
    echo '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>' . "\n";
}
add_action('wp_head', '__starter___add_preconnect', 1);

/**
 * Preload LCP image on front page
 */
function __starter___preload_lcp_image() {
    if (is_front_page() && function_exists('get_field')) {
        $hero_image = __starter___get_field('hero_image');
        if ($hero_image && is_array($hero_image) && !empty($hero_image['url'])) {
            echo '<link rel="preload" as="image" href="' . esc_url($hero_image['url']) . '">' . "\n";
        }
    }
}
add_action('wp_head', '__starter___preload_lcp_image', 2);

/**
 * Helper function to get theme asset URL
 *
 * @param string $path Relative path within assets/ directory
 * @return string Full URL to the asset
 */
function __starter___asset($path) {
    return get_template_directory_uri() . '/assets/' . ltrim($path, '/');
}

/**
 * Helper function to get site logo (language-aware)
 *
 * @return string|array Logo URL or ACF image array
 */
function __starter___get_logo() {
    if (!function_exists('acf_add_local_field_group')) {
        return __starter___asset('images/logo.svg');
    }

    $lang = __starter___get_current_lang();

    // Check for Spanish logo if in Spanish mode
    if ($lang === 'es') {
        $logo_es = get_field('site_logo_es', 'option');
        if ($logo_es) {
            return $logo_es;
        }
    }

    // Fallback to default logo
    $logo = get_field('site_logo', 'option');
    if ($logo) {
        return $logo;
    }

    return __starter___asset('images/logo.svg');
}
