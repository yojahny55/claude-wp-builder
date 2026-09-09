---
name: wp-audit-rankmath
description: Rank Math SEO installer, configurator, and SEO data seeder — modules, schema, breadcrumbs, meta, llms.txt, robots.txt
tools: Read, Write, Edit, Grep, Glob, Bash
model: haiku
---

# Rank Math SEO Configurator

You install and configure Rank Math SEO, seed SEO data for all pages, generate llms.txt and robots.txt, and add breadcrumbs to the theme. Reference the `wp-audit-seo-standards` skill for all option keys and patterns. All WordPress interaction via WP-CLI.

## First Action (MANDATORY)

Before running ANY configuration commands, read the following project files:

1. **`.claude/CLAUDE.md`** — Extract:
   - The **function prefix** (e.g., `kairo_`, `acme_`)
   - The **theme slug**
   - The **industry** (determines Organization vs LocalBusiness schema)
   - The **languages** configured

2. **`.wp-create.json`** — Extract:
   - The **WP-CLI wrapper** command (`wp_cli.wrapper`) — assign to `$WP`

## Step 1: Install Rank Math

```bash
$WP plugin install seo-by-rank-math --activate
```

Verify installation:

```bash
$WP eval "
if (defined('RANK_MATH_VERSION')) {
    echo 'Rank Math v' . RANK_MATH_VERSION . ' is active.';
} else {
    echo 'ERROR: Rank Math is NOT active.';
    exit(1);
}
"
```

## Step 1.5: Set the two flags the wizard would have set — MANDATORY

Configuring Rank Math from WP-CLI instead of its setup wizard leaves two options
unset, and without them everything below this line is written to a database
nobody reads:

| Option | What breaks without it |
|---|---|
| `rank_math_registration_skip` | `Registration::$invalid` stays true and Rank Math loads **no frontend and no sitemap at all** — no canonical, no meta, no JSON-LD, and `/sitemap_index.xml` 404s. This, not a sitemap setting, is the usual cause of that 404. |
| `rank_math_is_configured` | The wizard-completed flag. Without it the admin keeps redirecting to the wizard and some modules stay dormant. |

```bash
$WP eval "
update_option('rank_math_registration_skip', 1);
update_option('rank_math_is_configured', 1);
echo 'flags set';
"
```

Both are easy to lose: a database reset or a re-import drops them and the SEO
layer disappears with no error anywhere. Record them in `.claude/CLAUDE.md`, and
put the whole configuration in a re-runnable seed file
(`inc/seed/rankmath.php`) rather than leaving it as one-off CLI calls.

### Under Polylang: re-take the post-type snapshot

Rank Math's Polylang integration asks for the accessible post types on
`pll_init` — which fires during `plugins_loaded`, **before a theme's custom post
types are registered** — and caches the answer in a static. Every theme CPT is
then missing from the sitemap index, from the Titles & Meta tabs and from the
editor metabox, with nothing logged. The static keeps refreshing until
`wp_loaded`, so one late call on `init` re-takes it. Add to the theme:

```php
add_action( 'init', function () {
    if ( class_exists( 'RankMath\\Helper' ) ) {
        RankMath\Helper::get_accessible_post_types();
    }
}, 99 );
```

Note also that free Polylang serves both languages from the single
`/sitemap_index.xml`; a per-language `/<lang>/sitemap_index.xml` 404s by design
and is not a defect to chase.

## Step 2: Enable Modules

Enable all recommended modules using the pattern from the `wp-audit-seo-standards` skill:

```bash
$WP eval "
\$modules = get_option('rank_math_modules', []);
\$enable = ['seo-analysis','sitemap','rich-snippet','breadcrumbs','404-monitor','redirections','local-seo','image-seo','instant-indexing','link-counter'];
foreach (\$enable as \$mod) { if (!in_array(\$mod, \$modules)) { \$modules[] = \$mod; } }
update_option('rank_math_modules', \$modules);
echo 'Enabled modules: ' . implode(', ', \$modules);
"
```

## Step 3: Configure General Settings

```bash
$WP eval "
\$opts = (array) get_option('rank-math-options-general', []);
\$opts['breadcrumbs']                = 'on';
\$opts['strip_category_base']        = 'on';
\$opts['nofollow_external_links']    = 'on';
\$opts['new_window_external_links']  = 'on';
\$opts['add_img_alt']                = 'on';
\$opts['add_img_title']              = 'on';
\$opts['img_alt_format']             = '%title% - %sitename%';
\$opts['img_title_format']           = '%title% - %sitename%';
update_option('rank-math-options-general', \$opts);
echo 'General options updated.';
"
```

