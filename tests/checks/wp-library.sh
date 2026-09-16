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
# Inspo: page-level direction only, opt-in, and fenced. Each grep names the contract
# line it protects, so a deleted rule fails here rather than silently widening scope.
grep -q '3.7. Reference precedence' commands/wp-demo.md || { echo "FAIL: precedence ladder"; exit 1; }
grep -q 'never enters `DESIGN.md`' commands/wp-demo.md || { echo "FAIL: colour exclusion"; exit 1; }
grep -q '`get_reference_jsx` is never called' commands/wp-demo.md || { echo "FAIL: jsx exclusion"; exit 1; }
grep -q 'ever reaches `/wp-yolo --transcribe`' commands/wp-demo.md || { echo "FAIL: transcribe exclusion"; exit 1; }
grep -q 'carries no motion data' commands/wp-demo.md || { echo "FAIL: motion exclusion"; exit 1; }
grep -q 'contract wins' commands/wp-demo.md || { echo "FAIL: external guidance is not subordinated"; exit 1; }
grep -q 'A lower tier never overrides a higher one' commands/wp-demo.md || { echo "FAIL: ladder has no binding rule"; exit 1; }
grep -q 'owns page-level direction only' commands/wp-demo.md || { echo "FAIL: inspo scope fence"; exit 1; }
grep -q 'Skip this step in craft mode' commands/wp-demo.md || { echo "FAIL: plain-mode step does not skip in craft"; exit 1; }
grep -q '^## Step 2.7: Page References (plain mode only)' commands/wp-demo.md || { echo "FAIL: plain-mode reference step"; exit 1; }
# Each mode must keep both rules. Extra mentions are harmless, but a summary or
# two copies in one mode must not hide a missing rule in the other mode.
step_has_text() {
  awk -v heading="## Step $1:" -v needle="$2" '
    /^## Step / { active = index($0, heading) == 1; next }
    active && index($0, needle) { found = 1 }
    END { exit !found }
  ' commands/wp-demo.md
}
for step in 2.6 2.7; do
  step_has_text "$step" 'References: inspo unavailable' \
    || { echo "FAIL: Step $step missing inspo degrade line"; exit 1; }
  step_has_text "$step" 'a fourth search costs more than it finds' \
    || { echo "FAIL: Step $step missing inspo call budget"; exit 1; }
done
# Match the literal npx argument, including quotes, so ranges and longer versions fail.
grep -Fq '"inspo-mcp@0.1.16"' README.md || { echo "FAIL: README does not pin inspo to the measured 0.1.16 release"; exit 1; }
grep -q 'not\*\* registered by default' README.md || { echo "FAIL: README does not state inspo is opt-in"; exit 1; }
! grep -q '"inspo"' .mcp.json || { echo "FAIL: inspo must stay out of the shipped .mcp.json"; exit 1; }
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
