# Rank Math under Polylang (agent Step 15)

The code of `wp-audit-rankmath` Step 15 and 15b. `$WP` is the project WP-CLI wrapper.

If Polylang is active, verify:

```bash
$WP eval "
if (!function_exists('pll_languages_list')) { echo 'SKIP: Polylang not active'; exit; }

\$langs = pll_languages_list();
echo 'Languages: ' . implode(', ', \$langs) . PHP_EOL;

// Check 1: Free Polylang = single sitemap (not per-language)
\$sitemap_url = home_url('/sitemap_index.xml');
\$response = wp_remote_get(\$sitemap_url);
\$body = wp_remote_retrieve_body(\$response);
if (strpos(\$body, '<sitemapindex') !== false) {
    echo 'OK: Sitemap index present' . PHP_EOL;
}
// Per-language /<lang>/sitemap_index.xml 404s by design on free Polylang — not a defect.

// Check 2: Posts without language assigned
global \$wpdb;
\$posts = \$wpdb->get_col(\"SELECT ID FROM {\$wpdb->posts} WHERE post_status='publish' AND post_type='post'\");
\$untranslated = 0;
foreach (\$posts as \$id) {
    if (!pll_get_post_language(\$id)) { \$untranslated++; }
}
if (\$untranslated > 0) {
    echo \"WARN: \$untranslated posts have no Polylang language assigned\" . PHP_EOL;
}

// Check 3: Translation completeness
\$default = pll_default_language();
\$missing = 0;
foreach (\$posts as \$id) {
    if (pll_get_post_language(\$id) !== \$default) continue;
    \$tr = pll_get_post_translations(\$id);
    if (count(\$tr) < 2) { \$missing++; }
}
if (\$missing > 0) {
    echo \"INFO: \$missing default-language posts have no translations\" . PHP_EOL;
}

echo 'Polylang + Rank Math checks complete.' . PHP_EOL;
"
```

### 15b. Translate the CPT-archive breadcrumb

Rank Math builds the archive crumb of a custom post type from the label passed to
`register_post_type()`, a plain literal in the primary language. Under Polylang,
`/en/<cpt-plural>/` and every single under it then show the primary-language plural in the
breadcrumb. `post_type_archive_title` filters do not reach it. Add this to the theme's
`inc/rankmath.php` (or wherever Step 4.7's `rank_math/json_ld` filter lives), with the real
prefix:

```php
/**
 * Route each CPT-archive crumb through the theme's string table, the same
 * `plural_<post_type>` key the post_type_archive_title filter reads.
 */
add_filter( 'rank_math/frontend/breadcrumb/items', function ( $crumbs ) {
    $types = get_post_types( array( '_builtin' => false, 'has_archive' => true ), 'names' );
    foreach ( $crumbs as $i => $crumb ) {
        foreach ( $types as $type ) {
            $link = get_post_type_archive_link( $type );
            $is_archive_crumb = ! empty( $crumb[1] ) && $link
                && untrailingslashit( $crumb[1] ) === untrailingslashit( $link );
            // On the archive itself the last crumb may carry no link.
            $is_current = empty( $crumb[1] ) && is_post_type_archive( $type ) && $i === array_key_last( $crumbs );
            if ( $is_archive_crumb || $is_current ) {
                $key   = 'plural_' . $type;
                $label = prefix_t( $key );
                // Fallback: the type's own label. post_type_archive_title() is null
                // on a single, and every single under the CPT carries this crumb too.
                $crumbs[ $i ][0] = $label !== $key ? $label : get_post_type_object( $type )->labels->name;
            }
        }
    }
    return $crumbs;
} );
```

Register a `plural_<post_type>` string for every CPT with an archive, in every language.
Then verify on the secondary language: fetch `/<lang>/<cpt-plural>/` and one single, and
read the breadcrumb text. The crumb must match the page's `<h1>`/`<title>` language, not the
primary one.
