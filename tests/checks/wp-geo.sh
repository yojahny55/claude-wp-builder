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

# Wiring: --geo flag, dispatch names, and the live verifier in the finish phase.
grep -q -- '--geo' "$audit" || fail "$audit missing --geo"
grep -q 'wp-audit-geo' "$audit" || fail "$audit must dispatch wp-audit-geo"
grep -q 'wp-agentic-surfaces' "$audit" || fail "$audit must dispatch wp-agentic-surfaces"
grep -q -- '--geo' "$yolo" || fail "$yolo missing --geo"
grep -q 'geo-scan.sh' "$yolo" || fail "$yolo must run the live scan"
grep -q 'GEO & agent-readiness' "$finalize" || fail "$finalize missing the GEO readiness check"

echo PASS
