# GEO surface templates

Part of the `wp-audit-geo-standards` skill. What each surface `inc/agentic.php` serves
must contain, and which ORA check it satisfies. `agents/wp-agentic-surfaces.md` holds the
executable version of each; this file is the specification both agents check it against.
Every surface is applicability-gated: a content site emits no API or payment surface.

## Contents

- 4. The robots.txt body
- 6.1 Dynamic `llms.txt`
- 6.2 `/.well-known/ard.json` (Agentic Resource Discovery)
- 6.3 `/.well-known/agent-skills/index.json` v0.2.0
- 6.4 `pricing.md`
- 6.5 Markdown negotiation
- 6.6 RFC 8288 `Link:` headers
- 6.7 Agent-friendly 404
- 6.8 JSON-LD identity and breadth
- 6.9 Trust anchors
- 6.10 `llms-full.txt` and `auth.md`

## 4. The robots.txt body

The whole file, as the fixer's Step 4 writes it: the classic block, every ALLOW crawler of
the allowlist in SKILL.md §4, the BLOCK row, the `Content-Signal` comment and the sitemap.
`Content-Signal` itself is the HTTP header (§4), never a directive line here.

```
User-agent: *
Allow: /
Disallow: /wp-admin/
Allow: /wp-admin/admin-ajax.php
Disallow: /wp-includes/
Disallow: /search/
Disallow: /?s=

User-agent: GPTBot
Allow: /

User-agent: OAI-SearchBot
Allow: /

User-agent: ChatGPT-User
Allow: /

User-agent: ClaudeBot
Allow: /

User-agent: PerplexityBot
Allow: /

User-agent: Google-Extended
Allow: /

User-agent: GoogleOther
Allow: /

User-agent: Applebot-Extended
Allow: /

User-agent: Amazonbot
Allow: /

User-agent: FacebookBot
Allow: /

User-agent: Bytespider
Disallow: /

# Content-Signal: ai-train=yes, search=yes, ai-retrieval=yes (sent as an HTTP header on every response)
Sitemap: {home_url}/sitemap_index.xml
```

## 6.1 Dynamic `llms.txt`

Route `/llms.txt` (and `/llms-full.txt`) through WordPress, not a static file — a
static file goes stale. Structure:

```
# {Site Name}

> {One-line site description}

## Key Facts
- {Identity, location, hours, what the site sells/offers}
- {Trust anchors: founded, credentials, first-party numbers}

## Pages
- [Page Title](url): excerpt or first 20 words

## Posts
- [Post Title](url): excerpt

## When to use
- {Agent-facing guidance: what this site is authoritative for, and when to reach it}

## Contact
- Website: {home_url}
```

Per-area modular files (`/services/llms.txt`, `/docs/llms.txt`, …) satisfy
`modular-llms-txt`. Every link must resolve (`llms-txt-links-resolve`) and carry a
short description (`llms-txt-formatting`).

## 6.2 `/.well-known/ard.json` (Agentic Resource Discovery)

The canonical path. Keep `/.well-known/ai-catalog.json` answering the same document as an
alias: scanners written against the earlier name still request it. Each entry names a
resource with a `urn:air` identifier, a media type, and exactly one of `url` or `data`:

```json
{
  "catalog": {
    "id": "urn:air:example.com:catalog",
    "name": "Example Site",
    "entries": [
      {
        "id": "urn:air:example.com:mcp:docs",
        "name": "Docs MCP",
        "mediaType": "application/json",
        "url": "https://example.com/mcp"
      }
    ]
  }
}
```

`ard-trust-manifest` adds the provenance/trust block alongside the entries.

## 6.3 `/.well-known/agent-skills/index.json` v0.2.0

```json
{
  "version": "0.2.0",
  "skills": [
    {
      "name": "example-skill",
      "description": "What the skill does",
      "url": "https://example.com/.well-known/agent-skills/example-skill.md",
      "digest": {
        "algorithm": "sha256",
        "value": "sha256:..."
      }
    }
  ]
}
```

