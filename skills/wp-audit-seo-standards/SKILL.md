---
name: wp-audit-seo-standards
description: Rank Math SEO reference — plugin detection, module and option keys, post meta keys, schema JSON-LD templates, title and description formulas, llms.txt and robots.txt templates, breadcrumbs, sitemap failure modes and WooCommerce SEO checks. Use when auditing, configuring or seeding SEO on a WordPress site that runs Rank Math (the wp-audit-seo and wp-audit-rankmath agents).
user-invocable: false
---

# SEO Standards — Rank Math Reference

This skill defines the SEO configuration standards, schema templates, and seeding commands for WordPress sites using **Rank Math SEO** as the primary SEO plugin.

---

## Reference files

Rules, keys and gotchas stay in this file. Templates and scripts live in `references/`, under
the same section numbers they carry here:

- [references/schema-templates.md](references/schema-templates.md) — §5 JSON-LD templates and the
  §11 FAQ generator. Read when emitting or checking structured data.
- [references/seeding-commands.md](references/seeding-commands.md) — WP-CLI blocks for §3 options,
  §4 post meta, §6 title templates and §7 meta descriptions. Read when seeding SEO data.
- [references/llms-and-robots.md](references/llms-and-robots.md) — §8 llms.txt and §9 robots.txt,
  templates and generators. Read when writing either file.
- [references/breadcrumbs.md](references/breadcrumbs.md) — §10 `prefix_breadcrumbs()`, its CSS and
  the Rank Math switch. Read when adding breadcrumbs to a theme.
- [references/woocommerce-seo.md](references/woocommerce-seo.md) — §18, the store-only checks
  SEO-064 to SEO-068. Read only when `site.commerce` is `woocommerce`.

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
$WP eval 'RankMath\Installer::create_tables(get_option("rank_math_modules"));'
```

The second call is not optional. Writing the option skips the activation that creates the
`{prefix}rank_math_404_logs` and `{prefix}rank_math_redirections` tables, and the two modules
then run a failing query on every request (TTFB several seconds on a real build).
`wp-audit-rankmath` Step 2.1 verifies both tables; `/wp-audit` reports a missing one as PERF-060.

---

## 3. Rank Math Option Keys

| Option | Purpose |
|--------|---------|
| `rank_math_modules` | Array of active module slugs |
| `rank-math-options-general` | Breadcrumbs, links, image SEO, strip category base |
| `rank-math-options-titles` | Title templates, schema type, social profiles, noindex rules |
| `rank-math-options-sitemap` | Sitemap inclusions, ping settings |
| `rank-math-options-instant-indexing` | IndexNow configuration |

Rank Math stores options as serialized arrays. Always merge rather than overwrite.
Read and write blocks: see [references/seeding-commands.md](references/seeding-commands.md).

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


Seeding commands — one post, and bulk descriptions from content: see
[references/seeding-commands.md](references/seeding-commands.md).

---

## 5. Schema JSON-LD Templates

Organization, LocalBusiness, FAQPage, BreadcrumbList and Article templates: see
[references/schema-templates.md](references/schema-templates.md).

`<category_base>` is never assumed to be `category`: read it with `$WP option get category_base`
(empty means the default, `category`) and the tag equivalent with `$WP option get tag_base`
(empty means `tag`). Build archive URLs from those values, or from `get_term_link()`.

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

Seed them with the block in [references/seeding-commands.md](references/seeding-commands.md).

---

## 7. Meta Description Generation

### Priority Order

1. **Manual** — `rank_math_description` post meta (highest priority)
2. **Excerpt** — Post excerpt if set
3. **First paragraph** — First `<p>` block in post content
4. **Trimmed content** — First 155 characters of stripped content

**Target length:** 150–160 characters.

The generator function and the bulk seed: see
[references/seeding-commands.md](references/seeding-commands.md).

---

## 8. llms.txt Template

Template and WP-CLI generator: see [references/llms-and-robots.md](references/llms-and-robots.md).

---

## 9. robots.txt Template

Template and WP-CLI generator: see [references/llms-and-robots.md](references/llms-and-robots.md).

> **Note:** AI crawler policy (Allow vs Disallow) should be confirmed with the site owner before writing. The defaults above allow all major AI crawlers except Bytespider.

---

## 10. Breadcrumb Integration Code

`prefix_breadcrumbs()`, its CSS and the Rank Math switch: see
[references/breadcrumbs.md](references/breadcrumbs.md).

---

## 11. FAQ Detection Patterns

FAQ content can appear in several forms. Detect and convert to JSON-LD schema automatically.

### Detection Sources

1. **ACF repeater fields** — field names: `faq_items`, `faqs`, `faq_cards`, `faq`
2. **`<details>/<summary>` HTML** — accordion-style FAQ in content
3. **H2/H3 headings ending with `?`** — followed by `<p>` answer content

The auto-detection generator and its `wp_head` hook: see
[references/schema-templates.md](references/schema-templates.md).

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

---

## 13. Lighthouse SEO Audit Gotchas (hard-won)

Non-obvious traps that make a fix *look* applied while the audit keeps failing. Verify against these before reporting an SEO finding fixed.

### `link-text` matches VISIBLE innerText — not `aria-label`

The Lighthouse `link-text` audit (`core/audits/seo/link-text.js`) lowercases/trims the anchor's **`link.text`** (rendered innerText) and checks it against a blocklist: `click here`, `here`, `learn more`, `more`, `read more`, `this`, `start`, … (per-language). **`aria-label`, `title`, and `nodeLabel` are ignored** — adding an `aria-label` fixes the a11y accessible-name but does **not** satisfy this SEO audit.

To keep a design's non-descriptive label (e.g. a "LEARN MORE" button) *and* pass, append a visually-hidden descriptive suffix **inside** the anchor so it becomes part of innerText:

```php
<a class="btn" href="<?php echo esc_url( $url ); ?>">
    <?php echo esc_html( $label ); // e.g. "LEARN MORE" — stays visible ?>
    <?php if ( $context ) : ?><span class="screen-reader-text"><?php
        echo esc_html( 'about ' . $context ); // e.g. "about Home Search"
    ?></span><?php endif; ?>
