# Theme setup and enqueueing code

The PHP behind the setup rules in `wp-theme-standards`. `prefix_` is the project's function
prefix from its `.claude/CLAUDE.md`.

## Contents

- Asset enqueueing — styles, scripts, `wp_localize_script()`
- Page-specific asset enqueueing
- Theme supports and content width
- Custom body classes
- SCF/ACF options page and option fields
- Helper functions
- SVG upload support

---

## Asset Enqueueing

The `Template: tailwind` starter's own callback, in `functions.php` — one compiled
stylesheet and one wp-scripts bundle. Extend this callback; never add a second one, and
never a second stylesheet: fonts and every other rule are compiled into `main.css`.
`PREFIX_` / `prefix-` are the project's prefix and slug (the starter's `__STARTER__` /
`__starter__`, renamed by `/wp-init`).

```php
add_action( 'wp_enqueue_scripts', function() {
    // The compiled Tailwind stylesheet, versioned by its own mtime.
    $css_file = PREFIX_DIR . '/assets/css/dist/main.css';
    if ( file_exists( $css_file ) ) {
        wp_enqueue_style( 'prefix-tailwind', PREFIX_URI . '/assets/css/dist/main.css', array(), filemtime( $css_file ) );
    }

    // style.css carries the theme header only.
    wp_enqueue_style( 'prefix-style', get_stylesheet_uri(), array( 'prefix-tailwind' ), PREFIX_VERSION );

    // The wp-scripts bundle, in the footer; dependencies and version from index.asset.php.
    $js_file = PREFIX_DIR . '/assets/js/dist/index.js';
    if ( file_exists( $js_file ) ) {
        $asset_file = PREFIX_DIR . '/assets/js/dist/index.asset.php';
        $asset      = file_exists( $asset_file ) ? require $asset_file : array( 'dependencies' => array(), 'version' => PREFIX_VERSION );
        wp_enqueue_script( 'prefix-main', PREFIX_URI . '/assets/js/dist/index.js', $asset['dependencies'], $asset['version'], true );
    }
} );
```

A `Template: cinematic` theme enqueues from `inc/cinematic-loader.php` instead; read it
there.

### wp_localize_script() for Passing PHP Data to JavaScript

Use `wp_localize_script()` to safely pass PHP data (dynamic content, URLs, translations) to
a script already enqueued. The starter passes its AJAX data this way:

```php
wp_localize_script( 'prefix-main', 'PREFIX_data', array(
    'ajax_url' => admin_url( 'admin-ajax.php' ),
    'nonce'    => wp_create_nonce( 'prefix_nonce' ),
    'site_url' => home_url( '/' ),
    'lang'     => prefix_get_current_lang(),
) );
```

In JavaScript, read it from the global of that name: `PREFIX_data.lang`.

## Page-Specific Asset Enqueueing

Key page assets on the template file (`is_page_template()`) or `is_front_page()`, never on
a slug: under Polylang each language is its own post with its own slug. Inside the same
callback:

```php
if ( is_page_template( 'page-<name>.php' ) ) {
    $js_file = PREFIX_DIR . '/assets/js/<name>.js';
    wp_enqueue_script( 'prefix-<name>', PREFIX_URI . '/assets/js/<name>.js', array( 'prefix-main' ), filemtime( $js_file ), true );
}
```

On `Template: tailwind` a page's styles are not a second file: they are a
`components/<name>.css` compiled into `main.css` (`wp-tailwind-system`).

---

## Theme Supports

Register all required theme features inside an `after_setup_theme` hook.

```php
function prefix_setup() {
    // Let WordPress manage the document <title>
    add_theme_support('title-tag');

    // Enable featured images
    add_theme_support('post-thumbnails');

    // Custom logo support
    add_theme_support('custom-logo', array(
        'height'      => 100,
        'width'       => 340,
        'flex-height' => true,
        'flex-width'  => true,
    ));

    // HTML5 markup for core elements
    add_theme_support('html5', array(
        'search-form',
        'comment-form',
        'comment-list',
        'gallery',
        'caption',
        'style',
        'script',
    ));

    // RSS feed links in <head>
    add_theme_support('automatic-feed-links');

    // Register navigation menus
    register_nav_menus(array(
        'primary' => __('Primary Navigation', 'theme-slug'),
        'footer'  => __('Footer Navigation', 'theme-slug'),
    ));
}
add_action('after_setup_theme', 'prefix_setup');
```

