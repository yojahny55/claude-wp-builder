# llms.txt and robots.txt

Part of the `wp-audit-seo-standards` skill; section numbers match its SKILL.md.

## Contents

- 8. llms.txt Template — template, then the WP-CLI generator
- 9. robots.txt Template — template, AI crawler defaults, then the WP-CLI generator

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
