#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }

skill=skills/wp-audit-geo-standards/SKILL.md
agent=agents/wp-audit-geo.md
fixer=agents/wp-agentic-surfaces.md
audit=commands/wp-audit.md
yolo=commands/wp-yolo.md
finalize=commands/wp-finalize.md

for f in "$skill" "$agent" "$fixer"; do [ -f "$f" ] || fail "$f is missing"; done

# Skill: ORA layers as exact table rows. Bare '20'/'30'/'40'/'10' also match the
# citability weights, so they never proved the layer table; require the row shape.
for row in '| Discovery | 20 |' '| Access | 30 |' '| Usability | 40 |' '| Payments | 10 |'; do
  grep -qF "$row" "$skill" || fail "$skill missing layer row '$row'"
done
for t in required recommended emerging; do
  grep -q "$t" "$skill" || fail "$skill missing '$t'"
done
grep -qF 'share an **80**-point' "$skill" || fail "$skill missing the Essential-pool 80-point line"
grep -q 'ora.ai/api/checks' "$skill" || fail "$skill missing the ORA catalog endpoint"
grep -qE 'GEO-[DAUP]' "$skill" || fail "$skill missing GEO layer codes"

# Skill: AI crawler allowlist.
for bot in GPTBot OAI-SearchBot ChatGPT-User ClaudeBot PerplexityBot Google-Extended Applebot-Extended Amazonbot FacebookBot Bytespider; do
  grep -q "$bot" "$skill" || fail "$skill missing crawler $bot"
done

# Skill: citability rubric + site types + required mechanisms.
for t in '30%' '25%' '20%' '15%' '10%' '134-167' merchant 'local business' SaaS 'Content-Signal' 'text/markdown'; do
  grep -q "$t" "$skill" || fail "$skill missing '$t'"
done

# Auditor: model tier, report path, DOM parsing not regex.
grep -q '^model: sonnet' "$agent" || fail "$agent must be sonnet"
grep -q 'audit-results/geo.json' "$agent" || fail "$agent must write the GEO report"
grep -q 'DOMXPath' "$agent" || fail "$agent must parse the DOM, not regex the markup"

# Fixer: model tier and the theme file it owns.
grep -q '^model: sonnet' "$fixer" || fail "$fixer must be sonnet"
grep -q 'inc/agentic.php' "$fixer" || fail "$fixer must own inc/agentic.php"

# Auditor: local-business probe reads the ACF options-page value, never a raw option key.
grep -qE "get_field\('business_address','option'\)|options_business_address" "$agent" || fail "$agent must probe business_address via ACF options"
grep -q '<prefix>_business_address' "$agent" && fail "$agent must not look up <prefix>_business_address as an option"

# Fixer: the detected site type is baked into the theme constant.
grep -q 'AGENTIC_SITE_TYPE' "$fixer" || fail "$fixer must bake AGENTIC_SITE_TYPE"

# Live scanner: timeout wrapper is portable (GNU timeout / gtimeout / none).
grep -q 'gtimeout' bin/geo-scan.sh || fail "bin/geo-scan.sh must fall back to gtimeout"

# Security: the scanner must not download and execute npm packages unattended.
! grep -q 'npx' bin/geo-scan.sh || fail "bin/geo-scan.sh must not run npx (supply-chain risk)"
grep -q 'is-agentic.com/api/v1/report' bin/geo-scan.sh || fail "bin/geo-scan.sh must call the public report API"

# Fixer: the RFC 8288 Link header belongs on send_headers — wp_headers filters request headers.
grep -q 'send_headers' "$fixer" || fail "$fixer must emit the Link header on send_headers"
grep -qE "add_filter\\( *'wp_headers'" "$fixer" && fail "$fixer must not build the Link header on wp_headers"

# Fixer: Content-Signal must match the training-capable allowlist, not contradict it.
grep -q 'ai-train=yes' "$fixer" || fail "$fixer must declare ai-train=yes to match its allowlist"
grep -qE 'Content-Signal: *ai-train=no' "$fixer" && fail "$fixer must not emit ai-train=no while allowing training crawlers"

# Fixer: trust-anchor seeding calls the copy function; quoting it makes wp eval fatal.
grep -q "'<prefix>_trust_anchor_copy" "$fixer" && fail "$fixer must not quote the trust-anchor copy call"

# Fixer: llms-full is capped; an unbounded dump can exhaust memory on a large site.
grep -q "'posts_per_page' => 200" "$fixer" || fail "$fixer must cap llms-full.txt at 200 posts"
grep -q 'Never answer an empty 200' "$fixer" || fail "$fixer must 404 a missing area llms builder"

# Scanner: a full URL must be reduced to a bare host before building the API query.
grep -qF 'host="${host#*@}"' bin/geo-scan.sh || fail "bin/geo-scan.sh must strip userinfo/query/fragment from the host"

# Finalize: JS/CSS must not inflate the GEO-A01 count, and GEO-A02 parses robots.
grep -qF 's/<(script|style)' "$finalize" || fail "$finalize GEO-A01 must strip script/style before counting"
grep -qF 'BLOCKED ' "$finalize" || fail "$finalize GEO-A02 must detect a site-wide Disallow for a named bot"

# Wiring: --geo flag, dispatch names, and the live verifier in the finish phase.
grep -q -- '--geo' "$audit" || fail "$audit missing --geo"
grep -q 'wp-audit-geo' "$audit" || fail "$audit must dispatch wp-audit-geo"
grep -q 'wp-agentic-surfaces' "$audit" || fail "$audit must dispatch wp-agentic-surfaces"
grep -q -- '--geo' "$yolo" || fail "$yolo missing --geo"
grep -q 'geo-scan.sh' "$yolo" || fail "$yolo must run the live scan"
grep -q 'GEO & agent-readiness' "$finalize" || fail "$finalize missing the GEO readiness check"

echo PASS
