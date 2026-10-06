# SEO audit gotchas and validators

Part of the `wp-audit-seo-standards` skill; section numbers match its SKILL.md, which keeps
the rule each section proves. Read before reporting an SEO finding fixed, or when validating
the sitemap, the schema or the title and description lengths.

## Contents

- 13. Lighthouse SEO Audit Gotchas (hard-won)
- 14. Category noindex — the dual-option gotcha (CRITICAL)
- 15. Sitemap failure modes (11 known)
- 16. Schema conflict detection
- 17. Title/description quality thresholds

## 13. Lighthouse SEO Audit Gotchas (hard-won)

Non-obvious traps that make a fix *look* applied while the audit keeps failing. Verify against these before reporting an SEO finding fixed.

### `link-text` matches VISIBLE innerText — not `aria-label`

The Lighthouse `link-text` audit (`core/audits/seo/link-text.js`) lowercases/trims the anchor's **`link.text`** (rendered innerText) and checks it against a blocklist: `click here`, `here`, `learn more`, `more`, `read more`, `this`, `start`, … (per-language). **`aria-label`, `title`, and `nodeLabel` are ignored** — adding an `aria-label` fixes the a11y accessible-name but does **not** satisfy this SEO audit.

To keep a design's non-descriptive label (e.g. a "LEARN MORE" button) *and* pass, append a visually-hidden descriptive suffix **inside** the anchor so it becomes part of innerText:

```php
<a class="btn" href="<?php echo esc_url( $url ); ?>">
    <?php echo esc_html( $label ); // e.g. "LEARN MORE" — stays visible ?>
    <?php if ( $context ) : ?><span class="screen-reader-text"><?php
        /* translators: %s: what the link leads to, e.g. "Home Search" */
        echo esc_html( sprintf( __( 'about %s', 'theme-slug' ), $context ) );
    ?></span><?php endif; ?>
</a>
```

Now `link.text` = "LEARN MORE about Home Search" → not a blocklist match → audit passes; the button still visually reads "LEARN MORE".

- **Critical:** the hidden span must use the `.screen-reader-text` **clip** pattern (`position:absolute; clip: rect(...); width:1px`) — NOT `display:none` or `visibility:hidden`, which are excluded from innerText and would fail again. (A `.screen-reader-text` rule is required in the theme CSS; see a11y standards.) The suffix is
  translatable text like any other: under Polylang it reads in the page's language.
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

Fix each `FAIL` line, re-run the script, and stop when it prints only the `HTTP 200` line and
`Done.`.

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

Rewrite each reported title or description, re-run, and stop when the script prints nothing.
