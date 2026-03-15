---
name: wp-theme-standards
description: WordPress legacy theme best practices — proper enqueueing, escaping, hooks, security, and performance
user-invocable: false
---

# WordPress Legacy Theme Standards

This skill defines the mandatory standards for building WordPress themes using the **legacy (classic) theme** architecture. No block themes, no Full Site Editing (FSE), no theme.json.

---

## Required Theme Files

Every theme MUST include these files:

| File | Purpose |
|---|---|
| `style.css` | Theme declaration with required headers |
| `index.php` | Fallback template (required by WordPress) |
| `functions.php` | Theme setup, hooks, enqueuing, helpers |
| `screenshot.png` | Theme thumbnail (1200x900px recommended) |

### style.css Headers

The `style.css` file MUST begin with the theme declaration comment. This is how WordPress identifies the theme.

```css
/*
Theme Name:   Starter Theme
Theme URI:    https://example.com
Author:       Developer Name
Author URI:   https://example.com
Description:  A custom legacy WordPress theme.
Version:      1.0.0
License:      GNU General Public License v2 or later
License URI:  https://www.gnu.org/licenses/gpl-2.0.html
Text Domain:  starter
*/
```

> **Note:** Do not put actual styles in `style.css`. Use it only for the header declaration. All styles go in `assets/css/styles.css` (or similar), enqueued via `functions.php`.

---

## Theme Directory Structure

```
theme-name/
├── assets/
│   ├── css/
│   │   └── styles.css          # Main design system stylesheet
│   ├── js/
│   │   └── main.js             # Main client-side JS
│   └── images/                 # Theme images (logo fallback, icons, etc.)
├── inc/
│   ├── theme-setup.php         # Theme supports, nav menus, content width
│   ├── i18n.php                # Internationalization helpers (if bilingual)
│   └── scf-fields.php          # SCF/ACF custom field definitions
├── template-parts/
│   ├── section-hero.php        # Reusable section templates
│   ├── section-services.php
│   └── ...
├── functions.php               # Main functions file (requires inc/ files)
├── header.php                  # Site header
├── footer.php                  # Site footer
├── front-page.php              # Homepage template
├── index.php                   # Fallback template
├── style.css                   # Theme declaration (headers only)
└── screenshot.png              # Theme preview image
```

---

## Asset Enqueueing

**NEVER** add `<link>` or `<script>` tags directly in templates. Always use WordPress enqueueing functions.

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

### Cache Busting

Always use `filemtime()` for the version parameter on local assets. This forces browsers to re-download the file whenever it changes, without manual version bumping.

```php
filemtime(get_template_directory() . '/assets/css/styles.css')
```

For external assets (CDN fonts, libraries), pass `null` as the version to omit the query string.

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

---

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

## Security: Output Escaping

**Every** dynamic value rendered in HTML MUST be escaped. No exceptions.

| Function | Use When | Example |
|---|---|---|
| `esc_html()` | Outputting text content inside HTML tags | `<h1><?php echo esc_html($title); ?></h1>` |
| `esc_url()` | Outputting URLs in href, src, action attributes | `<a href="<?php echo esc_url($link); ?>">` |
| `esc_attr()` | Outputting values inside HTML attributes | `<div class="<?php echo esc_attr($class); ?>">` |
| `wp_kses_post()` | Outputting rich text/HTML that should allow safe tags | `<div><?php echo wp_kses_post($content); ?></div>` |

### Rules

- **Plain text** in tags: `esc_html()`
- **URLs** anywhere: `esc_url()`
- **Attribute values** (class, id, data-*): `esc_attr()`
- **Rich HTML content** from WYSIWYG/editor fields: `wp_kses_post()`
- **Never output raw** `get_field()`, `$_GET`, `$_POST`, or any user input without escaping

---

## Security: Input Sanitization

Sanitize all input before saving to the database.

| Function | Use For |
|---|---|
| `sanitize_text_field()` | Single-line text input |
| `sanitize_textarea_field()` | Multi-line text input |
| `sanitize_email()` | Email addresses |
| `absint()` | Positive integers |
| `sanitize_file_name()` | File names |
| `wp_kses_post()` | Rich HTML (on save) |
| `sanitize_url()` | URL input |

```php
// Example: sanitize URL parameter
if (isset($_GET['lang'])) {
    $lang = sanitize_text_field($_GET['lang']);
}
```

---

## WordPress Hooks Reference

The hooks below are the ones most commonly used in theme development, listed in the order they typically fire.

| Hook | Type | When to Use |
|---|---|---|
| `after_setup_theme` | Action | Register theme supports, nav menus, content width |
| `init` | Action | Register post types, taxonomies, disable emojis |
| `acf/init` | Action | Register ACF/SCF options pages |
| `wp_enqueue_scripts` | Action | Enqueue all frontend CSS and JS |
| `wp_head` | Action | Add meta tags, preconnect hints, schema markup, preload LCP |
| `wp_footer` | Action | Add inline scripts before `</body>` |
| `body_class` | Filter | Add custom CSS classes to `<body>` |
| `upload_mimes` | Filter | Allow additional file types (SVG) |

---

## Querying Posts

**NEVER** use `query_posts()`. It modifies the main query and causes bugs.

**ALWAYS** use `WP_Query` for custom queries.

```php
$args = array(
    'post_type'      => 'post',
    'posts_per_page' => 6,
    'orderby'        => 'date',
    'order'          => 'DESC',
);
$query = new WP_Query($args);

if ($query->have_posts()) :
    while ($query->have_posts()) : $query->the_post();
        get_template_part('template-parts/content', get_post_type());
    endwhile;
    wp_reset_postdata();
endif;
```

