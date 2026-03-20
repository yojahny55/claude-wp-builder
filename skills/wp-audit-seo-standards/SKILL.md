---
name: wp-audit-seo-standards
description: Rank Math SEO configuration reference, schema JSON-LD templates, meta patterns, and SEO seeding commands
user-invocable: false
---

# SEO Standards — Rank Math Reference

This skill defines the SEO configuration standards, schema templates, and seeding commands for WordPress sites using **Rank Math SEO** as the primary SEO plugin.

---

## 1. Rank Math Plugin Detection

```php
// Plugin slug: seo-by-rank-math
// Detection: defined('RANK_MATH_VERSION') or class_exists('RankMath')
// WP-CLI install: $WP plugin install seo-by-rank-math --activate
```

Before running any Rank Math commands, verify the plugin is active:

```bash
$WP eval "
if (defined('RANK_MATH_VERSION')) {
    echo 'Rank Math v' . RANK_MATH_VERSION . ' is active.';
} else {
    echo 'Rank Math is NOT active.';
}
"
```

---

## 2. Rank Math Modules Reference

| Module | Slug | Recommended | Notes |
|--------|------|-------------|-------|
| SEO Analysis | `seo-analysis` | Yes | On-page content scoring |
| Sitemap | `sitemap` | Yes | XML sitemap generation |
| Rich Snippets | `rich-snippet` | Yes | JSON-LD structured data |
| Breadcrumbs | `breadcrumbs` | Yes | Breadcrumb trail + schema |
| 404 Monitor | `404-monitor` | Yes | Track broken links |
| Redirections | `redirections` | Yes | 301/302 redirect manager |
| Local SEO | `local-seo` | Yes (business sites) | LocalBusiness schema |
| Image SEO | `image-seo` | Yes | Auto alt/title attributes |
| Instant Indexing | `instant-indexing` | Yes | IndexNow / Bing |
| Link Counter | `link-counter` | Yes | Internal/external link audit |

### Enable All Recommended Modules

```bash
$WP eval "
\$modules = get_option('rank_math_modules', []);
\$enable = ['seo-analysis','sitemap','rich-snippet','breadcrumbs','404-monitor','redirections','local-seo','image-seo','instant-indexing','link-counter'];
foreach (\$enable as \$mod) { if (!in_array(\$mod, \$modules)) { \$modules[] = \$mod; } }
update_option('rank_math_modules', \$modules);
echo 'Enabled modules: ' . implode(', ', \$modules);
"
```

---

## 3. Rank Math Option Keys

| Option | Purpose |
|--------|---------|
| `rank_math_modules` | Array of active module slugs |
| `rank-math-options-general` | Breadcrumbs, links, image SEO, strip category base |
| `rank-math-options-titles` | Title templates, schema type, social profiles, noindex rules |
| `rank-math-options-sitemap` | Sitemap inclusions, ping settings |
| `rank-math-options-instant-indexing` | IndexNow configuration |

### Reading Options

```bash
# Get all general options
$WP eval "print_r(get_option('rank-math-options-general'));"

# Get all title options
$WP eval "print_r(get_option('rank-math-options-titles'));"

# Get active modules
$WP eval "print_r(get_option('rank_math_modules'));"
```

### Writing Options

Rank Math stores options as serialized arrays. Always merge rather than overwrite:

```bash
$WP eval "
\$opts = (array) get_option('rank-math-options-general', []);
\$opts['breadcrumbs']          = 'on';
\$opts['strip_category_base']  = 'on';
\$opts['nofollow_external_links'] = 'on';
\$opts['new_window_external_links'] = 'on';
\$opts['add_img_alt']          = 'on';
\$opts['add_img_title']        = 'on';
update_option('rank-math-options-general', \$opts);
echo 'General options updated.';
"
```

---

## 4. Rank Math Post Meta Keys