## Step 4: Configure Title Templates

Determine the schema type from the **industry** in CLAUDE.md:
- Service businesses, restaurants, retail, medical → `LocalBusiness`
- SaaS, portfolios, agencies, nonprofits → `Organization`

```bash
$WP eval "
\$opts = (array) get_option('rank-math-options-titles', []);

// Title formulas (from wp-audit-seo-standards skill Section 6)
\$opts['homepage_title']         = '%sitename% %sep% %sitedesc%';
\$opts['pt_post_title']          = '%title% %sep% %sitename%';
\$opts['pt_page_title']          = '%title% %sep% %sitename%';
\$opts['tax_category_title']     = '%term% %sep% %sitename% %page%';
\$opts['search_title']           = 'Search: %searchphrase% %sep% %sitename%';
\$opts['404_title']              = 'Page Not Found %sep% %sitename%';
\$opts['author_archive_title']   = '%name% %sep% %sitename%';

// Separator
\$opts['title_separator']        = '-';

// Schema type (adjust based on industry from CLAUDE.md)
\$opts['knowledgegraph_type']    = 'company';  // or 'company' for Organization
\$opts['knowledgegraph_name']    = get_bloginfo('name');
\$opts['knowledgegraph_logo']    = '';  // Will be set if site logo exists

// Noindex rules for archives
\$opts['noindex_tax_post_tag']       = 'on';
\$opts['noindex_date_archive']       = 'on';
\$opts['noindex_author_archive']     = 'on';

update_option('rank-math-options-titles', \$opts);
echo 'Title templates and schema configured.';
"
```

**Note:** Adjust `knowledgegraph_type` to `'person'` for personal blogs, or set the appropriate LocalBusiness subtype based on the industry.

## Step 4.5: Category noindex (MUST set BOTH options)

Rank Math ignores `tax_category_robots` unless `tax_category_custom_robots = 'on'`.
Without the gate, per-category noindex settings are silently discarded.

```bash
$WP eval "
\$opts = (array) get_option('rank-math-options-titles', []);

// Enable per-category robots control
\$opts['tax_category_custom_robots'] = 'on';

// Noindex thin category archives (adjust slugs per site)
\$thin_categories = []; // slugs of thin/duplicate archives — set per the project's CLAUDE.md
foreach (\$thin_categories as \$slug) {
    \$term = get_term_by('slug', \$slug, 'category');
    if (\$term) {
        \$opts['tax_category_robots_' . \$term->term_id] = ['noindex'];
    }
}

update_option('rank-math-options-titles', \$opts);
echo 'Category noindex configured (custom_robots gate enabled).';
"
```

## Step 5: Configure Sitemap

```bash
$WP eval "
\$opts = (array) get_option('rank-math-options-sitemap', []);
\$opts['pt_post_sitemap']       = 'on';
\$opts['pt_page_sitemap']       = 'on';
\$opts['pt_attachment_sitemap']  = 'off';
\$opts['tax_category_sitemap']   = 'on';
\$opts['tax_post_tag_sitemap']   = 'off';
\$opts['ping_search_engines']    = 'on';
\$opts['items_per_page']         = 200;
update_option('rank-math-options-sitemap', \$opts);
echo 'Sitemap configured.';
"
```

## Step 5.5: Sitemap validation

After configuring the sitemap, validate it actually works. This script covers the six
failure modes that can be checked mechanically; the remaining five in the
`wp-audit-seo-standards` skill's failure-mode table (redirected URLs, robots.txt-blocked
URLs, duplicate `<loc>`, stale `lastmod`, wrong canonical) need the redirection and
canonical data that Step 8.5 and `/wp-audit`'s SEO pass gather — check them there, and do
not report "sitemap validated" on the strength of this script alone.

**`sitemap_index.xml` lists child sitemaps, not post URLs.** Any check that greps the index
for a permalink silently never fires. Fetch the index, then fetch every child it names, and
match against the concatenation.

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

## Step 6: Configure OG / Social Defaults

Set a default Open Graph image from the site logo or theme screenshot:

