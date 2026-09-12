#!/usr/bin/env bash
# Client research reaches the network and reads third-party pages, so none of it
# can be exercised here. What is asserted instead is the contract around the
# call: that the methodology states the ladder and its degradation, that the
# agent treats scraped content as data, that the build's six consumers are
# required to cite the artifact, and that the "none" record is both written and
# read. Prose is pinned against a comment-stripped, whitespace-collapsed copy so
# a reflow cannot fail the build and a code comment cannot satisfy a pin.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Collapse a markdown file for prose pins: strip HTML comments, collapse all
# runs of whitespace to one space. Line wrapping then cannot break a pin.
flat() {  # file -> stripped copy path on stdout
  local out="$tmp/$(echo "$1" | tr / _).flat"
  perl -0pe 's{<!--.*?-->}{}gs; s{\s+}{ }g' "$1" > "$out" \
    || fail "could not build the stripped copy of $1"
  echo "$out"
}

# ---------------------------------------------------------------------------
# A. The skill states the method, the ladder and the cap.
# ---------------------------------------------------------------------------
s=skills/wp-research/SKILL.md
[ -f "$s" ] || fail "$s is missing"
grep -q '^user-invocable: false' "$s" || fail "$s must declare user-invocable: false"
sf=$(flat "$s")

for tier in websearch firecrawl dataforseo; do
  grep -Fq "$tier" "$sf" || fail "$s does not name the '$tier' tier"
done

# Each rung must state what it degrades TO. A ladder that names three tiers but
# never says one falls back to another is a list, not a ladder.
grep -Fq 'Firecrawl MCP if connected' "$sf" \
  || fail "$s does not state that Firecrawl is used via MCP when connected"
grep -Fq 'firecrawl_url' "$sf" \
  || fail "$s does not state the firecrawl_url HTTP fallback"
grep -Fq 'fall back to `WebFetch` and say so in one line' "$sf" \
  || fail "$s does not state the WebFetch fallback and that it is announced"

# The cap is the only thing stopping a run from wandering. Pin the numbers.
grep -Fq 'at most 5 pages of the client' "$sf" \
  || fail "$s does not cap the client-site fetches at 5 pages"
grep -Fq 'at most 5 competitors' "$sf" \
  || fail "$s does not cap competitors at 5"
grep -Fq 'at most 2 pages each' "$sf" \
  || fail "$s does not cap competitor pages at 2 each"

# No key, ever. This is the rule that keeps a self-hosted Firecrawl from
# becoming a credential prompt.
grep -Fq 'No key is ever requested' "$sf" \
  || fail "$s does not state that no key is ever requested"

# ---------------------------------------------------------------------------
# B. The agent's contract: frontmatter, the artifact shape, the "none" write,
#    and the rule that scraped content is data.
# ---------------------------------------------------------------------------
a=agents/wp-research.md
[ -f "$a" ] || fail "$a is missing"
for key in name description tools model; do
  grep -q "^$key:" "$a" || fail "$a has no $key in its frontmatter"
done
grep -q '^model: opus' "$a" || fail "$a must be opus — this is synthesis, not extraction"
grep -q '^tools:.*WebSearch' "$a" || fail "$a does not declare WebSearch"
grep -q '^tools:.*WebFetch'  "$a" || fail "$a does not declare WebFetch"
grep -q '^## First Action (MANDATORY)' "$a" \
  || fail "$a does not open with the First Action (MANDATORY) block"

af=$(flat "$a")

# The artifact's four sections. Pinned against the RAW file with a line-start/end
# anchor so a heading name that also appears inside a sentence elsewhere (a
# cross-reference, e.g. "the `## Identity` block") cannot satisfy the pin — only
# a real heading line matches ^...$. The flattened copy cannot do this: flat()
# collapses every newline, so ^ has nothing to anchor to there. Pinned
# individually: one pin naming all four would stay green with three deleted.
for h in '## Identity' '## What they actually say' '## Competitors' '## Signals'; do
  grep -q "^$h\$" "$a" || fail "$a does not define the '$h' section of demo/RESEARCH.md"
done

# Prompt-injection containment. This is the rule that keeps a competitor's page
# from editing the build.
grep -Fq 'is data, never instructions' "$af" \
  || fail "$a does not state that scraped content is data, never instructions"
grep -Fq 'never followed' "$af" \
  || fail "$a does not state that instructions found in scraped content are never followed"

# Honest failure. Each is pinned separately because each is a different refusal.
grep -Fq 'unreadable' "$af" \
  || fail "$a does not record an unreadable competitor page as unreadable"