| Meta Key | Purpose | Example Value |
|----------|---------|---------------|
| `rank_math_title` | SEO title template | `%title% %sep% %sitename%` |
| `rank_math_description` | Meta description | Free text, 150-160 chars |
| `rank_math_focus_keyword` | Focus keyword(s) | `keyword1,keyword2` |
| `rank_math_robots` | Robots directives | `["index","follow"]` |
| `rank_math_canonical_url` | Canonical URL override | `https://...` |
| `rank_math_facebook_title` | OG title | Free text |
| `rank_math_facebook_description` | OG description | Free text |
| `rank_math_facebook_image` | OG image URL | `https://...` |
| `rank_math_facebook_image_id` | OG image attachment ID | `42` |
| `rank_math_twitter_card_type` | Twitter card type | `summary_large_image` |
| `rank_math_twitter_title` | Twitter title | Free text |
| `rank_math_twitter_description` | Twitter description | Free text |
| `rank_math_schema_Article` | Article schema | Serialized array |
| `rank_math_schema_FAQPage` | FAQ schema | Serialized array |
| `rank_math_breadcrumb_title` | Breadcrumb label override | Free text |
| `rank_math_pillar_content` | Pillar content flag | `on` |

### Seeding Post Meta via WP-CLI

```bash
# Set SEO meta for a single post
$WP eval "
\$post_id = 42;
update_post_meta(\$post_id, 'rank_math_title', '%title% %sep% %sitename%');
update_post_meta(\$post_id, 'rank_math_description', 'Your meta description here.');
update_post_meta(\$post_id, 'rank_math_focus_keyword', 'primary keyword');
update_post_meta(\$post_id, 'rank_math_robots', ['index','follow']);
update_post_meta(\$post_id, 'rank_math_twitter_card_type', 'summary_large_image');
echo 'SEO meta set for post ' . \$post_id;
"
```

### Bulk-Seed Meta Descriptions from Content

```bash
$WP eval "
\$posts = get_posts(['post_type' => ['post','page'], 'posts_per_page' => -1, 'post_status' => 'publish']);
foreach (\$posts as \$p) {
    \$existing = get_post_meta(\$p->ID, 'rank_math_description', true);
    if (!empty(\$existing)) continue;
    \$text = wp_strip_all_tags(\$p->post_excerpt ?: \$p->post_content);
    \$desc = mb_substr(trim(preg_replace('/\s+/', ' ', \$text)), 0, 155);
    if (mb_strlen(\$desc) > 10) {
        update_post_meta(\$p->ID, 'rank_math_description', \$desc);
        echo 'Set description for: ' . \$p->post_title . PHP_EOL;
    }
}
"
```

---

## 5. Schema JSON-LD Templates

### Organization

```json
{
  "@context": "https://schema.org",
  "@type": "Organization",
  "name": "",
  "url": "",
  "logo": {
    "@type": "ImageObject",
    "url": ""
  },
  "sameAs": [
    "https://www.facebook.com/PROFILE",
    "https://www.instagram.com/PROFILE",
    "https://x.com/PROFILE",
    "https://www.linkedin.com/company/PROFILE"
  ]
}
```

### LocalBusiness

```json
{
  "@context": "https://schema.org",
  "@type": "LocalBusiness",
  "name": "",
  "url": "",
  "image": "",
  "telephone": "",
  "email": "",
  "address": {
    "@type": "PostalAddress",
    "streetAddress": "",
    "addressLocality": "",
    "addressRegion": "",
    "postalCode": "",
    "addressCountry": ""
  },
  "geo": {
    "@type": "GeoCoordinates",
    "latitude": "",
    "longitude": ""
  },
  "openingHoursSpecification": [
    {
      "@type": "OpeningHoursSpecification",
      "dayOfWeek": ["Monday","Tuesday","Wednesday","Thursday","Friday"],
      "opens": "09:00",
      "closes": "17:00"
    }
  ],
  "sameAs": []
}
```

### FAQPage

```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "What is the question?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "The answer to the question."
      }
    },
    {
      "@type": "Question",
      "name": "Another question?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Another answer."
      }
    }
  ]
}
```

### BreadcrumbList

