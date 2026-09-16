#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")/../.."
grep -q '"wp-design-library"' .mcp.json || { echo "FAIL: mcp registration"; exit 1; }
grep -q '"@yojahny/wp-design-library@0.2.0"' .mcp.json || { echo "FAIL: pinned mcp package"; exit 1; }
grep -q 'References: library unavailable' commands/wp-demo.md || { echo "FAIL: degrade line"; exit 1; }
grep -q 'every call fails before that happens' commands/wp-demo.md || { echo "FAIL: unavailable line is not limited to zero successful references"; exit 1; }
grep -q 'keep their citations' commands/wp-demo.md || { echo "FAIL: partial library failures discard successful references"; exit 1; }
grep -q 'search` per role' commands/wp-demo.md || { echo "FAIL: per-role query"; exit 1; }
grep -q '## References' commands/wp-demo.md || { echo "FAIL: brief section"; exit 1; }
grep -q 'Design library' README.md || { echo "FAIL: README"; exit 1; }
if [ -n "${WP_DESIGN_LIBRARY_URL:-}" ]; then
  base="${WP_DESIGN_LIBRARY_URL%/}"
  if [[ "$base" == */mcp ]]; then
    mcp_url="$base"
    base="${base%/mcp}"
  else
    mcp_url="$base/mcp"
  fi
  response="$(curl -sf --max-time 10 "$base/healthz")" \
    || { echo "FAIL: live healthz"; exit 1; }
  printf '%s' "$response" | grep -Eq '"ok"[[:space:]]*:[[:space:]]*true' \
    || { echo "FAIL: live healthz"; exit 1; }
  body='{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
  response="$(curl -sf --max-time 10 -X POST "$mcp_url" \
    -H "authorization: Bearer ${WP_DESIGN_LIBRARY_TOKEN:?}" \
    -H 'content-type: application/json' -H 'accept: application/json, text/event-stream' -d "$body")" \
    || { echo "FAIL: live tools/list"; exit 1; }
  printf '%s' "$response" | grep -Eq '"name"[[:space:]]*:[[:space:]]*"search"' \
    || { echo "FAIL: live tools/list search"; exit 1; }
  printf '%s' "$response" | grep -Eq '"name"[[:space:]]*:[[:space:]]*"get_entry"' \
    || { echo "FAIL: live tools/list get_entry"; exit 1; }
  call_body='{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"search","arguments":{"query":"","limit":1}}}'
  response="$(curl -sf --max-time 10 -X POST "$mcp_url" \
    -H "authorization: Bearer ${WP_DESIGN_LIBRARY_TOKEN:?}" \
    -H 'content-type: application/json' -H 'accept: application/json, text/event-stream' -d "$call_body")" \
    || { echo "FAIL: live tools/call search"; exit 1; }
  printf '%s' "$response" | grep -q '"arms"' \
    || { echo "FAIL: live tools/call search"; exit 1; }
  echo "live: ok"
else
  echo "live: SKIP (WP_DESIGN_LIBRARY_URL unset)"
fi
echo PASS
