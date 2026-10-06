---
name: wp-research
description: Method for researching a client's business and its comparable local competitors from the open web — confirming the client's identity by two independent signals, choosing 3-5 competitors, reading their sites for hero, proof, CTA and positioning, writing a differentiation line, and picking a source rung (WebSearch and WebFetch, Firecrawl, or DataForSEO) under a fixed fetch cap. Its output is demo/RESEARCH.md and the research key in .wp-create.json. Use when the wp-research agent runs, or when asked to research a client's business or competitors before a /wp-demo or /wp-yolo build. Not for extracting design tokens from a site (wp-demo-craft), keyword or backlink data (seo-dataforseo), or auditing a built site's SEO.
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

## The procedure

The order matters: the identity decides whether `research.site` is recorded at all, and the
competitor rows are the only evidence the differentiation line may rest on.

1. **Identify the business** — confirmed by two independent signals, or recorded unconfirmed.
2. **Choose 3–5 comparable competitors**, and say what was rejected.
3. **Read each site** for the four columns, within the fetch cap.
4. **Write the differentiation line**, or record that none was found.
5. **Write `demo/RESEARCH.md` and the `research` key** in the shapes `agents/wp-research.md`
   defines, stating the rung used.

## 1. Identifying the business

Start from what the project already carries: the project name and slug, the
industry and description recorded in `.claude/CLAUDE.md`, and anything under
`docs/` — an address, a phone number, an existing URL. Search by name plus
location plus industry; never guess a URL from the business name, and never
treat a plausible-looking site as the client's own without checking it
against a second signal.

**A business is confirmed by corroboration across two independent
signals** — for example a name-and-address match on a listing plus the
same phone number on the site, or a name match on the client's own site
plus that same address on a map listing. One signal is a candidate, not a
confirmation. When only one signal is found, record the identification as
unconfirmed and say what a second signal would have looked like.

Try two query shapes — name plus location, then name plus industry plus location. If neither
yields a second signal, stop searching and record the identity as unconfirmed.

## 2. Choosing comparable competitors

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

## 3. Reading a site for design signal

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

A filled row, for an invented practice (never copy a real client into an example):

| Competitor | URL | Hero move | Proof device | CTA | Positioning signal |
|---|---|---|---|---|---|
| Harbour Street Physio | `https://competitor-a.example/` | stock photo of a patient stretching, under "Move without pain" | five review stars, no count, no names | "Book online", top right and in the hero | prices hidden; "premium care" in the hero and footer |

**The fetch cap:** at most 5 pages of the client's own site (home, services, about, pricing,
contact — whichever exist), at most 5 competitors, at most 2 pages each. A run that wants more
records what it skipped and why.

## 4. Writing the differentiation line

The shape is "everyone here does X; this client does Y", where X is
observed on at least three of the competitor rows and Y is something the
client's own material supports. A line whose X is not on three rows is a
guess; a line whose Y is not in the client's material is a slogan. When
neither holds, write that no differentiation line was found — that is a
finding, not a failure.

For the row above, with two more practices showing the same hero and hidden prices: "Everyone
here leads with a stock photo and hides its prices; this client publishes a fixed price for a
first assessment (`https://client.example/services/`)."

## The source ladder

**Use the highest rung whose server is connected**: DataForSEO, then Firecrawl, then the
baseline. A call that errors or runs out of quota drops that step to the rung below for the rest
of the run, and the run says so in one line.

| Rung | Discovery | Page reading | Competitors |
|---|---|---|---|
| baseline | `WebSearch` | `WebFetch` | SERP + sector search |
| + Firecrawl | `WebSearch` | Firecrawl (below) | as baseline |
| + DataForSEO | `serp_organic_live_advanced` | `on_page_content_parsing` | `business_data_business_listings_search` by category **and** location |

- `WebSearch` stays the discovery tool at the Firecrawl rung — Firecrawl only changes how a
  page, once found, gets read. The baseline needs no configuration, no key and no account.
- Firecrawl has two access paths and one fallback: **Firecrawl MCP if connected**; otherwise
  the `firecrawl_url` HTTP endpoint from `.wp-create.json`, set by hand when it exists (a
  self-hosted instance); otherwise **fall back to `WebFetch` and say so in one line**. The HTTP
  request is `POST <firecrawl_url>/v1/scrape` with the JSON body
  `{"url": "<page>", "formats": ["markdown"]}` and no authorization header; the page text is
  `data.markdown` in the response. A non-2xx answer, `"success": false` or an empty
  `data.markdown` reads that page with `WebFetch` instead.
- DataForSEO is a paid API, used only when its MCP server is connected: at most 5 SERP or
  listing calls per run, with page reads inside the fetch cap.
- **No key is ever requested**, stored, written into `.wp-create.json` or
  echoed into a log. The agent only discovers whether a server is
  connected.
- The run states which rung it used, in `RESEARCH.md` and in its one-line
  summary, recorded as `research.tier` with exactly these three values: `websearch`,
  `firecrawl`, `dataforseo`.

## What honest output looks like

Every factual line carries its source URL; an unreadable page is recorded
`unreadable`, never inferred; a short competitor list is left short rather
than padded. What to write when a step fails — every rung down, an unconfirmed identity,
fewer than three competitors, an empty page — is the "When it goes wrong" table in
`agents/wp-research.md`.
