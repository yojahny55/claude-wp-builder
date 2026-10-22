#!/usr/bin/env bash
# Prints the path of one file holding an audit agent's prose AND the references it reads on
# demand, so a check that greps "the agent" still sees text that moved out to
# skills/wp-audit-standards/references/ (agents/wp-audit-performance.md ->
# perf-*.md, agents/wp-audit-security.md -> sec-*.md). The agent file comes first; the content
# is deterministic, so concurrent callers write the same bytes.
#   perf=$(bash "$(dirname "$0")/lib/agent-text.sh" wp-audit-performance)
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
name="${1:?agent name}"
case "$name" in
  wp-audit-performance) pat='perf-*.md' ;;
  wp-audit-security)    pat='sec-*.md' ;;
  *) echo "$root/agents/$name.md"; exit 0 ;;
esac
dir="${TMPDIR:-/tmp}/wpb-agent-text"
mkdir -p "$dir"
out="$dir/$name.$$.md"
cat "$root/agents/$name.md" "$root"/skills/wp-audit-standards/references/$pat > "$out"
mv -f "$out" "$dir/$name.md"
echo "$dir/$name.md"