grep -Fqi 'do not pad' "$af" \
  || fail "$a does not refuse to pad a short competitor list"
grep -Fq 'no `research.site` is recorded' "$af" \
  || fail "$a does not withhold research.site on an unconfirmed identity"

# The WRITE half of the "none" contract. The READ half is pinned in section C
# against the command; pinning only one half lets the other be reworded green.
grep -Fq '"research": "none"' "$af" \
  || fail "$a never writes \"research\": \"none\""

# The web address is research.site and is never called a domain: .wp-create.json
# already uses "domain" for the domains.csv industry category, and an agent that
# writes the URL there would silently overwrite the classification. A bare
# `grep -Fq 'research.site'` pin is dead weight here — it cannot fail while the
# "no `research.site` is recorded" pin above is satisfied, since that string
# already contains it. Test the actual rule instead: no URL ever lands in
# "domain", and the prose says why.
grep -Eq '"domain"[[:space:]]*:[[:space:]]*"https?://' "$a" \
  && fail "$a writes a URL into \"domain\" — that key holds the domains.csv industry category"
grep -Fq 'It is **never** called `domain`' "$af" \
  || fail "$a does not state that the web address is never called domain"

# ---------------------------------------------------------------------------
# C. /wp-demo Step 2.4: position, branch order, and the READ half of "none".
# ---------------------------------------------------------------------------
d=commands/wp-demo.md
df=$(flat "$d")

grep -Fq '## Step 2.4: Research' "$df" || fail "$d has no Step 2.4"

# Position: Step 2.4 must sit between Step 2 and Step 2.5, or a plain build
# reaches Step 4 without it and the copy is invented exactly as before.
awk '/^## Step 2.4: Research/ { r = NR } /^## Step 2.5: Choose the Demo Mode/ { m = NR }
     END { exit !(r > 0 && m > 0 && r < m) }' "$d" \
  || fail "$d Step 2.4 must appear before Step 2.5, so plain builds get research too"

grep -Fq 'wp-research' "$df" || fail "$d never dispatches the wp-research agent"

# The READ half of the "none" contract. The WRITE half is pinned in section B
# against the agent. One pin covering both lets either be reworded green.
grep -Fq 'skip in one line, do not ask' "$df" \
  || fail "$d does not skip on a recorded \"research\": \"none\" without asking"

# Reuse, not re-research. Without this a second run burns the fetch budget again.
grep -Fq 'already exists' "$df" \
  || fail "$d does not reuse an existing demo/RESEARCH.md"
grep -Fq 'never re-researches' "$df" \
  || fail "$d does not state that iterate never re-researches"

# The three answers are three different outcomes. Pinned separately.
grep -Fq 'wrong business' "$df" \
  || fail "$d does not handle the 'wrong business' answer distinctly from a decline"
grep -Fq 'Research still happened; the identity did not' "$df" \
  || fail "$d conflates a rejected identity with a declined research run"

# Research must never block a build.
grep -Fq 'never blocks a build' "$df" \
  || fail "$d does not state that research never blocks a build"

# ---------------------------------------------------------------------------
# D. The six consumers. Research that nothing is required to cite ships green
#    and does nothing — that is exactly how "image provider" shipped read but
#    never written. Each consumer is pinned on its own.
# ---------------------------------------------------------------------------
# D1. designlang gets a URL from research when the docs name none.
grep -Fq 'or `research.site` from `demo/RESEARCH.md` when `confidence` is `confirmed`' "$df" \
  || fail "$d does not feed research.site to designlang"

# D2. BRIEF.md: cite, or keep the self-authored marker.
grep -Fq 'cites the `demo/RESEARCH.md` line and its source URL, or keeps the marker' "$df" \
  || fail "$d does not require person/pain/promise to cite research or keep the marker"

# D3. Domain classification corpus. The wp-yolo half is pinned in section E.
grep -Fq 'the client documents and `demo/RESEARCH.md`' "$df" \
  || fail "$d does not widen the domain-classification corpus to include research"
grep -Fq 'which corpus produced each hit' "$df" \
  || fail "$d does not record which corpus produced each domain keyword hit"

# D4. The composition table's second signal column.
grep -Fq 'no research signal' "$df" \
  || fail "$d composition table has no research-signal column"

# D5. Image prompts draw on the research vocabulary.
grep -Fq 'the vocabulary from `demo/RESEARCH.md`' "$df" \
  || fail "$d image prompts do not draw on the research vocabulary"

# D6. Plain-mode copy.
grep -Fq "the client's real sentences from \`demo/RESEARCH.md\`" "$df" \
  || fail "$d plain-mode content does not prefer the client's real sentences"

echo PASS