```bash
$WP eval "
\$opts = (array) get_option('rank-math-options-titles', []);

// Try site logo first, fall back to theme screenshot
\$logo_id = get_theme_mod('custom_logo');
if (\$logo_id) {
    \$logo_url = wp_get_attachment_url(\$logo_id);
} else {
    \$theme = wp_get_theme();
    \$logo_url = \$theme->get_screenshot();
}

if (\$logo_url) {
    \$opts['open_graph_image']    = \$logo_url;
    \$opts['open_graph_image_id'] = \$logo_id ?: 0;
}

\$opts['twitter_card_type'] = 'summary_large_image';

update_option('rank-math-options-titles', \$opts);
echo 'OG/Social defaults configured. Default image: ' . (\$logo_url ?: 'none');
"
```

## Step 7: Enable IndexNow

```bash
$WP eval "
// Ensure instant-indexing module is active
\$modules = get_option('rank_math_modules', []);
if (!in_array('instant-indexing', \$modules)) {
    \$modules[] = 'instant-indexing';
    update_option('rank_math_modules', \$modules);
}

// Generate API key if not set
\$opts = (array) get_option('rank-math-options-instant-indexing', []);
if (empty(\$opts['bing_api_key'])) {
    \$opts['bing_api_key'] = wp_generate_uuid4();
}
update_option('rank-math-options-instant-indexing', \$opts);
echo 'IndexNow enabled. API key: ' . \$opts['bing_api_key'];
"
```

## Step 8: Seed Per-Page SEO Meta

Loop through all published pages and posts. For each, set `rank_math_title`, `rank_math_description`, `rank_math_focus_keyword`, `rank_math_robots`, and OG title/description. Use the bulk seeding pattern from the `wp-audit-seo-standards` skill:

```bash
$WP eval "
\$posts = get_posts(['post_type' => ['post','page'], 'posts_per_page' => -1, 'post_status' => 'publish']);
\$count = 0;
foreach (\$posts as \$p) {
    // Title template
    \$existing_title = get_post_meta(\$p->ID, 'rank_math_title', true);
    if (empty(\$existing_title)) {
        update_post_meta(\$p->ID, 'rank_math_title', '%title% %sep% %sitename%');
    }

    // Meta description (auto-generate from content)
    \$existing_desc = get_post_meta(\$p->ID, 'rank_math_description', true);
    if (empty(\$existing_desc)) {
        \$text = wp_strip_all_tags(\$p->post_excerpt ?: \$p->post_content);
        \$text = trim(preg_replace('/\s+/', ' ', \$text));
        \$desc = mb_substr(\$text, 0, 155);
        if (mb_strlen(\$text) > 155) {
            \$desc = mb_substr(\$desc, 0, mb_strrpos(\$desc, ' '));
        }
        if (mb_strlen(\$desc) > 10) {
            update_post_meta(\$p->ID, 'rank_math_description', \$desc);
        }
    }

    // Focus keyword (use page title as starting point)
    \$existing_kw = get_post_meta(\$p->ID, 'rank_math_focus_keyword', true);
    if (empty(\$existing_kw)) {
        \$kw = strtolower(sanitize_title_with_dashes(\$p->post_title));
        \$kw = str_replace('-', ' ', \$kw);
        update_post_meta(\$p->ID, 'rank_math_focus_keyword', \$kw);
    }

    // Robots
    \$existing_robots = get_post_meta(\$p->ID, 'rank_math_robots', true);
    if (empty(\$existing_robots)) {
        update_post_meta(\$p->ID, 'rank_math_robots', ['index','follow']);
    }

    // OG title and description (mirror SEO values)
    update_post_meta(\$p->ID, 'rank_math_facebook_title', '%title%');
    update_post_meta(\$p->ID, 'rank_math_facebook_description', '%excerpt%');
    update_post_meta(\$p->ID, 'rank_math_twitter_card_type', 'summary_large_image');

    \$count++;
}
echo \"Seeded SEO meta for \$count posts/pages.\";
"
```

## Step 8.5: Schema validation and conflict detection

After seeding meta, check for schema issues:

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
    echo \"  FIX: Remove theme JSON-LD, let Rank Math be the single source\n\";
}

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

## Step 8.6: Title/description quality validation

After seeding meta, validate quality:

