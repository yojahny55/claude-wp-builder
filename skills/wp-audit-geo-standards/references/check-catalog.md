# GEO check catalog

Part of the `wp-audit-geo-standards` skill (§3). Every GEO code, the ORA check ids it maps
to, and whether the theme can fix it. The ids are a snapshot of `GET https://ora.ai/api/checks`.

## Contents

- Legend
- Discovery — GEO-D
- Access — GEO-A (GEO-A25 to GEO-A28 are the plugin's own, outside the ORA score)
- Usability — GEO-U
- Payments — GEO-P

## Legend

Codes are `GEO-<layer><nn>`, layer letter D, A, U or P. Each maps to one or more ORA check
ids and is the unit the auditor tabulates and the fixer resolves. Grouped ORA ids are
expanded to the concrete ids in the check catalog snapshot. `yes` = the theme or host can
fix it. `advisory` = detected and reported, not fixed (off-site, network- or
third-party-dependent). `*` = only when the site type implies it.

### Discovery — GEO-D

| Code | ORA check ids | Fixable |
|---|---|---|
| GEO-D01 | `ard-catalog`, `ai-catalog-published`, `ard-entries-valid` | yes — `/.well-known/ard.json` + `ai-catalog.json` alias |
| GEO-D02 | `robots-ai-policy-quality`, `robots-agent-user-policy` | yes — robots policy + `Content-Signal` |
| GEO-D03 | `ard-trust-manifest` | yes — trust manifest in the ARD catalog |
| GEO-D04 | `agent-rules-repo`, `agent-plugins-repo` | yes — `/agents.md`, the AGENTS.md document served by `inc/agentic.php` |
| GEO-D05 | `brand-search-accuracy` | advisory — measured via ORA / DataForSEO |
| GEO-D06 | `agentic-search-specific`, `agentic-search-usecase` | advisory — share of voice |
| GEO-D07 | `wikipedia-presence` | advisory — off-site |
| GEO-D08 | `registry-branding`, `skills-sh-listed`, `chatgpt-app-listed`, `mcp-registry-listed`, `npm-sdk-package` | advisory — off-site |

### Access — GEO-A

| Code | ORA check ids | Fixable |
|---|---|---|
| GEO-A01 | `content-no-js` | yes — raw-HTML content ≥500 chars, first heading `H1`, sequential, ≥5% ratio |
| GEO-A02 | `bot-detection` | yes — AI crawler allowlist in the WAF and robots.txt |
| GEO-A03 | `redirect-hygiene` | yes — real 301/302, no meta-refresh or JS redirect |
| GEO-A04 | `agent-friendly-404` | yes — real 404 status + short markdown body |
| GEO-A05 | `docs-auth-gate` | yes — keep public pages ungated |
| GEO-A06 | `metadata-completeness` | yes — canonical + `lang` + `og:image` + `og:type` together |
| GEO-A07 | `json-ld` | yes, when no SEO plugin owns the graph (surface-templates.md §6.8) — identity JSON-LD |
| GEO-A08 | `json-ld-entity-linking` | yes, when no SEO plugin owns the graph (surface-templates.md §6.8) — `sameAs` |
| GEO-A09 | `org-schema-completeness` | yes, when no SEO plugin owns the graph (surface-templates.md §6.8) — `contactPoint` + `address` |
| GEO-A10 | `schema-type-breadth` | yes, when no SEO plugin owns the graph (surface-templates.md §6.8) — FAQPage/Service/Product/AggregateRating/BreadcrumbList |
| GEO-A11 | `trust-anchors` | yes — `/about`, `/contact`, `/privacy` each ≥500 chars |
| GEO-A12 | `sitemap`, `sitemap-lastmod` | yes — Rank Math `lastmod` on |
| GEO-A13 | `llms-txt-exists` | yes — dynamic endpoint |
| GEO-A14 | `llms-txt-formatting` | yes |
| GEO-A15 | `llms-txt-links-resolve` | yes |
| GEO-A16 | `modular-llms-txt` | yes — per-area `llms.txt` |
| GEO-A17 | `agent-instruction` | yes — "When to use" block |
| GEO-A18 | `page-token-budget` | yes — trim oversized pages |
| GEO-A19 | `markdown-negotiation`, `markdown-negotiation-vary`, `markdown-url-fallback`, `markdown-frontmatter`, `code-fence-validity`, `markdown-link-alternate` | yes — `Accept: text/markdown` + `Vary` |
| GEO-A20 | `link-headers-discovery` | yes — RFC 8288 `Link:` |
| GEO-A21 | `agent-discovery-file`, `agent-skills-index-v2` | yes — `/.well-known/agent-skills/index.json` |
| GEO-A22 * | `openapi-spec`, `public-api-docs`, `developer-portal`, `api-catalog-rfc9727` | SaaS/API only |
| GEO-A23 | `agent-crawler-reachability` | yes |
| GEO-A24 * | `pricing-info`, `pricing-md` | merchant/SaaS |
| GEO-A25 † | — no ORA id | yes — every referenced `@id` resolves inside the `@graph` |
| GEO-A26 † | — no ORA id | yes — no physical root file shadowing a theme rewrite |
| GEO-A27 † | — no ORA id | no — fixed at the CDN, not in the theme |
| GEO-A28 † | — no ORA id | yes — advertised URLs resolve and agree with the sitemap |

† GEO-A25 through GEO-A28 are **plugin-added**: the ORA catalog has no check that resolves a schema
reference, so a graph whose `publisher` points at an `@id` no node declares passes
`json-ld`, `json-ld-entity-linking` and `org-schema-completeness` alike. Report it
outside the ORA score — the score must stay reproducible against the published catalog.
The same holds for the three serving-layer and surface-agreement codes: ORA scores what a
URL returns, so it cannot see that the returning file is a physical one shadowing the
theme, that the canonical path only answers through a redirect, or that a surface
advertises pages the site does not publish.

### Usability — GEO-U

| Code | ORA check ids | Fixable |
|---|---|---|
| GEO-U01 | `ax-document-structure` | yes — `main`, landmarks, single H1, sequential |
| GEO-U02 | `ax-native-controls` | yes |
| GEO-U03 | `ax-accessible-names` | yes |
| GEO-U04 | `ax-form-labeling` | yes |
| GEO-U05 | `ax-tree-injection-safe` | yes |
| GEO-U06 * | `json-error-responses`, `api-error-model` | API only |
| GEO-U07 * | `mcp-server`, `mcp-server-identity`, `mcp-tool-listing`, `mcp-tool-naming`, `mcp-tool-descriptions`, `mcp-param-schemas`, `mcp-tool-annotations`, `mcp-resource-listing`, `mcp-resource-quality`, `mcp-auth-mechanism`, `mcp-oauth-metadata`, `mcp-pkce-s256`, `mcp-error-handling`, `mcp-transport-modern`, `mcp-server-card`, `mcp-multi-surface-coverage` | MCP only |
| GEO-U08 * | `oauth-support`, `oauth-protected-resource`, `scoped-permissions`, `auth-md-exists`, `auth-md-structure`, `auth-md-walkthrough-simulation`, `agent-auth-discovery-metadata`, `agent-auth-www-authenticate`, `agent-auth-endpoints-reachable` | API/MCP only |
| GEO-U09 * | `onboarding-friction`, `sandbox-environment` | SaaS only |
| GEO-U10 | `cli-tool`, `webmcp`, `a2ui-support`, `nlweb-schema-feeds`, `nlweb-ask`, `nlweb-streaming` | advisory / emerging |

### Payments — GEO-P (merchant only, `N/A` on a catalog store)

| Code | ORA check ids | Fixable |
|---|---|---|
| GEO-P01 | `acp-support`, `acp-delegate-payment` | advisory |
| GEO-P02 | `ucp-support` | advisory |
| GEO-P03 | `mpp-support` (the Machine Payments Protocol; MCP payment rides on the MCP surface checks in GEO-U07) | advisory |
| GEO-P04 | `x402-support` | advisory |
| GEO-P05 | `ap2-support` | advisory |

Payment protocols are advisory for WooCommerce, because no WooCommerce gateway implements an
agent payment protocol (SKILL.md §8). The fixer reports the recommendation and does not
fabricate protocol support. On a catalog store all five are `N/A` (SKILL.md §2).
