# llms.txt and robots.txt

Part of the `wp-audit-seo-standards` skill; section numbers match its SKILL.md.

## Contents

- 8. llms.txt — a GEO route, never a physical file
- 9. robots.txt — the classic block, and the one agent that writes the file

## 8. llms.txt

`llms.txt` is not written by this skill. It is a dynamic route in the theme's
`inc/agentic.php`, emitted by the `wp-agentic-surfaces` agent to the structure in
`wp-audit-geo-standards` §6.1, and audited as GEO-A13 to GEO-A16.

**Never write a physical `llms.txt`.** The web server answers a file at the web root before
PHP runs, so a file written to `ABSPATH . 'llms.txt'` shadows the theme's route for good: the file is stale the moment content changes, and the audit reports it as GEO-A26
(ERROR). This skill used to ship exactly that generator, and `/wp-audit` dispatches the SEO
fixes before the GEO fixes, so every site fixed by both ended with a stale file in front of
the fresh route.

Check what is served, and whether a file is in the way:

```bash
$WP eval "echo file_exists(ABSPATH . 'llms.txt') ? 'PHYSICAL llms.txt present -- GEO-A26' : 'no physical llms.txt';"
curl -s -o /dev/null -w '%{http_code} %{content_type}\n' "<site-url>/llms.txt"   # 200 text/plain, from the route
```

## 9. robots.txt

The SEO half of `robots.txt` is the classic block: it keeps crawlers out of the admin and
the search results, and points at the sitemap.

```
User-agent: *
Allow: /
Disallow: /wp-admin/
Allow: /wp-admin/admin-ajax.php
Disallow: /wp-includes/
Disallow: /search/
Disallow: /?s=

Sitemap: {home_url}/sitemap_index.xml
```

The AI-crawler half — each AI crawler named in its own `User-agent` block, Bytespider
disallowed, and the `Content-Signal` HTTP header that must agree with them — is
`wp-audit-geo-standards` §4. The file has **one writer**: `wp-agentic-surfaces` Step 4
writes this classic block, the allowlist and the sitemap line together, after confirming
the site owner's AI-crawler posture. Do not write a second version. This skill's old
template named six of the ten crawlers GEO-D02 requires, so whichever agent ran last
decided whether the GEO audit passed.

When no GEO fix runs, leave `robots.txt` alone: WordPress serves a virtual one, and Rank
Math's General Settings manage its contents.
