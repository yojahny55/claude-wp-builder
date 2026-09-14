#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")/../.."
grep -q '"wp-design-library"' .mcp.json || { echo "FAIL: mcp registration"; exit 1; }
grep -q 'References: library unavailable' commands/wp-demo.md || { echo "FAIL: degrade line"; exit 1; }
grep -q 'search` per role' commands/wp-demo.md || { echo "FAIL: per-role query"; exit 1; }
grep -q '## References' commands/wp-demo.md || { echo "FAIL: brief section"; exit 1; }
grep -q 'Design library' README.md || { echo "FAIL: README"; exit 1; }
if [ -n "${WP_DESIGN_LIBRARY_URL:-}" ]; then
  curl -sf "$WP_DESIGN_LIBRARY_URL/healthz" | grep -q '"ok":true' || { echo "FAIL: live healthz"; exit 1; }
  body='{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
  curl -s -X POST "$WP_DESIGN_LIBRARY_URL/mcp" -H "authorization: Bearer ${WP_DESIGN_LIBRARY_TOKEN:?}" \
    -H 'content-type: application/json' -H 'accept: application/json, text/event-stream' -d "$body" \
    | grep -q '"name":"search"' || { echo "FAIL: live tools/list"; exit 1; }
  echo "live: ok"
else
  echo "live: SKIP (WP_DESIGN_LIBRARY_URL unset)"
fi
echo PASS