```json
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    {
      "@type": "ListItem",
      "position": 1,
      "name": "Home",
      "item": "https://example.com/"
    },
    {
      "@type": "ListItem",
      "position": 2,
      "name": "Category",
      "item": "https://example.com/category/"
    },
    {
      "@type": "ListItem",
      "position": 3,
      "name": "Current Page"
    }
  ]
}
```

### Article

```json
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "",
  "author": {
    "@type": "Person",
    "name": "",
    "url": ""
  },
  "datePublished": "2025-01-01T00:00:00+00:00",
  "dateModified": "2025-01-01T00:00:00+00:00",
  "image": {
    "@type": "ImageObject",
    "url": "",
    "width": 1200,
    "height": 630
  },
  "mainEntityOfPage": {
    "@type": "WebPage",
    "@id": "https://example.com/post-slug/"
  },
  "publisher": {
    "@type": "Organization",
    "name": "",
    "logo": {
      "@type": "ImageObject",
      "url": ""
    }
  }
}
```

---

## 6. Meta Title Formulas by Page Type

| Page Type | Formula |
|-----------|---------|
| Homepage | `%sitename% %sep% %sitedesc%` |
| Page | `%title% %sep% %sitename%` |
| Blog Post | `%title% %sep% %sitename%` |
| Category | `%term% %sep% %sitename% %page%` |
| Search | `Search: %searchphrase% %sep% %sitename%` |
| 404 | `Page Not Found %sep% %sitename%` |
| Author | `%name% %sep% %sitename%` |

### Available Variables

- `%title%` — Post/page title
- `%sitename%` — Site name from Settings > General
- `%sitedesc%` — Site tagline
- `%sep%` — Separator character (default: `-`)
- `%term%` — Category/tag name
- `%searchphrase%` — Current search query
- `%page%` — Page number (blank on page 1)
- `%name%` — Author display name
- `%date%` — Post publication date
- `%excerpt%` — Post excerpt

### Seed Title Templates via WP-CLI

```bash
$WP eval "
\$opts = (array) get_option('rank-math-options-titles', []);
\$opts['homepage_title']    = '%sitename% %sep% %sitedesc%';
\$opts['pt_post_title']     = '%title% %sep% %sitename%';
\$opts['pt_page_title']     = '%title% %sep% %sitename%';
\$opts['tax_category_title'] = '%term% %sep% %sitename% %page%';
\$opts['search_title']      = 'Search: %searchphrase% %sep% %sitename%';
\$opts['404_title']         = 'Page Not Found %sep% %sitename%';
\$opts['author_archive_title'] = '%name% %sep% %sitename%';
update_option('rank-math-options-titles', \$opts);
echo 'Title templates updated.';
"
```

---

## 7. Meta Description Generation

### Priority Order

1. **Manual** — `rank_math_description` post meta (highest priority)
2. **Excerpt** — Post excerpt if set
3. **First paragraph** — First `<p>` block in post content
4. **Trimmed content** — First 155 characters of stripped content

**Target length:** 150–160 characters.

### Auto-Generate Description Function

```php
function prefix_auto_meta_description( $post_id ) {
    $existing = get_post_meta( $post_id, 'rank_math_description', true );
    if ( ! empty( $existing ) ) {
        return $existing;
    }

    $post = get_post( $post_id );
    if ( ! $post ) {
        return '';
    }

    // Try excerpt first
    if ( ! empty( $post->post_excerpt ) ) {
        $text = $post->post_excerpt;
    } else {
        // Try first paragraph
        $content = $post->post_content;
        if ( preg_match( '/<p[^>]*>(.*?)<\/p>/is', $content, $matches ) ) {
            $text = $matches[1];
        } else {
            $text = $content;
        }
    }

    $text = wp_strip_all_tags( $text );
    $text = trim( preg_replace( '/\s+/', ' ', $text ) );
    $desc = mb_substr( $text, 0, 155 );

    // Avoid cutting mid-word
    if ( mb_strlen( $text ) > 155 ) {
        $desc = mb_substr( $desc, 0, mb_strrpos( $desc, ' ' ) );
        $desc .= '...';
    }

    return $desc;
}
```

