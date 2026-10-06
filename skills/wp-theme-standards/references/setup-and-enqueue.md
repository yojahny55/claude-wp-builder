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

### Styles

```php
function prefix_scripts() {
    // Google Fonts (external, no version needed)
    wp_enqueue_style(
        'prefix-fonts',
        'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap',
        array(),
        null
    );

    // Main stylesheet with filemtime() cache busting
    wp_enqueue_style(
        'prefix-style',
        get_template_directory_uri() . '/assets/css/styles.css',
        array('prefix-fonts'),
        filemtime(get_template_directory() . '/assets/css/styles.css')
    );
}
add_action('wp_enqueue_scripts', 'prefix_scripts');
```

### Scripts

```php
// Main JavaScript — loaded in footer (last param = true)
wp_enqueue_script(
    'prefix-main',
    get_template_directory_uri() . '/assets/js/main.js',
    array(),
    filemtime(get_template_directory() . '/assets/js/main.js'),
    true
);
```

### wp_localize_script() for Passing PHP Data to JavaScript

Use `wp_localize_script()` to safely pass PHP data (dynamic content, URLs, translations) to JavaScript.

```php
// Pass calculator data to JS on the pricing page
if (is_page('pricing')) {
    $calculator_data = prefix_get_calculator_data();
    wp_localize_script('prefix-main', 'prefixCalculator', $calculator_data);
}

// Pass i18n data to JS for all pages
wp_localize_script('prefix-main', 'prefixI18n', array(
    'currentLang' => prefix_get_current_lang(),
    'strings'     => prefix_get_js_translations(),
));
```

In JavaScript, access the data via the global variable name:

```js
console.log(prefixCalculator.setupOptions);
console.log(prefixI18n.currentLang); // 'en' or 'es'
```

## Page-Specific Asset Enqueueing

Load page-specific CSS and JS only when needed using `is_page_template()` or `is_page()`.

```php
function prefix_scripts() {
    // ... main styles/scripts ...

    // Software page: dedicated CSS + JS
    if (is_page_template('page-software.php')) {
        wp_enqueue_style(
            'prefix-software-style',
            get_template_directory_uri() . '/assets/css/software.css',
            array('prefix-style'),
            filemtime(get_template_directory() . '/assets/css/software.css')
        );
        wp_enqueue_script(
            'prefix-software-js',
            get_template_directory_uri() . '/assets/js/software.js',
            array('prefix-main'),
            filemtime(get_template_directory() . '/assets/js/software.js'),
            true
        );
    }
}
add_action('wp_enqueue_scripts', 'prefix_scripts');
```

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

Add contextual CSS classes to the `<body>` tag for page-specific styling.

```php
function prefix_body_classes($classes) {
    if (is_front_page()) {
        $classes[] = 'home-page';
    }
    if (is_page('pricing')) {
        $classes[] = 'pricing-page';
    }
    if (is_page_template('page-software.php')) {
        $classes[] = 'software-page';
    }
    if (is_singular('post')) {
        $classes[] = 'single-post-page';
    }
    if (is_archive()) {
        $classes[] = 'archive-page';
    }
    return $classes;
}
add_filter('body_class', 'prefix_body_classes');
```

---

## SCF/ACF as Required Dependency

All themes built with this system use **Secure Custom Fields (SCF)** or **Advanced Custom Fields (ACF)** as the custom fields plugin. SCF is an ACF-compatible fork and uses the same API (`get_field()`, `the_field()`, `have_rows()`, etc.).

### Options Page Registration

Register an options page for site-wide settings (logo, footer content, social links, etc.).

```php
function prefix_register_options_page() {
    if (function_exists('acf_add_options_page')) {
        acf_add_options_page(array(
            'page_title' => 'Site Settings',
            'menu_title' => 'Site Settings',
            'menu_slug'  => 'prefix-settings',
            'capability' => 'edit_posts',
            'redirect'   => false,
            'icon_url'   => 'dashicons-admin-generic',
            'position'   => 30,
        ));
    }
}
add_action('acf/init', 'prefix_register_options_page');
```

### Retrieving Option Fields

```php
// Options page fields use 'option' as the post ID
$logo = get_field('site_logo', 'option');
$footer_text = get_field('footer_copyright', 'option');
```

---

## Helper Functions

Create small utility functions to keep templates clean.

```php
/**
 * Get theme asset URL
 */
function prefix_asset($path) {
    return get_template_directory_uri() . '/assets/' . ltrim($path, '/');
}

/**
 * Get site logo with fallback
 */
function prefix_get_logo() {
    $logo = get_field('site_logo', 'option');
    if ($logo) {
        return $logo;
    }
    return prefix_asset('images/logo.svg');
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

function prefix_check_filetype($data, $file, $filename, $mimes) {
    $filetype = wp_check_filetype($filename, $mimes);
    return array(
        'ext'             => $filetype['ext'],
        'type'            => $filetype['type'],
        'proper_filename' => $data['proper_filename'],
    );
}
add_filter('wp_check_filetype_and_ext', 'prefix_check_filetype', 10, 4);
```
