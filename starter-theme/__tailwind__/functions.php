<?php
/**
 * __STARTER_NAME__ — Functions and definitions
 *
 * @package __starter__
 */

// Theme constants
define( '__STARTER___VERSION', '1.0.0' );
define( '__STARTER___DIR', get_template_directory() );
define( '__STARTER___URI', get_template_directory_uri() );

// Core includes
require_once __STARTER___DIR . '/inc/i18n.php';
require_once __STARTER___DIR . '/inc/theme-setup.php';
require_once __STARTER___DIR . '/inc/cf7-helpers.php';
require_once __STARTER___DIR . '/inc/nav-walker.php';
require_once __STARTER___DIR . '/inc/template-tags.php';
require_once __STARTER___DIR . '/inc/template-functions.php';
require_once __STARTER___DIR . '/inc/performance.php';

/**
 * Field groups use ACF/SCF Local JSON (acf-json/) as the single source of truth
 * so they stay editable in the dashboard AND versioned in code — dashboard edits
 * (including manually added fields) sync back to the JSON files.
 *
 * fields/*.php are a one-time bootstrap: on the first load with no JSON yet, they
 * register the groups and get persisted to acf-json/. Once JSON exists it is the
 * only source loaded — re-running the PHP would re-register the same keys as
 * read-only PHP-local groups and shadow the editable JSON copies.
 */
add_action( 'acf/init', function() {
    $json_dir   = __STARTER___DIR . '/acf-json';
    $fields_dir = __STARTER___DIR . '/fields';
    if ( ! is_dir( $fields_dir ) ) { return; }
    if ( ! is_dir( $json_dir ) ) { wp_mkdir_p( $json_dir ); }

    // Bootstrap each group from PHP only if it isn't already Local JSON. A group
    // that has a acf-json/<key>.json is the source of truth (dashboard edits sync
    // there); re-running its PHP would re-register it read-only and shadow edits.
    $bootstrapped = false;
    foreach ( glob( $fields_dir . '/*.php' ) as $file ) {
        if ( ! is_readable( $file ) ) { continue; }
        $src = file_get_contents( $file );
        if ( preg_match_all( "/'key'\\s*=>\\s*'(group_[A-Za-z0-9_]+)'/", $src, $m ) ) {
            $pending = false;
            foreach ( $m[1] as $key ) {
                if ( ! file_exists( "$json_dir/$key.json" ) ) { $pending = true; break; }
            }
            if ( ! $pending ) { continue; } // every group in this file already has JSON
        }
        require_once $file;
        $bootstrapped = true;
    }

    // Steady state — every group already has JSON: nothing to persist, so skip
    // the scan entirely. An unwritable acf-json/ degrades to read-only PHP
    // groups instead of emitting warnings on every request.
    if ( ! $bootstrapped || ! is_writable( $json_dir ) ) {
        return;
    }

    // One writer at a time: two concurrent first loads would both write the same
    // files, and a half-written JSON reads back as a corrupt field group.
    $lock = fopen( $json_dir . '/.bootstrap.lock', 'c' );
    if ( ! $lock || ! flock( $lock, LOCK_EX | LOCK_NB ) ) {
        return; // another request is bootstrapping; it finishes the write.
    }

    // Persist any freshly-registered PHP-local group to Local JSON (editable).
    foreach ( acf_get_field_groups() as $g ) {
        if ( ( $g['local'] ?? '' ) !== 'php' ) { continue; }
        if ( file_exists( "$json_dir/{$g['key']}.json" ) ) { continue; }
        $g['fields'] = acf_get_fields( $g );
        acf_write_json_field_group( acf_prepare_field_group_for_export( $g ) );
    }

    flock( $lock, LOCK_UN );
    fclose( $lock );
});

/**
 * Register ACF/SCF Options Page (Theme Settings).
 */
add_action( 'acf/init', function() {
    if ( function_exists( 'acf_add_options_page' ) ) {
        acf_add_options_page( array(
            'page_title' => '__STARTER_NAME__ Settings',
            'menu_title' => '__STARTER_NAME__',
            'menu_slug'  => '__starter__-settings',
            'capability' => 'manage_options',
            'redirect'   => false,
            'icon_url'   => 'dashicons-admin-customizer',
            'position'   => 2,
        ));
    }
});