### Bulk Seed via WP-CLI

```bash
$WP eval "
\$posts = get_posts(['post_type' => ['post','page'], 'posts_per_page' => -1, 'post_status' => 'publish']);
\$count = 0;
foreach (\$posts as \$p) {
    \$existing = get_post_meta(\$p->ID, 'rank_math_description', true);
    if (!empty(\$existing)) continue;
    \$text = wp_strip_all_tags(\$p->post_excerpt ?: \$p->post_content);
    \$text = trim(preg_replace('/\s+/', ' ', \$text));
    \$desc = mb_substr(\$text, 0, 155);
    if (mb_strlen(\$text) > 155) {
        \$desc = mb_substr(\$desc, 0, mb_strrpos(\$desc, ' '));
    }
    if (mb_strlen(\$desc) > 10) {
        update_post_meta(\$p->ID, 'rank_math_description', \$desc);
        \$count++;
    }
}
echo \"Seeded \$count meta descriptions.\";
"
```

---

## 8. llms.txt Template

```
# {Site Name}

> {Site Description}

## Pages
- [Page Title](url): excerpt or first 20 words

## Blog Posts
- [Post Title](url): excerpt

## Contact
- Website: {home_url}
```

### Generate llms.txt via WP-CLI

```bash
$WP eval "
\$name = get_bloginfo('name');
\$desc = get_bloginfo('description');
\$home = home_url('/');
\$out  = \"# \$name\n\n> \$desc\n\n\";

// Pages
\$out .= \"## Pages\n\";
\$pages = get_posts(['post_type' => 'page', 'posts_per_page' => -1, 'post_status' => 'publish', 'orderby' => 'menu_order', 'order' => 'ASC']);
foreach (\$pages as \$p) {
    \$url     = get_permalink(\$p->ID);
    \$excerpt = \$p->post_excerpt ?: wp_trim_words(wp_strip_all_tags(\$p->post_content), 20, '...');
    \$out    .= \"- [\$p->post_title](\$url): \$excerpt\n\";
}

// Blog posts
\$out  .= \"\n## Blog Posts\n\";
\$posts = get_posts(['post_type' => 'post', 'posts_per_page' => -1, 'post_status' => 'publish', 'orderby' => 'date', 'order' => 'DESC']);
foreach (\$posts as \$p) {
    \$url     = get_permalink(\$p->ID);
    \$excerpt = \$p->post_excerpt ?: wp_trim_words(wp_strip_all_tags(\$p->post_content), 20, '...');
    \$out    .= \"- [\$p->post_title](\$url): \$excerpt\n\";
}

// Contact
\$out .= \"\n## Contact\n\";
\$out .= \"- Website: \$home\n\";

file_put_contents(ABSPATH . 'llms.txt', \$out);
echo 'Generated llms.txt at ' . ABSPATH . 'llms.txt';
echo PHP_EOL . '---' . PHP_EOL . \$out;
"
```

---

## 9. robots.txt Template

```
# robots.txt for WordPress
User-agent: *
Allow: /
Disallow: /wp-admin/
Allow: /wp-admin/admin-ajax.php
Disallow: /wp-includes/
Disallow: /wp-content/plugins/
Disallow: /readme.html
Disallow: /license.txt
Disallow: /?s=
Disallow: /search/
Disallow: /cgi-bin/
Disallow: /trackback/

# AI Crawlers — Allow by default (confirm with user before changing)
User-agent: GPTBot
Allow: /

User-agent: ClaudeBot
Allow: /

User-agent: Google-Extended
Allow: /

User-agent: PerplexityBot
Allow: /

User-agent: CCBot
Allow: /

User-agent: Bytespider
Disallow: /

# Sitemap
Sitemap: {home_url}/sitemap_index.xml
```

