# Rank Math schema validation (agent Step 8.5)

The script `wp-audit-rankmath` Step 8.5 runs. `$WP` is the project WP-CLI wrapper.

```bash
$WP eval "
// Check 1: Theme JSON-LD + Rank Math = duplicate schema
\$theme_jsonld = 0;
\$it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator(get_template_directory()));
foreach (\$it as \$f) {
    if (\$f->getExtension() !== 'php') continue;
    if (strpos(file_get_contents(\$f->getPathname()), 'application/ld+json') !== false) {
        \$theme_jsonld++;
        echo \"Theme JSON-LD found in: \" . \$f->getFilename() . \"\n\";
    }
}
if (\$theme_jsonld > 0) {
    echo \"WARN: Theme outputs JSON-LD AND Rank Math is active = duplicate schema\n\";
    echo \"  FIX: if it shares an @id with Rank Math's own node (Organization/LocalBusiness), merge it\n\";
    echo \"       through the rank_math/json_ld filter (Step 4.7) instead of removing it outright —\n\";
    echo \"       Rank Math does not collect address/contactPoint/geo/sameAs itself, so deleting the\n\";
    echo \"       theme's block loses that data rather than de-duplicating it. Only a genuinely\n\";
    echo \"       independent node (a different @type, its own @id) should just be removed.\n\";
}

// Check 1b: Theme's own <meta name=\"description\"> duplicates Rank Math's
\$meta_desc_theme = [];
\$it2 = new RecursiveIteratorIterator(new RecursiveDirectoryIterator(get_template_directory()));
foreach (\$it2 as \$f) {
    if (\$f->getExtension() !== 'php') continue;
    if (preg_match('/<meta\s+name=([\"\x27])description\1/i', file_get_contents(\$f->getPathname()))) {
        \$meta_desc_theme[] = \$f->getFilename();
    }
}
if (\$meta_desc_theme) {
    echo \"WARN: theme prints its own <meta name=description> in: \" . implode(', ', \$meta_desc_theme) . \"\n\";
    echo \"  FIX: do not gate this only on 'is an SEO plugin active' — Rank Math can be active and still\n\";
    echo \"       emit no description on a specific page (an unconfigured template, a route with no\n\";
    echo \"       post/term to hold meta). Gate the theme's own tag on the CURRENT object already having\n\";
    echo \"       a non-empty rank_math_description/rank_math_title (get_post_meta / get_term_meta), and\n\";
    echo \"       only print the fallback when that is empty — otherwise two description tags render on\n\";
    echo \"       the same page once Rank Math starts covering more routes.\n\";
}
\$dup = wp_remote_get(home_url('/'));
\$dup_body = wp_remote_retrieve_body(\$dup);
\$dup_count = preg_match_all('/<meta\s+name=[\"\x27]description[\"\x27]/i', \$dup_body);
echo \$dup_count > 1 ? \"FAIL: home page renders \$dup_count <meta name=description> tags\n\" : \"home page has \$dup_count description tag OK\n\";

// Check 2: Validate required schema fields
\$posts = get_posts(['post_type' => ['post','page'], 'posts_per_page' => -1, 'post_status' => 'publish']);
\$schema_issues = [];
foreach (\$posts as \$p) {
    \$schema = get_post_meta(\$p->ID, 'rank_math_schema_BlogPosting', true);
    if (\$schema && is_array(\$schema)) {
        // BlogPosting requires: headline, datePublished, author
        if (empty(\$schema['headline'])) { \$schema_issues[] = '#' . \$p->ID . ' missing headline'; }
        if (empty(\$schema['datePublished'])) { \$schema_issues[] = '#' . \$p->ID . ' missing datePublished'; }
        if (empty(\$schema['author'])) { \$schema_issues[] = '#' . \$p->ID . ' missing author'; }
    }
}
if (!empty(\$schema_issues)) {
    echo \"Schema issues: \" . implode(', ', \$schema_issues) . \"\n\";
} else {
    echo \"Schema validation passed.\n\";
}

// Check 3: LocalBusiness schema for service businesses
\$kg_type = get_option('rank-math-options-titles', [])['knowledgegraph_type'] ?? '';
if (\$kg_type === 'localBusiness') {
    \$schema = get_option('rank_math_schema_LocalBusiness', []);
    if (empty(\$schema['areaServed'])) {
        echo \"WARN: LocalBusiness schema missing areaServed\n\";
    }
    if (empty(\$schema['hasOfferCatalog'])) {
        echo \"WARN: LocalBusiness schema missing hasOfferCatalog (service catalog)\n\";
    }
}

echo \"Schema checks complete.\n\";
"
```