/**
 * Show admin notice if ACF/SCF is not active.
 */
add_action( 'admin_notices', function() {
    if ( ! function_exists( 'acf_add_options_page' ) ) {
        echo '<div class="notice notice-error"><p>';
        echo '<strong>__STARTER_NAME__</strong> requires <strong>Advanced Custom Fields</strong> or <strong>Secure Custom Fields</strong> to be installed and activated.';
        echo '</p></div>';
    }
});

/**
 * Enqueue scripts and styles.
 */
add_action( 'wp_enqueue_scripts', function() {
    // Tailwind compiled CSS
    $css_file = __STARTER___DIR . '/assets/css/dist/main.css';
    if ( file_exists( $css_file ) ) {
        wp_enqueue_style(
            '__starter__-tailwind',
            __STARTER___URI . '/assets/css/dist/main.css',
            array(),
            filemtime( $css_file )
        );
    }

    // Theme style.css (WP header only, minimal)
    wp_enqueue_style(
        '__starter__-style',
        get_stylesheet_uri(),
        array( '__starter__-tailwind' ),
        __STARTER___VERSION
    );

    // Compiled JS
    $js_file = __STARTER___DIR . '/assets/js/dist/index.js';
    if ( file_exists( $js_file ) ) {
        $asset_file = __STARTER___DIR . '/assets/js/dist/index.asset.php';
        $asset = file_exists( $asset_file ) ? require $asset_file : array( 'dependencies' => array(), 'version' => __STARTER___VERSION );

        wp_enqueue_script(
            '__starter__-main',
            __STARTER___URI . '/assets/js/dist/index.js',
            $asset['dependencies'],
            $asset['version'],
            true
        );
    }

    // Localization for AJAX
    wp_localize_script( '__starter__-main', '__STARTER___data', array(
        'ajax_url' => admin_url( 'admin-ajax.php' ),
        'nonce'    => wp_create_nonce( '__starter___nonce' ),
        'site_url' => home_url( '/' ),
        'lang'     => __starter___get_current_lang(),
    ));
});

/**
 * Add editor styles for Gutenberg.
 */
add_action( 'after_setup_theme', function() {
    add_editor_style( 'assets/css/editor-style.css' );
});

/**
 * Defer non-critical JS for performance.
 */
add_filter( 'script_loader_tag', function( $tag, $handle, $src ) {
    if ( is_admin() ) {
        return $tag;
    }
    if ( '__starter__-main' === $handle ) {
        return str_replace( ' src', ' defer src', $tag );
    }
    return $tag;
}, 10, 3 );

/**
 * Meta description helper.
 */
add_action( 'wp_head', function() {
    if ( is_front_page() ) {
        $desc = __starter___get_field( 'site_description', 'option' );
        if ( ! $desc ) {
            $desc = get_bloginfo( 'description' );
        }
        if ( $desc ) {
            printf( '<meta name="description" content="%s">' . "\n", esc_attr( $desc ) );
        }
    }
});

/**
 * Preconnect to Google Fonts for performance.
 */
add_action( 'wp_head', function() {
    echo '<link rel="preconnect" href="https://fonts.googleapis.com">' . "\n";
    echo '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>' . "\n";
}, 1 );

/**
 * Asset URL helper.
 */
function __starter___asset( $path ) {
    return __STARTER___URI . '/assets/' . ltrim( $path, '/' );
}

/**
 * Get site logo URL (bilingual).
 */
function __starter___get_logo( $post_id = 'option' ) {
    $logo = __starter___get_field( 'site_logo', $post_id );
    if ( $logo && is_array( $logo ) ) {
        return $logo['url'];
    }
    $custom_logo_id = get_theme_mod( 'custom_logo' );
    if ( $custom_logo_id ) {
        return wp_get_attachment_image_url( $custom_logo_id, 'full' );
    }
    return '';
}