</a>
```

Now `link.text` = "LEARN MORE about Home Search" → not a blocklist match → audit passes; the button still visually reads "LEARN MORE".

- **Critical:** the hidden span must use the `.screen-reader-text` **clip** pattern (`position:absolute; clip: rect(...); width:1px`) — NOT `display:none` or `visibility:hidden`, which are excluded from innerText and would fail again. (A `.screen-reader-text` rule is required in the theme CSS; see a11y standards.)
- The same non-descriptive label often repeats across a reusable button component — fix the component/template part once, then re-check *every* page that uses it (Lighthouse audits per-URL; a homepage pass doesn't clear inner pages).
- `identical-links-same-purpose` (a11y, weight 0) can also flag two same-text links (e.g. two "VIEW ALL") pointing to different destinations — the same hidden-suffix technique resolves it.

### Meta description: let the SEO plugin own it — don't emit a theme fallback

If Rank Math (or Yoast) is active and configured, do **not** also `echo` a hardcoded `<meta name="description">` from the theme `wp_head`. Two tags = a duplicate-description warning, and the plugin's dynamic/templated value is the one you want. A common failure mode: a theme adds a front-page meta-description fallback "to be safe" while the SEO plugin's setup wizard was incomplete → once the wizard is finished, the tag is duplicated. Remove the theme fallback; verify only one `<meta name="description">` renders (`curl -s <url> | grep -o 'name="description"' | wc -l` → `1`).

## 14. Category noindex — the dual-option gotcha (CRITICAL)

Rank Math ignores `tax_category_robots` unless `tax_category_custom_robots = 'on'`.
Without the gate, per-category noindex settings are silently discarded.

```php
// WRONG — silently does nothing:
$opts['tax_category_robots_' . $term_id] = ['noindex'];

// CORRECT — must also set the gate:
$opts['tax_category_custom_robots'] = 'on';
$opts['tax_category_robots_' . $term_id] = ['noindex'];
```

Both options must be saved in the same `update_option` call. The gate is a
site-wide switch that enables per-term robots control. Without it, Rank Math
falls back to the global robots setting for ALL categories.

**Verification:**
```bash
# Check gate is set
$WP eval "echo get_option('rank-math-options-titles')['tax_category_custom_robots'] ?? 'NOT SET';"

