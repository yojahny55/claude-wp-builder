# Head output and performance code

The PHP behind the `wp_head` and performance rules in `wp-theme-standards`. `prefix_` is the
project's function prefix from its `.claude/CLAUDE.md`.

## Contents

- Font preconnect
- LCP image preloading
- Disable WordPress emojis
- Hide the WordPress version
- Schema.org structured data
- SEO meta descriptions

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
        echo '<link rel="preload" as="image" href="' . esc_url($hero_image_url) . '" fetchpriority="high">' . "\n";
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