Always call `wp_reset_postdata()` after a custom `WP_Query` loop.

---

## No Inline Styles or Scripts

- **Never** add `<style>` blocks in PHP templates
- **Never** add `<script>` blocks in PHP templates
- **Never** use inline `style=""` attributes on elements

All CSS goes in `.css` files. All JS goes in `.js` files. Both are enqueued via `wp_enqueue_scripts`.

The only exceptions are:
- `wp_head` actions for `<meta>` tags, `<link rel="preload">`, and `<script type="application/ld+json">` (schema markup)
- SVG admin display fix in `admin_head` (minimal inline style)

---

## Performance Optimizations

### Font Preconnect

Add preconnect hints for external font providers to speed up loading.

```php
function prefix_add_preconnect() {
    echo '<link rel="preconnect" href="https://fonts.googleapis.com">' . "\n";
    echo '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>' . "\n";
}
add_action('wp_head', 'prefix_add_preconnect', 1);
```

### LCP Image Preloading

Preload the Largest Contentful Paint (LCP) element (usually the hero image) on the homepage.

```php
function prefix_preload_lcp_image() {
    if (is_front_page()) {
        $hero_image = prefix_get_field('hero_image');
        $hero_image_url = $hero_image ? $hero_image['url'] : prefix_asset('images/hero-image.png');
        echo '<link rel="preload" as="image" href="' . esc_url($hero_image_url) . '">' . "\n";
    }
}
add_action('wp_head', 'prefix_preload_lcp_image', 2);
```

### Disable WordPress Emojis

Remove the emoji detection script and styles that WordPress loads on every page.

```php
function prefix_disable_emojis() {
    remove_action('wp_head', 'print_emoji_detection_script', 7);
    remove_action('admin_print_scripts', 'print_emoji_detection_script');
    remove_action('wp_print_styles', 'print_emoji_styles');
    remove_action('admin_print_styles', 'print_emoji_styles');
    remove_filter('the_content_feed', 'wp_staticize_emoji');
    remove_filter('comment_text_rss', 'wp_staticize_emoji');
    remove_filter('wp_mail', 'wp_staticize_emoji_for_email');
}
add_action('init', 'prefix_disable_emojis');
```

### Hide WordPress Version

Remove the generator meta tag that exposes the WordPress version.

```php
remove_action('wp_head', 'wp_generator');
```

---

## SVG Upload Support

Allow SVG file uploads in the WordPress media library.

```php
function prefix_allow_svg_upload($mimes) {
    $mimes['svg']  = 'image/svg+xml';
    $mimes['svgz'] = 'image/svg+xml';
    return $mimes;
}
add_filter('upload_mimes', 'prefix_allow_svg_upload');

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

---

## Schema.org Structured Data

Add JSON-LD structured data for SEO and AI search optimization.

```php
function prefix_output_schema_markup() {
    $site_url  = home_url();
    $site_name = get_bloginfo('name');

    $schema = array(
        '@context'    => 'https://schema.org',
        '@type'       => 'Organization',
        '@id'         => $site_url . '/#organization',
        'name'        => $site_name,
        'url'         => $site_url,
        'description' => 'A brief description of the business.',
    );

    echo '<script type="application/ld+json">' . "\n";
    echo wp_json_encode($schema, JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);
    echo "\n" . '</script>' . "\n";
}
add_action('wp_head', 'prefix_output_schema_markup', 5);
```

---

## SEO Meta Descriptions

Add meta description tags, but defer to SEO plugins if present.

```php
function prefix_add_meta_description() {
    // Skip if Yoast or Rank Math is active
    if (defined('WPSEO_VERSION') || defined('RANK_MATH_VERSION')) {
        return;
    }

    $description = '';

    if (is_front_page()) {
        $description = 'Your site description here.';
    } elseif (is_singular('post')) {
        $post = get_post();
        $description = has_excerpt() ? get_the_excerpt($post) : wp_trim_words(strip_tags($post->post_content), 30, '...');
    }

    if ($description) {
        echo '<meta name="description" content="' . esc_attr($description) . '">' . "\n";
    }
}
add_action('wp_head', 'prefix_add_meta_description', 1);
```

---

## Naming Conventions

- **All PHP functions** use a unique prefix: `prefix_` (replace with your theme slug, e.g., `kairo_`, `starter_`)
- **Template parts** are named `section-*.php` for content sections, `footer-*.php` for footer variants
- **Page templates** are named `page-*.php` (e.g., `page-pricing.php`, `page-software.php`)
- **CSS classes** use BEM: `.block__element--modifier`
- **JS files** use lowercase with hyphens: `main.js`, `software.js`

---

## Summary Checklist

- [ ] `style.css` has required WordPress headers
- [ ] All assets enqueued via `wp_enqueue_style()` / `wp_enqueue_script()`
- [ ] `filemtime()` used for cache busting on all local assets
- [ ] All theme supports registered in `after_setup_theme`
- [ ] All dynamic output escaped with appropriate function
- [ ] No `query_posts()` anywhere
- [ ] No inline styles or scripts in templates
- [ ] Emojis disabled, WP version hidden
- [ ] SVG uploads enabled
- [ ] Custom body classes added
- [ ] SCF/ACF options page registered
- [ ] Schema.org structured data output
- [ ] Meta descriptions added with SEO plugin check
- [ ] Font preconnect and LCP preloading configured