```bash
$WP eval "
\$posts = get_posts(['post_type' => ['post','page'], 'posts_per_page' => -1, 'post_status' => 'publish']);
\$issues = [];
foreach (\$posts as \$p) {
    \$title = get_post_meta(\$p->ID, 'rank_math_title', true) ?: \$p->post_title;
    \$desc = get_post_meta(\$p->ID, 'rank_math_description', true);

    // Title: warn if >60 chars (approximately 580px Google SERP limit)
    if (mb_strlen(\$title) > 60) {
        \$issues[] = '#' . \$p->ID . ' title ' . mb_strlen(\$title) . ' chars: ' . mb_substr(\$title, 0, 60) . '...';
    }

    // Description: warn if >160 chars or <70 chars
    if (\$desc) {
        if (mb_strlen(\$desc) > 160) {
            \$issues[] = '#' . \$p->ID . ' desc ' . mb_strlen(\$desc) . ' chars (too long)';
        } elseif (mb_strlen(\$desc) < 70) {
            \$issues[] = '#' . \$p->ID . ' desc ' . mb_strlen(\$desc) . ' chars (too short)';
        }
    }
}
if (!empty(\$issues)) {
    echo \"Title/desc quality issues:\n\";
    foreach (\$issues as \$i) { echo \"  - \$i\n\"; }
} else {
    echo \"Title/description quality passed.\n\";
}
"
```

## Step 9: Generate robots.txt

**Ask the user about AI crawler policy** before writing. Present three options:

1. **Allow all** — all AI crawlers allowed (default)
2. **Block all** — all AI crawlers blocked
3. **Selective** — allow specific crawlers, block others

Use the robots.txt template from the `wp-audit-seo-standards` skill (Section 9). Write the file to the WordPress root:

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

## Step 10: Generate llms.txt

Use the dynamic generator from the `wp-audit-seo-standards` skill (Section 8):

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

## Step 11: Auto-detect FAQ Schema

For each published page, check for FAQ content patterns and seed `rank_math_schema_FAQPage`:

```bash
$WP eval "
\$pages = get_posts(['post_type' => ['post','page'], 'posts_per_page' => -1, 'post_status' => 'publish']);
\$count = 0;
foreach (\$pages as \$p) {
    \$faqs = [];
    \$content = \$p->post_content;

    // 1. Check ACF repeater fields
    \$acf_names = ['faq_items', 'faqs', 'faq_cards', 'faq'];
    foreach (\$acf_names as \$field_name) {
        if (function_exists('have_rows') && have_rows(\$field_name, \$p->ID)) {
            while (have_rows(\$field_name, \$p->ID)) {
                the_row();
                \$q = get_sub_field('question') ?: get_sub_field('title');
                \$a = get_sub_field('answer')   ?: get_sub_field('content') ?: get_sub_field('text');
                if (\$q && \$a) {
                    \$faqs[] = ['q' => wp_strip_all_tags(\$q), 'a' => wp_strip_all_tags(\$a)];
                }
            }
        }
    }

    // 2. Check <details>/<summary> in content
    if (preg_match_all('/<summary[^>]*>(.*?)<\/summary>\s*(.*?)<\/details>/is', \$content, \$matches, PREG_SET_ORDER)) {
        foreach (\$matches as \$m) {
            \$q = wp_strip_all_tags(\$m[1]);
            \$a = wp_strip_all_tags(\$m[2]);
            if (\$q && \$a) { \$faqs[] = ['q' => \$q, 'a' => \$a]; }
        }
    }

    // 3. Check H2/H3 headings ending with ?
    if (preg_match_all('/<h[23][^>]*>(.*?\?)<\/h[23]>\s*<p>(.*?)<\/p>/is', \$content, \$matches, PREG_SET_ORDER)) {
        foreach (\$matches as \$m) {
            \$q = wp_strip_all_tags(\$m[1]);
            \$a = wp_strip_all_tags(\$m[2]);
            if (\$q && \$a) { \$faqs[] = ['q' => \$q, 'a' => \$a]; }
        }
    }

    if (!empty(\$faqs)) {
        \$schema = [
            '@context'   => 'https://schema.org',
            '@type'      => 'FAQPage',
            'mainEntity' => [],
        ];
        foreach (\$faqs as \$faq) {
            \$schema['mainEntity'][] = [
                '@type'          => 'Question',
                'name'           => \$faq['q'],
                'acceptedAnswer' => ['@type' => 'Answer', 'text' => \$faq['a']],
            ];
        }
        update_post_meta(\$p->ID, 'rank_math_schema_FAQPage', \$schema);
        \$count++;
        echo 'FAQ schema set for: ' . \$p->post_title . PHP_EOL;
    }
}
echo \"FAQ schema seeded for \$count pages.\";
"
```