> **Note:** AI crawler policy (Allow vs Disallow) should be confirmed with the site owner before writing. The defaults above allow all major AI crawlers except Bytespider.

### Generate robots.txt via WP-CLI

```bash
$WP eval "
\$home = home_url('/');
\$robots = 'User-agent: *
Allow: /
Disallow: /wp-admin/
Allow: /wp-admin/admin-ajax.php
Disallow: /wp-includes/
Disallow: /wp-content/plugins/
Disallow: /readme.html
Disallow: /license.txt
Disallow: /?s=
Disallow: /search/
Disallow: /cgi-bin/
Disallow: /trackback/

# AI Crawlers
User-agent: GPTBot
Allow: /

User-agent: ClaudeBot
Allow: /

User-agent: Google-Extended
Allow: /

User-agent: PerplexityBot
Allow: /

User-agent: CCBot
Allow: /

User-agent: Bytespider
Disallow: /

Sitemap: ' . \$home . 'sitemap_index.xml
';
file_put_contents(ABSPATH . 'robots.txt', \$robots);
echo 'Generated robots.txt at ' . ABSPATH . 'robots.txt';
"
```

---

## 10. Breadcrumb Integration Code

### PHP Function

```php
function prefix_breadcrumbs() {
    if (is_front_page()) return;
    echo '<nav class="breadcrumbs" aria-label="Breadcrumb">';
    if (function_exists('rank_math_the_breadcrumbs')) {
        rank_math_the_breadcrumbs();
    } else {
        echo '<a href="' . esc_url(home_url('/')) . '">Home</a>';
        echo ' &raquo; ';
        if (is_singular()) { the_title(); }
        elseif (is_archive()) { the_archive_title(); }
        elseif (is_search()) { echo 'Search results'; }
        elseif (is_404()) { echo 'Page Not Found'; }
    }
    echo '</nav>';
}
```

### Breadcrumb CSS

```css
.breadcrumbs {
    padding: 12px 0;
    font-size: 0.875rem;
    color: #6b7280;
}
.breadcrumbs a {
    color: #3b82f6;
    text-decoration: none;
}
.breadcrumbs a:hover {
    text-decoration: underline;
}
.breadcrumbs .separator {
    margin: 0 0.5rem;
    color: #9ca3af;
}
```

### Enable Breadcrumbs in Rank Math

```bash
$WP eval "
\$opts = (array) get_option('rank-math-options-general', []);
\$opts['breadcrumbs'] = 'on';
update_option('rank-math-options-general', \$opts);
echo 'Breadcrumbs enabled.';
"
```

---

## 11. FAQ Detection Patterns

FAQ content can appear in several forms. Detect and convert to JSON-LD schema automatically.

### Detection Sources

1. **ACF repeater fields** — field names: `faq_items`, `faqs`, `faq_cards`, `faq`
2. **`<details>/<summary>` HTML** — accordion-style FAQ in content
3. **H2/H3 headings ending with `?`** — followed by `<p>` answer content

### FAQ Auto-Detection and JSON-LD Generator

