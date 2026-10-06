# SEO seeding commands

Part of the `wp-audit-seo-standards` skill; section numbers match its SKILL.md, which holds the
keys, formulas and rules these commands write.

## Contents

- 3. Options — read, and write by merging
- 4. Post meta — seed one post
- 6. Title templates — seed the template per page type
- 7. Meta descriptions — the generator function and the one bulk seed

## 3. Rank Math Option Keys

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

Merge into the existing array (SKILL.md §3):

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

Bulk descriptions are seeded by the one block in §7, which follows SKILL.md §7's priority
order.

---

## 6. Title Templates by Page Type

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

The same order and the same cut as `prefix_auto_meta_description()` above — excerpt, then
the first paragraph, then the content, cut at a word boundary — so a seeded description and
a generated one never differ for the same post. Posts that already have one are skipped.

```bash
$WP eval "
\$posts = get_posts(['post_type' => ['post','page'], 'posts_per_page' => -1, 'post_status' => 'publish']);
\$count = 0;
foreach (\$posts as \$p) {
    if (get_post_meta(\$p->ID, 'rank_math_description', true)) continue;
    // SKILL.md §7 priority: excerpt, then the first paragraph, then the content.
    \$text = \$p->post_excerpt;
    if (!\$text && preg_match('/<p[^>]*>(.*?)<\/p>/is', \$p->post_content, \$m)) \$text = \$m[1];
    if (!\$text) \$text = \$p->post_content;
    \$text = trim(preg_replace('/\s+/', ' ', wp_strip_all_tags(\$text)));
    \$desc = mb_substr(\$text, 0, 155);
    if (mb_strlen(\$text) > 155) \$desc = mb_substr(\$desc, 0, mb_strrpos(\$desc, ' ')) . '...';
    if (mb_strlen(\$desc) > 10) { update_post_meta(\$p->ID, 'rank_math_description', \$desc); \$count++; }
}
echo \"Seeded \$count meta descriptions.\";
"
```