The digest is a real `sha256:` of the referenced document — recompute it whenever the
document changes, or the index is silently invalid.

## 6.4 `pricing.md`

For merchant/SaaS sites, publish `/pricing.md` (and keep `/pricing` as the HTML page):
a plain-markdown table of plans, prices, currency and billing period, plus a one-line
answer per tier. `pricing-info` also accepts the HTML page; `pricing-md` wants the
markdown sibling.

## 6.5 Markdown negotiation

When the request's `Accept` header includes `text/markdown`, serve a markdown rendering
of the page (or a link to one) and always send:

```
Vary: Accept
Content-Type: text/markdown; charset=UTF-8
```

Balanced code fences (`code-fence-validity`) and optional YAML frontmatter
(`markdown-frontmatter`) are required for a clean markdown response.

## 6.6 RFC 8288 `Link:` headers

Emit discovery relations on HTML responses, e.g.:

```
Link: <https://example.com/llms.txt>; rel="alternate"; type="text/plain",
      <https://example.com/sitemap_index.xml>; rel="sitemap",
      <https://example.com/.well-known/api-catalog>; rel="api-catalog"
```

## 6.7 Agent-friendly 404

Return a real HTTP `404` with a short markdown body that points agents at the sitemap
and `llms.txt`:

```
# 404 — Not found

The page you asked for does not exist.
- Site map: /sitemap_index.xml
- Machine summary: /llms.txt

Try one of those, or search the site.
```

Never serve a `200` "soft 404"; `agent-friendly-404` checks the status line, not the
body alone. A soft 404 is not only the missing-page template: probe a made-up top-level slug,
a made-up nested path, a typo or near-prefix of a real post slug (WordPress's
`redirect_guess_404_permalink` redirects it to the closest post with `200`) and a made-up
`.php`/`.html` path, on both the apex and `www` hosts. An apex-to-`www` redirect that sends
unknown paths to the home page with `200` is a soft 404 too. One passing shape does not pass
the check.

## 6.8 JSON-LD identity and breadth

Emit one identity graph (Organization / LocalBusiness) with `contactPoint`, `address`
and a populated `sameAs` array (entity linking). Add breadth types Rank Math does not
already emit — `FAQPage`, `Service`, `Product`, `AggregateRating`, `BreadcrumbList` —
**guarded against duplicate schema sources**: if Rank Math already emits a type, the
theme must not emit it a second time (§16 of the SEO standards skill).

All of this is for a site with no SEO plugin. When Rank Math, Yoast or SEOPress owns the
schema, the theme emits no JSON-LD at all — a second identity graph beside the plugin's is
the duplicate source SEO-039 reports — so GEO-A07 to GEO-A10 cannot be fixed from the
theme. They are reported as dependent on the SEO plugin's configuration, and
`wp-audit-rankmath` fills the plugin's Organization / LocalBusiness `contactPoint`,
`address` and `sameAs` (Rank Math emits neither `contactPoint` nor `address` by default).

## 6.9 Trust anchors

Ensure `/about`, `/contact`, `/privacy` exist as real published pages with ≥500
characters each, seeded from the demo header/footer copy. They satisfy both
`trust-anchors` and give the entity graph something to link to.

## 6.10 `llms-full.txt` and `auth.md`

`/llms-full.txt` is the `/llms.txt` route family carrying the body text of published
pages and posts (capped at the first 200 — an unbounded dump can exhaust memory on a
content-heavy site; `/llms.txt` remains the complete index), for agents that ingest the
whole site. `/auth.md` (SaaS/API only) is the credential walkthrough an agent reads before
calling the API — scheme, discovery endpoints and a numbered obtain-and-send flow — and
satisfies `auth-md-exists`, `auth-md-structure` and `auth-md-walkthrough-simulation`
(GEO-U08).
