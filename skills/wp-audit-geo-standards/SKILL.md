---
name: wp-audit-geo-standards
description: GEO and AI-agent-readiness reference — the ORA and is-agentic scoring model, the GEO-D, GEO-A, GEO-U and GEO-P check catalog, applicability by site type (content, local, merchant, catalog store, SaaS), the AI crawler allowlist for robots.txt and the Content-Signal header, the dynamic llms.txt, ARD catalog (ard.json), agent-skills index, markdown negotiation and other surfaces inc/agentic.php serves, the bin/geo-scan.sh live verifier, and a citability rubric for writing copy that AI engines quote. Use when running /wp-audit --geo, explaining why is-agentic grades a site, fixing GEO findings with wp-agentic-surfaces, choosing which AI crawlers robots.txt allows, or writing section copy for ChatGPT and Perplexity to cite. Not for Rank Math titles, meta descriptions, sitemap or schema configuration (wp-audit-seo-standards), and not for accessibility fixes, which GEO-U01 to U05 only mirror.
user-invocable: false
---

# GEO & Agent-Readiness Standards

Scored by **ORA**, surfaced at [is-agentic.com](https://is-agentic.com), in four layers.
The live check catalog is `GET https://ora.ai/api/checks`; every count and weight below is a
snapshot of it, so re-fetch it before quoting a number as current.

This skill informs the audit (`${CLAUDE_PLUGIN_ROOT}/agents/wp-audit-geo.md`) and the fix
(`${CLAUDE_PLUGIN_ROOT}/agents/wp-agentic-surfaces.md`), which holds the executable version
of every surface. It never runs commands on its own. Terms used throughout: a **crawler** is
an AI user agent named in `robots.txt`; the **allowlist** is which crawlers `robots.txt`
admits; a **surface** is a URL the theme serves for agents (`/llms.txt`, `/.well-known/…`);
the **check catalog** is ORA's list of checks, and the **ARD catalog** is `ard.json`.

## Reference files

- [references/check-catalog.md](references/check-catalog.md) — every GEO code, the ORA check
  ids it maps to and whether the theme can fix it. Read when mapping an ORA id to a code,
  tabulating a code, or deciding whether a finding is fixable or advisory.
- [references/surface-templates.md](references/surface-templates.md) — what each surface must
  contain: the minimum robots body, `llms.txt`, `ard.json`, the agent-skills index,
  `pricing.md`, markdown negotiation, `Link:` headers, the agent-friendly 404, JSON-LD
  breadth, trust anchors, `llms-full.txt` and `auth.md`. Read when building or checking a
  surface.
- [references/citability.md](references/citability.md) — the citability rubric and a
  weak-to-strong rewrite. Read when writing or tightening page copy (`/wp-section`,
  `/wp-seed`); no audit code scores it.

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

Site type is **detected, not assumed**, from **positive signals** — the project's
`.claude/CLAUDE.md` (`industry`), active plugins, an OpenAPI/public-API signal, the page
inventory and templates. A registered REST namespace is **not** a signal: Rank Math,
Yoast, SEOPress and CF7 all register one, so scanning `rest_get_server()` marks an
ordinary content site as SaaS. Every check not implied by the detected type is reported
`N/A`.

| Site type | Detection | Layers that apply |
|---|---|---|
| content / publisher / service | default when no positive signal matches | Discovery + Access + GUI-Usability |
| **local business** | `industry` = local/business **and** a non-empty `business_address` | + LocalBusiness schema, NAP, reviews |
| **merchant** | `site.commerce` `woocommerce` from `/wp-audit` Step 2.3; standalone, `class_exists('WooCommerce')` / `$WP plugin is-active woocommerce` | + Payments, `pricing.md`, Product schema |
| **SaaS** / public API | an OpenAPI spec or a deliberate public API surface recorded in `.claude/CLAUDE.md` | + OpenAPI / api-catalog / MCP / OAuth |

The auditor runs only the applicable subset and prints the exclusion rationale for
every `N/A` layer. A WordPress site with WooCommerce active but products disabled
still counts as `merchant` for detection purposes; the payment-protocol checks stay
advisory either way, because no WooCommerce payment gateway speaks an agent payment
protocol (§8).

A catalog store is a merchant that deliberately takes no payment. When `/wp-audit` Step 2.3
records `site.store_tier` = `catalog` (read from the `store` block of `.wp-create.json`),
the payment-protocol codes GEO-P01 to GEO-P05 are `N/A ("catalog: nothing purchasable")`:
an agent payment protocol has nothing to pay for. `unknown` is not `catalog` — audit them.
Read the recorded tier; never infer it from whether a checkout page happens to exist.

---

## 3. Check catalog

Codes are `GEO-<layer><nn>`, layer letter D, A, U or P. Each maps to one or more ORA check
ids and is the unit the agents tabulate and report; the full table, with what the theme can
fix, is [references/check-catalog.md](references/check-catalog.md). GEO-A25 to GEO-A28 are
the plugin's own: ORA has no check for them, so they are reported outside the ORA score.

---

## 4. AI crawler allowlist

`robots.txt` must name each AI crawler explicitly — a bare `User-agent: *` does not
satisfy `robots-agent-user-policy`. The default posture is **ALLOW** for the retrieval
and training crawlers below.

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
| `CCBot` | Common Crawl | not named — falls under `User-agent: *`; `Disallow` it only when the owner does not want the site in the public corpus |
| `anthropic-ai` | Anthropic, legacy token | not named — when it is, give it `ClaudeBot`'s policy |
| `Bytespider` | ByteDance / TikTok | BLOCK for Western markets |

The minimum robots body is every ALLOW row, then the BLOCK row, after the classic
`User-agent: *` block — written out in
[references/surface-templates.md](references/surface-templates.md).

**The training posture is the owner's decision, and a deliberate one stands.** An existing
`Disallow` for a named crawler, or an `ai-train=no` signal, is the site owner's answer, not
a defect: the auditor reports it as a deliberate block (consistent or not with the signal,
below), and the fixer asks before changing it — it never rewrites a deliberate block back to
the default. The default applies only where the site states no posture at all.

Send the policy signal as an HTTP response header, and never as a line of `robots.txt`:

```
Content-Signal: ai-train=yes, search=yes, ai-retrieval=yes
```

No robots.txt grammar defines a `Content-Signal` directive, so a validator that lints the
file — Lighthouse among them — reports the whole `robots.txt` invalid over that one line.
The file may document the signal in a `#` comment; the header is what carries it.

`Content-Signal` declares the site's AI usage posture and **must match the robots
allowlist** — a signal that contradicts the rules fails both `robots-ai-policy-quality` and
`robots-agent-user-policy`. The allowlist above permits training-capable crawlers (`GPTBot`,
`ClaudeBot`, `Google-Extended`, `Applebot-Extended`), so the matching signal is
`ai-train=yes`. A site that wants to refuse training must also `Disallow` those crawlers and
set `ai-train=no`; `search=yes, ai-retrieval=yes` keeps it discoverable in AI answers either
way.

---

## 5. Citability

Citability is a property of the **copy**, not the markup: how likely a generative engine is
to lift a passage verbatim. The rubric — five weighted components, an optimal passage of
134-167 words, answer-first openings — and a worked rewrite are in
[references/citability.md](references/citability.md).

## 6. Surfaces

The fixer writes the theme's `inc/agentic.php`, which owns every surface; all are
applicability-gated, so a content site emits no API or payment surface. What each must
contain is [references/surface-templates.md](references/surface-templates.md). One rule
belongs here because both agents act on it: **when Rank Math, Yoast or SEOPress owns the
schema, the theme emits no JSON-LD**, so GEO-A07 to GEO-A10 are fixable only when no SEO
plugin owns the graph — otherwise `wp-audit-rankmath` fills it.

---

## 7. Verification loop

The live verifier is `${CLAUDE_PLUGIN_ROOT}/bin/geo-scan.sh <domain|url> [--start]` — run
it, do not read or reimplement it. It needs `curl`; `timeout` or `gtimeout` bound it when
present. It issues a read-only `GET` to the public is-agentic report API
(`https://is-agentic.com/api/v1/report?url=…`) and **only prints the JSON report**. It never
runs npm packages — `/wp-yolo` calls it unattended, so downloading and executing a package
would be a supply-chain risk. When no completed report exists yet, `--start` asks
is-agentic to scan the host through the same HTTP endpoint the npm CLI uses and reads the
report when the scan finishes, all within 110 s. Pass `--start` only for a host the
operator confirmed as public this run: a scan makes is-agentic fetch the site. The script
does not parse the JSON.

| Exit | Meaning | What the caller does |
|---|---|---|
| `0` | a non-empty report came back | map its failed ids to GEO codes |
| `1` | the request failed, or the arguments were wrong | record the error; the GEO codes it would have measured are `UNMEASURED` |
| `2` | skipped cleanly: no `curl`, no network, no completed report, a scan that did not finish, a transient `429`/`503` | record the skip and mark the run incomplete — never a pass |
| `3` | the host is not publicly reachable: `localhost`, `.local`, `.test`, `*.local.com`, a private address, a name with no dot | pass the public URL (`/wp-audit --host`); a dev host is a configuration problem, not a missing report |

The loop:

1. **Scan** the public host and note the report's scan time.
2. **Map** each failed ORA check id to its GEO code with
   [references/check-catalog.md](references/check-catalog.md).
3. **Fix** what the theme can fix (`wp-agentic-surfaces`); leave advisory codes as
   recommendations.
4. **Re-scan once**, after the fix is deployed to the host the scan reads.
5. **Compare.** A fix is resolved **only when its ORA check flips** in a report scanned
   after the fix — never because the theme file changed. A report whose scan time precedes
   the fix is the old report: `geo-scan.sh` only starts a scan when none exists, so it
   returns the pre-fix report until is-agentic re-scans the site. Ask the operator to
   re-scan at https://is-agentic.com; until then the code is `UNMEASURED`, not resolved.
   Stop after that one re-scan.

The evaluator reads a point-in-time scan; a green scan is evidence, not a guarantee.

---

## 8. Ceilings (documented, not bugs)

- **Off-site checks are advisory.** Wikipedia/Wikidata, registries, ChatGPT app
  listings, npm SDK packages and brand share-of-voice are detected and recommended,
  never fixed from a WordPress theme.
- **Payments / AP2 / ACP / UCP / x402 are merchant-only and advisory** for WooCommerce:
  no WooCommerce gateway implements an agent payment protocol, so the fixer recommends and
  never fabricates support.
- **`markdown-negotiation` on edge-cached hosts is CDN-dependent.** The theme route
  covers standard PHP hosting; an aggressive CDN cache can serve HTML regardless of the
  `Accept` header and must be configured separately.
- **The live scan depends on a publicly reachable URL and the ORA/is-agentic service.**
  It skips cleanly when unavailable and the run is marked.
- **The catalog is a moving target.** Counts and weights come from
  `GET https://ora.ai/api/checks`; re-fetch it before quoting numbers as current.