### Content Width

Set the global content width for embeds and images.

```php
function prefix_content_width() {
    $GLOBALS['content_width'] = apply_filters('prefix_content_width', 1280);
}
add_action('after_setup_theme', 'prefix_content_width', 0);
```

---

## Custom Body Classes

Add contextual CSS classes to the `<body>` tag for page-specific styling. The starter
already declares `prefix_body_classes()` in `inc/template-functions.php`; extend that
function — a second `body_class` callback of the same name is a duplicate-declaration fatal.
Key each class on the template, never on a slug:

```php
function prefix_body_classes( $classes ) {
    if ( is_front_page() ) {
        $classes[] = 'home-page';
    }
    if ( is_page_template( 'page-<name>.php' ) ) {
        $classes[] = '<name>-page';
    }
    if ( is_singular( 'post' ) ) {
        $classes[] = 'single-post-page';
    }
    if ( is_archive() ) {
        $classes[] = 'archive-page';
    }
    return $classes;
}
add_filter( 'body_class', 'prefix_body_classes' );
```

---

## SCF/ACF as Required Dependency

All themes built with this system use **Secure Custom Fields (SCF)** or **Advanced Custom Fields (ACF)** as the custom fields plugin. SCF is an ACF-compatible fork and uses the same API (`get_field()`, `the_field()`, `have_rows()`, etc.).

### Options Page Registration

One options page holds the site-wide settings (logo, footer content, social links). The
starter registers it in `functions.php`; a theme built from it already has it, and a
second registration is a second menu entry:

```php
add_action( 'acf/init', function() {
    if ( function_exists( 'acf_add_options_page' ) ) {
        acf_add_options_page( array(
            'page_title' => 'Site Name Settings',
            'menu_title' => 'Site Name',
            'menu_slug'  => 'prefix-settings',
            'capability' => 'manage_options',
            'redirect'   => false,
            'icon_url'   => 'dashicons-admin-customizer',
            'position'   => 2,
        ) );
    }
} );
```

### Retrieving Option Fields

Through the i18n seam, like every other field read — `prefix_get_field()`, never raw
`get_field()`, so an options field that carries `_<lang>` suffixes resolves to the visitor's
language:

```php
// Options page fields use 'option' as the post ID
$logo        = prefix_get_field( 'site_logo', 'option' );
$footer_text = prefix_get_field( 'footer_copyright', 'option' );
```

---

## Helper Functions

Create small utility functions to keep templates clean. Both ship in the starter's
`functions.php`:

```php
/**
 * Get theme asset URL
 */
function prefix_asset( $path ) {
    return PREFIX_URI . '/assets/' . ltrim( $path, '/' );
}

/**
 * Get the site logo URL: the settings field first, then the Customizer logo.
 */
function prefix_get_logo( $post_id = 'option' ) {
    $logo = prefix_get_field( 'site_logo', $post_id );
    if ( $logo && is_array( $logo ) ) {
        return $logo['url'];
    }
    $custom_logo_id = get_theme_mod( 'custom_logo' );
    if ( $custom_logo_id ) {
        return wp_get_attachment_image_url( $custom_logo_id, 'full' );
    }
    return '';
}
```

## SVG Upload Support

```php
function prefix_allow_svg_upload($mimes, $user = null) {
    // `get_allowed_mime_types()` passes the user the list is being built FOR, which
    // is not always the current one: a CLI or programmatic upload runs on behalf of
    // another account. Resolve the capability the same way core does one line above
    // this filter, or the gate answers for the wrong user in both directions.
    $allowed = $user ? user_can($user, 'unfiltered_html') : current_user_can('unfiltered_html');
    if (!$allowed) {
        return $mimes;
    }
    $mimes['svg']  = 'image/svg+xml';
    $mimes['svgz'] = 'image/svg+xml';
    return $mimes;
}
add_filter('upload_mimes', 'prefix_allow_svg_upload', 10, 2);

function prefix_fix_svg_display() {
    echo '<style>
        .attachment-266x266, .thumbnail img {
            width: 100% !important;
            height: auto !important;
        }
    </style>';
}
add_action('admin_head', 'prefix_fix_svg_display');
```

No `wp_check_filetype_and_ext` filter goes with it. One that returns the type from the file
name answers for every upload and switches off core's content check for all file types; the
starter ships the gated mime filter alone.
