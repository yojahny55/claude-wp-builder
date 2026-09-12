---
name: wp-research
description: How to research a client's business and its competitors from the open web — identification, comparable-competitor selection, reading a site for design signal, and the source ladder. Read by the wp-research agent, dispatched from /wp-demo Step 2.4 and /wp-yolo.
user-invocable: false
---

# Client Research

## What this is for

The build invents the client when nothing tells it otherwise; `demo/BRIEF.md`
marks that honestly, and the content is still made up. Research replaces
invention with attribution wherever it can — a hero claim sourced to the
client's own page, a competitor pattern sourced to three sites that all do
it — and says so plainly wherever it cannot: an unconfirmed identity, a
market with no findable comparables, a differentiation line with no
support are all recorded as findings, not papered over with a guess.

## Identifying the business

Start from what the project already carries: the project name and slug, the
industry and description recorded in `.claude/CLAUDE.md`, and anything under
`docs/` — an address, a phone number, an existing URL. Search by name plus
location plus industry; never guess a URL from the business name, and never
treat a plausible-looking domain as the client's own without checking it
against a second signal.

**A business is confirmed by corroboration across two independent
signals** — for example a name-and-address match on a listing plus the
same phone number on the site, or a name match on the client's own domain
plus that same address on a map listing. One signal is a candidate, not a
confirmation. When only one signal is found, record the identification as
unconfirmed and say what a second signal would have looked like.

## Choosing comparable competitors

Comparable means same service, same buyer, reachable from the same
location — not merely the same industry. A national chain is not a
comparable competitor for a two-person local studio, and a franchise's
corporate site tells you nothing about the local market a client actually
competes in. Prefer businesses that surface in the same local search
results the client itself would appear in.

Pick 3–5 of them. Say what was rejected and why — a chain excluded for
scale, a franchise excluded because its site is corporate rather than
local, an industry peer excluded because it serves a different buyer — so
the shortlist reads as a judgment, not an arbitrary cut.

## Reading a site for design signal

For each competitor, extract the columns of the `## Competitors` table:

- **Hero move** — what the first screen does: stock photo, type-led,
  product shot, video.
- **Proof device** — logos, numbers, testimonials, case studies, or
  nothing.
- **CTA** — what it asks for and where it sits.
- **Positioning signal** — price shown or hidden, "premium" or
  "affordable" vocabulary, credentials.

Read markup and stylesheets, not a screenshot — a rendered screenshot loses
the vocabulary and the markup structure that the columns above depend on.

## Writing the differentiation line

The shape is "everyone here does X; this client does Y", where X is
observed on at least three of the competitor rows and Y is something the
client's own material supports. A line whose X is not on three rows is a
guess; a line whose Y is not in the client's material is a slogan. When
neither holds, write that no differentiation line was found — that is a
finding, not a failure.

## The source ladder

| Tier | Tools | Unlocks |
|---|---|---|
| baseline | `WebSearch`, `WebFetch` | identification, competitor discovery, reading any page directly |
| + Firecrawl | `firecrawl_url` (or the Firecrawl MCP server) | cleaner extraction from JS-heavy or blocked pages |
| + DataForSEO | `serp_organic_live_advanced`, `on_page_content_parsing`, `business_data_business_listings_search` | ranked SERP discovery, structured on-page parsing, category-and-location business listings |

- The baseline always works: `WebSearch` and `WebFetch` need no
  configuration, no key and no account.
- Firecrawl has two access paths and one fallback: **Firecrawl MCP if
  connected**; otherwise the `firecrawl_url` HTTP endpoint from
  `.wp-create.json`; otherwise fall back to `WebFetch` and say so in one
  line.
- DataForSEO is used only when its MCP server is connected:
  `serp_organic_live_advanced` for discovery, `on_page_content_parsing`
  for reading, `business_data_business_listings_search` filtered by
  category **and** location for competitors.
- **No key is ever requested**, stored, written into `.wp-create.json` or
  echoed into a log. The agent only discovers whether a server is
  connected.
- The run states which tier it used, in `RESEARCH.md` and in its one-line
  summary, using exactly these three values: `websearch`, `firecrawl`,
  `dataforseo`. They are what `.wp-create.json` records as
  `research.tier`.

## The fetch cap

The cap is verbatim: at most 5 pages of the client's own site (home,
services, about, pricing, contact — whichever exist), at most 5
competitors, at most 2 pages each. A run that wants more records what it
skipped and why.

## What honest output looks like

Every factual line carries its source URL; an unreadable page is recorded
`unreadable`, never inferred; a short competitor list is left short rather
than padded, because a padded list is worse than a short one.