# Check specific category
$WP eval "
\$term = get_term_by('slug', '<thin-category-slug>', 'category');
\$opts = get_option('rank-math-options-titles');
echo 'Gate: ' . (\$opts['tax_category_custom_robots'] ?? 'MISSING') . PHP_EOL;
echo 'Robots: ' . print_r(\$opts['tax_category_robots_' . \$term->term_id] ?? 'NOT SET', true);
"
```

---

## 15. Sitemap failure modes (11 known)

After generating the sitemap, validate against these failure modes:

| # | Failure | Detection | Fix |
|---|---------|-----------|-----|
| 1 | Sitemap 404 | `curl -sI /sitemap_index.xml` returns 404 | Set `rank_math_registration_skip = 1` and `rank_math_is_configured = 1` |
| 2 | Sitemap returns HTML | Response contains `<!DOCTYPE html` | registration_skip flag missing, or rewrite rules flushed |
| 3 | Missing CPTs | Check `<sitemap>` entries for each translated post type | Register CPTs before `pll_init` fires (hook `init` at priority 99) |
| 4 | Noindex pages in sitemap | Compare `rank_math_robots` meta with sitemap URLs | Rank Math should exclude noindex, but verify |
| 5 | Draft posts in sitemap | Query `post_status IN ('draft','private')` | Rank Math excludes by default, but check after bulk operations |
| 6 | Redirected URLs in sitemap | Check Rank Math redirections vs sitemap URLs | Remove redirected URLs from sitemap |
| 7 | Blocked URLs (robots.txt) | Compare sitemap URLs with robots.txt Disallow | Remove blocked URLs from sitemap |
| 8 | Duplicate URLs | Parse sitemap XML for duplicate `<loc>` values | Check canonical settings |
| 9 | Wrong lastmod dates | Compare `<lastmod>` with `post_modified` | Rank Math uses post_modified, verify matches |
| 10 | Attachment pages in sitemap | Check `pt_attachment_sitemap` option | Set to `off` |
| 11 | Wrong canonical URLs in sitemap | Compare `<loc>` with `get_permalink()` | Check permalink structure and canonical settings |

**Validation script:**
```bash
$WP eval "
\$url = home_url('/sitemap_index.xml');
\$r = wp_remote_get(\$url);
\$code = wp_remote_retrieve_response_code(\$r);
\$body = wp_remote_retrieve_body(\$r);
\$ct = wp_remote_retrieve_header(\$r, 'content-type');

echo \"HTTP \$code | Content-Type: \$ct\n\";
if (\$code !== 200) echo \"FAIL: Sitemap not accessible\n\";
if (stripos(\$body, '<!DOCTYPE html') !== false) echo \"FAIL: Returns HTML\n\";
if (stripos(\$body, '<sitemapindex') === false && stripos(\$body, '<urlset') === false) echo \"FAIL: Missing XML root\n\";

\$skip = get_option('rank_math_registration_skip', 0);
\$cfg = get_option('rank_math_is_configured', 0);
if (!\$skip) echo \"FAIL: registration_skip not set\n\";
if (!\$cfg) echo \"FAIL: is_configured not set\n\";
echo 'Done.';
"
```

---

## 16. Schema conflict detection

When Rank Math is active, the theme should NOT emit its own JSON-LD.
Two schema blocks = duplicate structured data = Google may ignore both.

```bash
# Check for theme JSON-LD
$WP eval "
\$it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator(get_template_directory()));
\$conflicts = [];
foreach (\$it as \$f) {
    if (\$f->getExtension() !== 'php') continue;
    if (strpos(file_get_contents(\$f->getPathname()), 'application/ld+json') !== false) {
        \$conflicts[] = \$f->getFilename();
    }
}
if (\$conflicts) {
    echo 'CONFLICT: Theme JSON-LD in: ' . implode(', ', \$conflicts) . PHP_EOL;
    echo 'FIX: Remove theme JSON-LD when Rank Math handles schema.' . PHP_EOL;
} else {
    echo 'OK: No theme JSON-LD conflicts.' . PHP_EOL;
}
"
```

---

## 17. Title/description quality thresholds

Not just missing — but too long or too short.

| Field | Min | Max | Google behavior |
|-------|-----|-----|-----------------|
| Title | — | 60 chars (~580px) | Truncated with "…" in SERP |
| Description | 70 chars | 160 chars | Truncated or replaced with snippet |

**Pixel width note:** Google truncates by pixel width, not character count.
For Latin scripts, 60 chars ≈ 580px. For scripts with wider characters
(CJK, Cyrillic), the char limit is lower. Use the Rank Math editor's pixel
preview when available.

**Validation:**
```bash
$WP eval "
\$posts = get_posts(['post_type'=>['post','page'],'posts_per_page'=>-1,'post_status'=>'publish']);
foreach (\$posts as \$p) {
    \$t = get_post_meta(\$p->ID, 'rank_math_title', true) ?: \$p->post_title;
    \$d = get_post_meta(\$p->ID, 'rank_math_description', true);
    if (mb_strlen(\$t) > 60) echo 'LONG TITLE ['.mb_strlen(\$t).'] #'.\$p->ID.': '.mb_substr(\$t,0,60).'...' . PHP_EOL;
    if (\$d && mb_strlen(\$d) > 160) echo 'LONG DESC ['.mb_strlen(\$d).'] #'.\$p->ID . PHP_EOL;
    if (\$d && mb_strlen(\$d) < 70) echo 'SHORT DESC ['.mb_strlen(\$d).'] #'.\$p->ID . PHP_EOL;
}
"
```

---

## 18. E-commerce SEO nuances (WooCommerce)

The store-only checks SEO-064 to SEO-068: faceted canonicals, paginated categories,
`Offer.availability` against real stock, sitemap against noindex, and the post-migration
reminder. They apply only when `/wp-audit` Step 2.3 sets `site.commerce` to `woocommerce`, and
every live fetch targets the production host: see
[references/woocommerce-seo.md](references/woocommerce-seo.md).