```php
function prefix_detect_faq_jsonld( $post_id ) {
    $faqs = [];

    // 1. Check ACF repeater fields
    $acf_names = ['faq_items', 'faqs', 'faq_cards', 'faq'];
    foreach ( $acf_names as $field_name ) {
        if ( function_exists('have_rows') && have_rows( $field_name, $post_id ) ) {
            while ( have_rows( $field_name, $post_id ) ) {
                the_row();
                $q = get_sub_field('question') ?: get_sub_field('title');
                $a = get_sub_field('answer')   ?: get_sub_field('content') ?: get_sub_field('text');
                if ( $q && $a ) {
                    $faqs[] = [ 'q' => wp_strip_all_tags($q), 'a' => wp_strip_all_tags($a) ];
                }
            }
        }
    }

    // 2. Check <details>/<summary> in content
    $content = get_post_field('post_content', $post_id);
    if ( preg_match_all('/<summary[^>]*>(.*?)<\/summary>\s*(.*?)<\/details>/is', $content, $matches, PREG_SET_ORDER) ) {
        foreach ( $matches as $m ) {
            $q = wp_strip_all_tags( $m[1] );
            $a = wp_strip_all_tags( $m[2] );
            if ( $q && $a ) {
                $faqs[] = [ 'q' => $q, 'a' => $a ];
            }
        }
    }

    // 3. Check H2/H3 headings ending with ?
    if ( preg_match_all('/<h[23][^>]*>(.*?\?)<\/h[23]>\s*<p>(.*?)<\/p>/is', $content, $matches, PREG_SET_ORDER) ) {
        foreach ( $matches as $m ) {
            $q = wp_strip_all_tags( $m[1] );
            $a = wp_strip_all_tags( $m[2] );
            if ( $q && $a ) {
                $faqs[] = [ 'q' => $q, 'a' => $a ];
            }
        }
    }

    if ( empty( $faqs ) ) {
        return '';
    }

    // Build JSON-LD
    $schema = [
        '@context'   => 'https://schema.org',
        '@type'      => 'FAQPage',
        'mainEntity' => [],
    ];
    foreach ( $faqs as $faq ) {
        $schema['mainEntity'][] = [
            '@type'          => 'Question',
            'name'           => $faq['q'],
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text'  => $faq['a'],
            ],
        ];
    }

    return '<script type="application/ld+json">' . wp_json_encode( $schema, JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT ) . '</script>';
}
```

### Inject FAQ Schema into Head

```php
add_action('wp_head', function() {
    if ( is_singular() ) {
        $jsonld = prefix_detect_faq_jsonld( get_the_ID() );
        if ( $jsonld ) {
            echo $jsonld;
        }
    }
});
```

---

## 12. SEO Seeding Sequence

Recommended order for bulk SEO setup on a new or existing site:

1. **Install + activate Rank Math** — `$WP plugin install seo-by-rank-math --activate`
2. **Enable modules** — activate all recommended modules (Section 2)
3. **Configure general settings** — breadcrumbs, link behavior, image SEO (Section 3)
4. **Configure title templates** — set formulas per page type (Section 6)
5. **Configure sitemap** — set post types and taxonomies to include
6. **Set Organization / LocalBusiness schema** — configure site-wide schema (Section 5)
7. **Configure OG / Social defaults** — set default OG image, social profiles
8. **Enable IndexNow** — activate instant indexing for Bing / Yandex
9. **Seed per-page SEO meta** — `rank_math_title`, `rank_math_focus_keyword`, robots (Section 4)
10. **Seed meta descriptions** — auto-generate from excerpt/content (Section 7)
11. **Set image alt texts** — bulk update missing alt attributes
12. **Generate robots.txt** — write optimized robots.txt (Section 9)
13. **Generate llms.txt** — write AI-readable site summary (Section 8)
14. **Flush sitemap cache + rewrite rules** — finalize:

```bash
$WP eval "
if (class_exists('RankMath')) {
    // Trigger sitemap regeneration
    delete_transient('rank_math_sitemap_cache');
    \RankMath\Sitemap\Cache::invalidate_storage();
}
"
$WP rewrite flush
```

### Verification Checklist

After seeding, verify:

```bash
# Check title templates are set
$WP eval "print_r(get_option('rank-math-options-titles'));"

# Count posts with meta descriptions
$WP eval "
global \$wpdb;
\$count = \$wpdb->get_var(\"SELECT COUNT(*) FROM \$wpdb->postmeta WHERE meta_key = 'rank_math_description' AND meta_value != ''\");
echo \"Posts with meta descriptions: \$count\";
"

# Verify sitemap exists
$WP eval "echo home_url('/sitemap_index.xml');"

# Verify robots.txt exists
$WP eval "echo file_exists(ABSPATH . 'robots.txt') ? 'robots.txt exists' : 'robots.txt missing';"

# Verify llms.txt exists
$WP eval "echo file_exists(ABSPATH . 'llms.txt') ? 'llms.txt exists' : 'llms.txt missing';"
```
