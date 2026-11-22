# Rank Math sitemap validation (agent Step 5.5)

The script `wp-audit-rankmath` Step 5.5 runs. `$WP` is the project WP-CLI wrapper.

```bash
$WP eval "
\$home = home_url('/');
\$sitemap_url = \$home . 'sitemap_index.xml';
\$response = wp_remote_get(\$sitemap_url);
\$code = wp_remote_retrieve_response_code(\$response);
\$body = wp_remote_retrieve_body(\$response);
\$content_type = wp_remote_retrieve_header(\$response, 'content-type');

echo \"Status: \$code\n\";
echo \"Content-Type: \$content_type\n\";

// Follow the index into every child sitemap — the URLs live there, not here.
// Only an index has children: in a flat <urlset> the <loc> entries are the post
// URLs themselves, and re-fetching each one would hammer the site for nothing.
\$children = array();
\$all_bodies = array();
if (stripos(\$body, '<sitemapindex') !== false) {
    preg_match_all('#<loc>\s*([^<\s]+)\s*</loc>#i', \$body, \$m);
    \$children = array_diff(array_unique(\$m[1]), array(\$sitemap_url));
    foreach (\$children as \$child) {
        \$all_bodies[] = wp_remote_retrieve_body(wp_remote_get(\$child));
    }
}
echo 'Fetched ' . count(\$children) . \" child sitemaps.\n\";

// Every <loc> across the index and its children, compared as whole URLs. A
// substring test would report /page/ as present because /page/2/ is listed.
\$all_bodies[] = \$body;
\$listed = array();
foreach (\$all_bodies as \$b) {
    preg_match_all('#<loc>\s*([^<\s]+)\s*</loc>#i', \$b, \$m);
    foreach (\$m[1] as \$loc) { \$listed[untrailingslashit(html_entity_decode(\$loc))] = true; }
}

// Check 1: Must return 200
if (\$code !== 200) { echo \"FAIL: Sitemap returns \$code\n\"; }

// Check 2: Must be XML, not HTML
if (strpos(\$body, '<!DOCTYPE html') !== false || strpos(\$body, '<html') !== false) {
    echo \"FAIL: Sitemap returns HTML (not XML)\n\";
}

// Check 3: Must contain <sitemapindex or <urlset
if (strpos(\$body, '<sitemapindex') === false && strpos(\$body, '<urlset') === false) {
    echo \"FAIL: Sitemap missing <sitemapindex> or <urlset>\n\";
}

// Check 4: registration_skip flag
\$skip = get_option('rank_math_registration_skip', 0);
\$configured = get_option('rank_math_is_configured', 0);
if (!\$skip) { echo \"FAIL: rank_math_registration_skip not set — Rank Math loads NO frontend SEO\n\"; }
if (!\$configured) { echo \"FAIL: rank_math_is_configured not set — wizard flag missing\n\"; }

// Check 5: Noindex pages in sitemap
global \$wpdb;
\$noindex_in_sitemap = \$wpdb->get_col(\"
    SELECT p.ID FROM {\$wpdb->posts} p
    JOIN {\$wpdb->postmeta} m ON p.ID=m.post_id
    WHERE p.post_status='publish' AND p.post_type IN ('post','page')
    AND m.meta_key='rank_math_robots' AND m.meta_value LIKE '%noindex%'
\");
foreach (\$noindex_in_sitemap as \$id) {
    if (isset(\$listed[untrailingslashit(get_permalink(\$id))])) {
        echo \"FAIL: noindex post #\$id is listed in the sitemap\n\";
    }
}

// Check 6: Draft/private posts in sitemap
\$drafts = \$wpdb->get_col(\"SELECT ID FROM {\$wpdb->posts} WHERE post_status IN ('draft','private') AND post_type IN ('post','page')\");
foreach (\$drafts as \$id) {
    if (isset(\$listed[untrailingslashit(get_permalink(\$id))])) {
        echo \"FAIL: unpublished post #\$id is listed in the sitemap\n\";
    }
}

echo \"Sitemap validation complete.\n\";
"
```
