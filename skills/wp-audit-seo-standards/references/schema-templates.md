# Schema JSON-LD templates

Part of the `wp-audit-seo-standards` skill; section numbers match its SKILL.md.

## Contents

- 5. Schema JSON-LD Templates — Organization, LocalBusiness, FAQPage, BreadcrumbList, Article
- 11. FAQ Detection Patterns — the auto-detection generator and its `wp_head` hook

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
      "item": "https://example.com/<category_base>/<term-slug>/"
    },
    {
      "@type": "ListItem",
      "position": 3,
      "name": "Current Page"
    }
  ]
}
```

`<category_base>` is read, never assumed — SKILL.md §5 says how.

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

## 11. FAQ Detection Patterns

The three detection sources are listed in SKILL.md §11.

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
