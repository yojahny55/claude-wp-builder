---
name: wp-audit-seo-standards
description: Rank Math SEO reference for WordPress — detecting the plugin, the module, option and post meta keys (rank-math-options-titles), title templates and meta descriptions to seed with WP-CLI, JSON-LD schema templates, breadcrumbs, the classic robots.txt block, sitemap failure modes such as a sitemap_index.xml that 404s or returns HTML, the category-noindex gate, duplicate theme JSON-LD, title and description length limits, the Lighthouse link-text trap, and WooCommerce SEO checks SEO-064 to SEO-068. Use when auditing, configuring or seeding SEO on a site running Rank Math (wp-audit-seo, wp-audit-rankmath), or when per-category noindex, the sitemap or link-text fails. Not for llms.txt, AI-crawler rules in robots.txt or the Content-Signal header (wp-audit-geo-standards), and not for NAP or LocalBusiness subtype checks (wp-audit-local-standards).
user-invocable: false
---

# SEO Standards — Rank Math Reference

This skill defines the SEO configuration standards, schema templates, and seeding commands for WordPress sites using **Rank Math SEO** as the primary SEO plugin. `$WP` throughout is the WP-CLI wrapper from the project's `.wp-create.json` (`wp_cli.wrapper`).

---

## Reference files

Rules, keys and gotchas stay in this file. Templates and scripts live in `references/`, under
the same section numbers they carry here:

- [references/schema-templates.md](references/schema-templates.md) — §5 JSON-LD templates and the
  §11 FAQ generator. Read when emitting or checking structured data.
- [references/seeding-commands.md](references/seeding-commands.md) — WP-CLI blocks for §3 options,
  §4 post meta, §6 title templates and §7 meta descriptions. Read when seeding SEO data.
- [references/llms-and-robots.md](references/llms-and-robots.md) — §8 llms.txt and §9 robots.txt:
  the classic robots block, and why neither file is written from here. Read before touching
  either file.
- [references/breadcrumbs.md](references/breadcrumbs.md) — §10 `prefix_breadcrumbs()`, its CSS and
  the Rank Math switch. Read when adding breadcrumbs to a theme.
- [references/audit-gotchas.md](references/audit-gotchas.md) — §13 to §17: the link-text and
  meta-description traps, the category-noindex gate, the sitemap failure modes and their
  validator, duplicate JSON-LD detection, and the length check. Read before reporting an SEO
  finding fixed, or when validating the sitemap or the schema.
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

## 6. Title Templates by Page Type

| Page Type | Title template |
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

## 8. llms.txt

A dynamic route in `inc/agentic.php`, emitted by `wp-agentic-surfaces` to
`wp-audit-geo-standards` (`references/surface-templates.md` §6.1) — never a physical file.
A `llms.txt` at the web root shadows the route and is reported as GEO-A26. See
[references/llms-and-robots.md](references/llms-and-robots.md).

---

## 9. robots.txt

The classic block (admin, search results, sitemap) is in
[references/llms-and-robots.md](references/llms-and-robots.md). The AI-crawler allowlist
and the `Content-Signal` header are `wp-audit-geo-standards` §4, and the whole file has one
writer, `wp-agentic-surfaces` Step 4, which confirms the owner's AI-crawler posture first.

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

## 12. After seeding: flush and verify

The order of a full setup is `wp-audit-rankmath`'s Steps 1 to 15, which run it. When they
are done, flush the sitemap cache and the rewrite rules:

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

# robots.txt and llms.txt are served, not files: check the response
$WP eval "foreach (array('robots.txt', 'llms.txt') as \$f) { \$r = wp_remote_get(home_url('/' . \$f)); echo \$f . ': HTTP ' . wp_remote_retrieve_response_code(\$r) . PHP_EOL; }"

# A physical llms.txt shadows the dynamic route (GEO-A26)
$WP eval "echo file_exists(ABSPATH . 'llms.txt') ? 'PHYSICAL llms.txt present -- GEO-A26' : 'no physical llms.txt';"
```

Fix what a line reports, re-run the block, and stop when the titles print, the description
count equals the published total, both files answer `HTTP 200` and no physical `llms.txt` is
present.

---

## 13–17. Audit gotchas

Each rule below has its sample, detection command or validator in
[references/audit-gotchas.md](references/audit-gotchas.md), under the same number.

- **§13 Lighthouse `link-text` reads visible innerText, never `aria-label`.** Keep a
  design's "LEARN MORE" and pass by appending a `.screen-reader-text` suffix inside the
  anchor — the clip pattern, never `display:none`, which innerText skips. And let the SEO
  plugin own the meta description: a theme fallback becomes a duplicate tag.
- **§14 Rank Math ignores `tax_category_robots_<term_id>` unless `tax_category_custom_robots`
  is `'on'`**, saved in the same `update_option` call. Without the gate, per-category
  noindex is silently discarded.
- **§15 Eleven sitemap failure modes.** The first two — a sitemap that 404s or returns HTML —
  are the missing `rank_math_registration_skip` and `rank_math_is_configured` flags.
- **§16 When Rank Math is active, the theme emits no JSON-LD of its own.** Two schema blocks
  are duplicate structured data.
- **§17 Titles stop at 60 characters; descriptions run 70 to 160.**

---

## 18. E-commerce SEO nuances (WooCommerce)

The store-only checks SEO-064 to SEO-068: faceted canonicals, paginated categories,
`Offer.availability` against real stock, sitemap against noindex, and the post-migration
reminder. They apply only when `/wp-audit` Step 2.3 sets `site.commerce` to `woocommerce`, and
every live fetch targets the production host: see
[references/woocommerce-seo.md](references/woocommerce-seo.md).
