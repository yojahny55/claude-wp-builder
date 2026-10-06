# Head output and performance code

The PHP behind the `wp_head` and performance rules in `wp-theme-standards`. `prefix_` is the
project's function prefix from its `.claude/CLAUDE.md`.

## Contents

- Font preload
- LCP image preloading
- Disable WordPress emojis
- Hide the WordPress version
- SEO meta descriptions

---

## Performance Optimizations

### Font Preload

The theme self-hosts its fonts (`/wp-init` Step 4.5) and requests nothing from
`fonts.googleapis.com` or `fonts.gstatic.com`, so there is no font origin to preconnect to.
Preload exactly one file — the primary family's regular (400) latin woff2 — guarded on the
file existing. `crossorigin` is required even same-origin, or the font downloads twice:

```php
add_action( 'wp_head', function() {
    $font = PREFIX_DIR . '/assets/fonts/<primary-regular-latin>.woff2';
    if ( file_exists( $font ) ) {
        printf(
            '<link rel="preload" as="font" type="font/woff2" href="%s" crossorigin>' . "\n",
            esc_url( PREFIX_URI . '/assets/fonts/<primary-regular-latin>.woff2' )
        );
    }
}, 1 );
```

### LCP Image Preloading

Preload the Largest Contentful Paint (LCP) element (usually the hero image) on the homepage,
with the same candidates the `<img>` offers. `imagesrcset` and `imagesizes` let the browser
preload the candidate it will actually render; `href` alone preloads the full-size original
and the `<img>` then downloads its own `srcset` pick as well. Pass the `sizes` the template
gives `prefix_image()` for the same image:

```php
add_action( 'wp_head', function() {
    if ( ! is_front_page() ) {
        return;
    }
    $hero = prefix_get_field( 'hero_image' );
    $id   = is_array( $hero ) ? (int) ( $hero['id'] ?? 0 ) : 0;
    if ( ! $id ) {
        return;
    }
    printf(
        '<link rel="preload" as="image" href="%s" imagesrcset="%s" imagesizes="%s" fetchpriority="high">' . "\n",
        esc_url( wp_get_attachment_image_url( $id, 'large' ) ),
        esc_attr( (string) wp_get_attachment_image_srcset( $id, 'large' ) ),
        esc_attr( '100vw' ) // the hero's real display width — the same `sizes` as its <img>
    );
}, 2 );
```

### Disable WordPress Emojis

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

```php
remove_action('wp_head', 'wp_generator');
```

## SEO Meta Descriptions

```php
function prefix_add_meta_description() {
    // Skip if Yoast or Rank Math is active
    if (defined('WPSEO_VERSION') || defined('RANK_MATH_VERSION')) {
        return;
    }

    $description = '';

    if (is_front_page()) {
        $description = prefix_get_field('site_description', 'option') ?: get_bloginfo('description');
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
