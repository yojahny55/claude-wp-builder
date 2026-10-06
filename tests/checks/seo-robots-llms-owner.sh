#!/usr/bin/env bash
# robots.txt and llms.txt had two writers that disagreed. wp-audit-seo-standards shipped a
# robots template naming six of the ten AI crawlers GEO-D02 requires, and an llms.txt
# generator that wrote a physical file at ABSPATH; wp-audit-rankmath inlined both. /wp-audit
# dispatches the SEO fixes before the GEO fixes, so on every run that fixed both, a stale
# physical llms.txt sat in front of the dynamic route inc/agentic.php had just added -- GEO-A26,
# an ERROR, produced by the audit's own fixer -- and whichever agent wrote robots.txt last
# decided whether GEO-D02 passed.
#
# One writer now: wp-agentic-surfaces writes robots.txt (Step 4) and serves llms.txt from a
# route. The SEO skill keeps the classic robots block, identical to the one that writer uses.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

skill=skills/wp-audit-seo-standards/SKILL.md
ref=skills/wp-audit-seo-standards/references/llms-and-robots.md
rm_agent=agents/wp-audit-rankmath.md
fixer=agents/wp-agentic-surfaces.md
for f in "$skill" "$ref" "$rm_agent" "$fixer"; do [ -r "$f" ] || fail "$f is missing or unreadable"; done

# No physical llms.txt or robots.txt is written from the SEO side.
for f in "$skill" "$ref" "$rm_agent"; do
  grep -Eq "file_put_contents\([[:space:]]*ABSPATH[[:space:]]*\.[[:space:]]*'llms\.txt'" "$f" && fail "$f writes a physical llms.txt, which shadows the GEO route (GEO-A26)"
  grep -Eq "file_put_contents\([[:space:]]*ABSPATH[[:space:]]*\.[[:space:]]*'robots\.txt'" "$f" && fail "$f writes robots.txt, which wp-agentic-surfaces Step 4 owns"
done
grep -Fq 'Never write a physical `llms.txt`' "$ref" || fail "$ref does not forbid a physical llms.txt"
grep -Fq "Never write a physical \`ABSPATH . 'llms.txt'\`" "$rm_agent" \
  || fail "$rm_agent does not forbid a physical llms.txt"
grep -Fq 'has one writer: `wp-agentic-surfaces` Step 4' "$rm_agent" \
  || fail "$rm_agent does not hand robots.txt to wp-agentic-surfaces Step 4"
grep -Fq 'The file has **one writer**: `wp-agentic-surfaces` Step 4' "$ref" \
  || fail "$ref does not name the one writer of robots.txt"
grep -Fq "file_put_contents( ABSPATH . 'robots.txt'" "$fixer" \
  || fail "$fixer Step 4 no longer writes robots.txt -- then this check names the wrong owner"

# The AI-crawler policy is the GEO skill's; the SEO reference names no AI crawler of its own.
for bot in GPTBot ClaudeBot Google-Extended PerplexityBot CCBot Bytespider; do
  grep -qx "User-agent: $bot" "$ref" && fail "$ref still carries its own AI-crawler block ($bot) -- the allowlist is wp-audit-geo-standards §4"
done
grep -Fq 'The defaults above allow all major AI crawlers' "$skill" \
  && fail "$skill still points at an AI-crawler template that is not there"

# The classic block is the one the writer writes, line for line.
seo_block=$(grep -E '^(User-agent: \*|Allow: |Disallow: )' "$ref")
fixer_block=$(awk '/^## Step 4: Write the robots AI policy/{on=1} on && /\$bots = array/{exit} on' "$fixer" \
  | grep -oE "'(User-agent: \\*|Allow: [^']*|Disallow: [^']*)'" | tr -d "'")
[ -n "$seo_block" ] || fail "$ref has no classic robots block"
[ -n "$fixer_block" ] || fail "could not read the classic block from $fixer Step 4"
[ "$seo_block" = "$fixer_block" ] || fail "the classic robots block differs between $ref and $fixer Step 4:
--- $ref
$seo_block
--- $fixer
$fixer_block"

# The verification checks what is served, not whether a file exists.
grep -Fq "'llms.txt exists' : 'llms.txt missing'" "$skill" \
  && fail "$skill verification still wants a physical llms.txt to exist"
grep -Fq "(file_exists(ABSPATH . 'llms.txt') ? 'EXISTS' : 'MISSING')" "$rm_agent" \
  && fail "$rm_agent verification still wants a physical llms.txt to exist"

echo "PASS: robots.txt and llms.txt have one writer, and the SEO side never shadows the GEO route"
