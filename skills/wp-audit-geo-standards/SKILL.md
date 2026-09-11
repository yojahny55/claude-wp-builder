---
name: wp-audit-geo-standards
description: GEO and AI-agent-readiness reference — the ORA/is-agentic check catalog, applicability by site type, AI crawler allowlist, llms.txt/well-known specs, GEO citability rubric, and WordPress implementation templates
user-invocable: false
---

# GEO & Agent-Readiness Standards

Scored by **ORA**, surfaced at [is-agentic.com](https://is-agentic.com). Four layers,
125 checks. Full live catalog: `GET https://ora.ai/api/checks`.

This skill informs the audit (`agents/wp-audit-geo.md`) and the fix
(`agents/wp-agentic-surfaces.md`). It never runs commands on its own.

---

## 1. Scoring model

| Layer | Weight | Checks |
|---|---|---|
| Discovery | 20 | 16 |
| Access | 30 | 41 |
| Usability | 40 | 62 |
| Payments | 10 | 6 |
| **Total** | **100** | **125** |

Each check belongs to one of three tiers:

| Tier | Count | Pool |
|---|---|---|
| `required` | 29 checks | share an **80**-point Essential pool |
| `recommended` | 76 checks | share **20** points |
| `emerging` | 20 checks | bonus-only, capped at +5 |

**Non-applicable checks are excluded, never failed.** A brochure site is not
penalized for having no API, OAuth, MCP, or payment surface — those checks are
reported `N/A` exactly as ORA excludes them.

Grades: **A+** 95+ · **A** 86+ · **B** 70+ · **C** 48+ · **D** 28+ · **F** <28.

The weighted layer score is `Σ(maxScore of passed applicable checks) / Σ(maxScore of
applicable checks)`, re-weighted against the layers that apply. The Essential pool is
scored before the bonus pool: a `required` failure costs more than a `recommended`
failure, and an `emerging` pass can only lift the grade, never save it.

---

## 2. Applicability by site type

Site type is **detected, not assumed**, from the project's `.claude/CLAUDE.md`
(`industry`), active plugins, registered REST namespaces, page inventory, and
templates. Every check not implied by the detected type is reported `N/A`.

| Site type | Detection | Layers that apply |
|---|---|---|
| content / publisher / service | default | Discovery + Access + GUI-Usability |
| **local business** | `industry` = local/business + address fields | + LocalBusiness schema, NAP, reviews |
| **merchant** | WooCommerce active | + Payments, `pricing.md`, Product schema |
| **SaaS** / public API | custom REST namespace or OpenAPI present | + OpenAPI / api-catalog / MCP / OAuth |

The auditor runs only the applicable subset and prints the exclusion rationale for
every `N/A` layer. A WordPress site with WooCommerce active but products disabled
still counts as `merchant` for detection purposes; the payment-protocol checks stay
advisory either way.

---

## 3. Check catalog — GEO codes

Prefix `GEO-<layer><nn>`; layer letter D/A/U/P. Each code maps to one or more ORA
check ids and is the unit later agents reference and tabulate. Codes carry the full
mapping here; the audit/fixable subset is what the fixer can actually change.

Wildcard groups in the design spec §6 are expanded below to the concrete ids in the
live catalog. `yes` = the theme/host can fix it. `advisory` = detected and reported,
not fixed (off-site, network- or third-party-dependent). `*` = only when the site
type implies it.

### Discovery — GEO-D

| Code | ORA check ids | Fixable |
|---|---|---|
| GEO-D01 | `ard-catalog`, `ai-catalog-published`, `ard-entries-valid` | yes — `/.well-known/ard.json` + `ai-catalog.json` alias |
| GEO-D02 | `robots-ai-policy-quality`, `robots-agent-user-policy` | yes — robots policy + `Content-Signal` |
| GEO-D03 | `ard-trust-manifest` | yes — trust manifest in the ARD catalog |
| GEO-D04 | `agent-rules-repo`, `agent-plugins-repo` | yes — `AGENTS.md` |
| GEO-D05 | `brand-search-accuracy` | advisory — measured via ORA / DataForSEO |
| GEO-D06 | `agentic-search-specific`, `agentic-search-usecase` | advisory — share of voice |
| GEO-D07 | `wikipedia-presence` | advisory — off-site |
| GEO-D08 | `registry-branding`, `skills-sh-listed`, `chatgpt-app-listed`, `mcp-registry-listed`, `npm-sdk-package` | advisory — off-site |

### Access — GEO-A

| Code | ORA check ids | Fixable |
|---|---|---|
| GEO-A01 | `content-no-js` | yes — raw-HTML content ≥500 chars, first heading `H1`, sequential, ≥5% ratio |
| GEO-A02 | `bot-detection` | yes — AI UA allowlist in WAF/robots |
| GEO-A03 | `redirect-hygiene` | yes — real 301/302, no meta-refresh or JS redirect |
| GEO-A04 | `agent-friendly-404` | yes — real 404 status + short markdown body |
| GEO-A05 | `docs-auth-gate` | yes — keep public pages ungated |
| GEO-A06 | `metadata-completeness` | yes — canonical + `lang` + `og:image` + `og:type` together |
| GEO-A07 | `json-ld` | yes — identity JSON-LD |
| GEO-A08 | `json-ld-entity-linking` | yes — `sameAs` |
| GEO-A09 | `org-schema-completeness` | yes — `contactPoint` + `address` |
| GEO-A10 | `schema-type-breadth` | yes — FAQPage/Service/Product/AggregateRating/BreadcrumbList |
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
| GEO-A22 * | `openapi-spec`, `public-api`, `developer-portal`, `api-catalog-rfc9727` | SaaS/API only |
| GEO-A23 | `agent-crawler-reachability` | yes |
| GEO-A24 * | `pricing-info`, `pricing-md` | merchant/SaaS |

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

### Payments — GEO-P (merchant only)

| Code | ORA check ids | Fixable |
|---|---|---|
| GEO-P01 | `acp-support`, `acp-delegate-payment` | advisory |
| GEO-P02 | `ucp-support` | advisory |
| GEO-P03 | `mpp-support`, `mcp-*` payment surfaces | advisory |
| GEO-P04 | `x402-support` | advisory |
| GEO-P05 | `ap2-support` | advisory |

Payment protocols are largely advisory for WooCommerce today (see §8 Ceilings). The
fixer reports the recommendation and does not fabricate protocol support.

---

## 4. AI crawler allowlist

`robots.txt` must name each AI crawler explicitly — a bare `User-agent: *` does not
satisfy `robots-agent-user-policy`. The default posture is **ALLOW** for the retrieval
and training agents below; confirm the commercial intent with the site owner before
changing it.

| Crawler | Operator | Policy |
|---|---|---|
| `GPTBot` | OpenAI (training + crawl) | ALLOW |
| `OAI-SearchBot` | OpenAI Search | ALLOW |
| `ChatGPT-User` | OpenAI live browsing | ALLOW |
| `ClaudeBot` | Anthropic (training + crawl) | ALLOW |
| `PerplexityBot` | Perplexity | ALLOW |
| `Google-Extended` | Google Gemini training | ALLOW |
| `GoogleOther` | Google research crawl | ALLOW |
| `Applebot-Extended` | Apple Intelligence | ALLOW |
| `Amazonbot` | Amazon | ALLOW |
| `FacebookBot` | Meta AI | ALLOW |
| `CCBot` | Common Crawl | context — allow if the public corpus is wanted, otherwise block |
| `anthropic-ai` | Anthropic legacy UA | context — alias of ClaudeBot; keep consistent |
| `Bytespider` | ByteDance / TikTok | BLOCK for Western markets |

Minimum robots body:

```
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

User-agent: Applebot-Extended
Allow: /

User-agent: Amazonbot
Allow: /

User-agent: FacebookBot
Allow: /

User-agent: Bytespider
Disallow: /
```

Add the policy signal as a response header (and, where the host supports it, a
per-`User-agent` block):

```
Content-Signal: ai-train=no, search=yes, ai-retrieval=yes
```

`Content-Signal` lets a site refuse training while still answering search and live
agent retrieval — which is the posture an SEO-driven WordPress site almost always
wants. Keep it consistent with the robots allowlist; contradictory signals fail both
`robots-ai-policy-quality` and `robots-agent-user-policy`.

---

## 5. GEO citability rubric

Citability is a property of the **copy**, not the markup. It scores how likely a
generative engine is to lift a passage verbatim. Weights:

| Component | Weight | What it means |
|---|---|---|
| Answer-block quality | 30% | A direct 1–2 sentence answer opens the section ("X is…") |
| Self-containment | 25% | The passage reads correctly with no surrounding context |
| Structural readability | 20% | Question-based H2s, short paragraphs, tables for 3+ comparisons |
| Statistical density | 15% | Named numbers, units, dates sourced to first-party data |
| Uniqueness | 10% | Original data or framing, not a restatement of the consensus |

Concrete rules:

- **Optimal extractable passage length: 134-167 words.** Below that the engine has too
  little to quote; above it gets truncated mid-argument.
- Open every section with a 1–2 sentence answer before any elaboration. Do not bury the
  answer under a definition parade.
- Phrase H2s as questions where the content answers one (`What does X cost?`).
- Use a table whenever three or more things are compared; prose comparisons are not
  extractable as a unit.
- Name sources and dates inline (`per the 2025 WordPress project survey…`).
- Prefer first-party data — measured numbers we own — over adjectives.
- One idea per passage; a section that answers two questions gets split.

The rubric is for **generation** as well as audit: `/wp-section` and `/wp-seed` authors
apply it when writing copy, and the auditor scores each page's extractable blocks
against it.

---

## 6. Surface templates

The fixer writes the theme's `inc/agentic.php`, which owns every surface below. All are
applicability-gated; a content site does not emit API or payment surfaces.

### 6.1 Dynamic `llms.txt`

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

### 6.2 `/.well-known/ard.json` (Agentic Resource Discovery)

ARD v0.91 canonical path; keep `/.well-known/ai-catalog.json` as the equivalent
predecessor alias. Each entry names a resource with a `urn:air` identifier, a media
type, and exactly one of `url` or `data`:

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

### 6.3 `/.well-known/agent-skills/index.json` v0.2.0

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

### 6.4 `pricing.md`

For merchant/SaaS sites, publish `/pricing.md` (and keep `/pricing` as the HTML page):
a plain-markdown table of plans, prices, currency and billing period, plus a one-line
answer per tier. `pricing-info` also accepts the HTML page; `pricing-md` wants the
markdown sibling.

### 6.5 Markdown negotiation

When the request's `Accept` header includes `text/markdown`, serve a markdown rendering
of the page (or a link to one) and always send:

```
Vary: Accept
Content-Type: text/markdown; charset=UTF-8
```

Balanced code fences (`code-fence-validity`) and optional YAML frontmatter
(`markdown-frontmatter`) are required for a clean markdown response.

### 6.6 RFC 8288 `Link:` headers

Emit discovery relations on HTML responses, e.g.:

```
Link: <https://example.com/llms.txt>; rel="alternate"; type="text/plain",
      <https://example.com/sitemap_index.xml>; rel="sitemap",
      <https://example.com/.well-known/api-catalog>; rel="api-catalog"
```

### 6.7 Agent-friendly 404

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
body alone.

### 6.8 JSON-LD identity and breadth

Emit one identity graph (Organization / LocalBusiness) with `contactPoint`, `address`
and a populated `sameAs` array (entity linking). Add breadth types Rank Math does not
already emit — `FAQPage`, `Service`, `Product`, `AggregateRating`, `BreadcrumbList` —
**guarded against duplicate schema sources**: if Rank Math already emits a type, the
theme must not emit it a second time (§16 of the SEO standards skill).

### 6.9 Trust anchors

Ensure `/about`, `/contact`, `/privacy` exist as real published pages with ≥500
characters each, seeded from the demo header/footer copy. They satisfy both
`trust-anchors` and give the entity graph something to link to.

---

## 7. Verification loop

The live verifier is `bin/geo-scan.sh <domain>`: it runs
`npx --yes is-agentic <domain> --json`, falls back to `npx ax`, parses the JSON, maps
failed ORA check ids back to GEO codes, and re-scans after the fixer runs.

- A fix is reported resolved **only when the ORA check flips**, not when the theme
  file changed.
- No network or no public URL: the scan prints the reason and **skips cleanly**; a run
  is marked accordingly rather than silently passing.
- The evaluator reads a point-in-time scan; a green scan is evidence, not a guarantee.

---

## 8. Ceilings (documented, not bugs)

- **Off-site checks are advisory.** Wikipedia/Wikidata, registries, ChatGPT app
  listings, npm SDK packages and brand share-of-voice are detected and recommended,
  never fixed from a WordPress theme.
- **Payments / AP2 / ACP / UCP / x402 are merchant-only and largely advisory** for
  WooCommerce today.
- **`markdown-negotiation` on edge-cached hosts is CDN-dependent.** The theme route
  covers standard PHP hosting; an aggressive CDN cache can serve HTML regardless of the
  `Accept` header and must be configured separately.
- **The live scan depends on a publicly reachable URL and the ORA/is-agentic service.**
  It skips cleanly when unavailable and the run is marked.
- **The catalog is a moving target.** Counts and weights come from
  `GET https://ora.ai/api/checks`; re-fetch it before quoting numbers as current.