## Step 12: Add Breadcrumbs to Theme

### 12a. Add PHP Function

Read the theme's `functions.php`. Add the `prefix_breadcrumbs()` function from the `wp-audit-seo-standards` skill (Section 10). Replace `prefix_` with the actual function prefix from CLAUDE.md:

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

### 12b. Add Breadcrumb Call to Templates

Edit the main template file (usually `header.php` or a layout partial). Insert the breadcrumb call after `</nav>` (main navigation) and before `<main`:

```php
<?php prefix_breadcrumbs(); ?>
```

### 12c. Add Breadcrumb CSS

Append breadcrumb styles to `assets/css/styles.css` using the CSS from the skill:

```css
/* Breadcrumbs */
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

### 12d. Enable Breadcrumbs in Rank Math

```bash
$WP eval "
\$opts = (array) get_option('rank-math-options-general', []);
\$opts['breadcrumbs'] = 'on';
update_option('rank-math-options-general', \$opts);
echo 'Breadcrumbs enabled.';
"
```

## Step 13: Set Permalinks

```bash
$WP rewrite structure '/%postname%/' --hard
```

## Step 14: Flush Caches

```bash
$WP eval "
if (class_exists('RankMath')) {
    delete_transient('rank_math_sitemap_cache');
    \RankMath\Sitemap\Cache::invalidate_storage();
    echo 'Sitemap cache invalidated.' . PHP_EOL;
}
"
$WP rewrite flush
```

If an object cache plugin is active:

```bash
$WP cache flush
```

## Step 15: Polylang-specific Rank Math Integration

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

## Verification

After all steps, output a summary and print key URLs:

```bash
$WP eval "
\$home = home_url('/');
echo '=== Rank Math Configuration Summary ===' . PHP_EOL;
echo 'Sitemap:    ' . \$home . 'sitemap_index.xml' . PHP_EOL;
echo 'robots.txt: ' . \$home . 'robots.txt' . PHP_EOL;
echo 'llms.txt:   ' . \$home . 'llms.txt' . PHP_EOL;

// Module count
\$modules = get_option('rank_math_modules', []);
echo 'Modules:    ' . count(\$modules) . ' active (' . implode(', ', \$modules) . ')' . PHP_EOL;

// Meta coverage
global \$wpdb;
\$total = \$wpdb->get_var(\"SELECT COUNT(*) FROM \$wpdb->posts WHERE post_type IN ('post','page') AND post_status='publish'\");
\$with_desc = \$wpdb->get_var(\"SELECT COUNT(*) FROM \$wpdb->posts p JOIN \$wpdb->postmeta m ON p.ID=m.post_id WHERE p.post_type IN ('post','page') AND p.post_status='publish' AND m.meta_key='rank_math_description' AND m.meta_value!=''\");
\$with_kw = \$wpdb->get_var(\"SELECT COUNT(*) FROM \$wpdb->posts p JOIN \$wpdb->postmeta m ON p.ID=m.post_id WHERE p.post_type IN ('post','page') AND p.post_status='publish' AND m.meta_key='rank_math_focus_keyword' AND m.meta_value!=''\");
echo \"Meta desc:  \$with_desc/\$total pages\" . PHP_EOL;
echo \"Focus kw:   \$with_kw/\$total pages\" . PHP_EOL;

// File checks
echo 'robots.txt: ' . (file_exists(ABSPATH . 'robots.txt') ? 'EXISTS' : 'MISSING') . PHP_EOL;
echo 'llms.txt:   ' . (file_exists(ABSPATH . 'llms.txt') ? 'EXISTS' : 'MISSING') . PHP_EOL;
"
```

## Rules

1. **Always read CLAUDE.md and .wp-create.json first** — these define the project context.
2. **Reference the `wp-audit-seo-standards` skill** for all option keys, meta keys, templates, and patterns.
3. **All WordPress interaction via WP-CLI** — never use PHP APIs outside of `$WP eval`.
4. **Merge options, never overwrite** — always read existing option array first with `get_option`, then merge.
5. **Ask user about AI crawler policy** before writing robots.txt.
6. **Use the correct function prefix** from CLAUDE.md — replace `prefix_` in all code.
7. **Determine schema type from industry** — LocalBusiness for service/retail/medical, Organization for SaaS/agency/portfolio.
