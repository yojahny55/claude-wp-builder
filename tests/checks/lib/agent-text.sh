#!/usr/bin/env bash
# Prints the path of one file holding an audit agent's prose AND the references it reads on
# demand, so a check that greps "the agent" still sees text that moved out to
# skills/wp-audit-standards/references/ (agents/wp-audit-performance.md ->
# perf-*.md plus the older performance-lessons.md, agents/wp-audit-security.md -> sec-*.md).
# The agent file comes first. The content is deterministic, so concurrent callers write the same
# bytes, and the final file is deliberately left in place as a cache across calls; only the
# per-process temp file is removed. Keep the output free of timestamps or anything per-run.
#   perf=$(bash "$(dirname "$0")/lib/agent-text.sh" wp-audit-performance)
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
name="${1:?agent name}"
case "$name" in
  wp-audit-performance) pat='perf-*.md'; extra='performance-lessons.md' ;;
  wp-audit-security)    pat='sec-*.md'; extra='' ;;
  *) echo "$root/agents/$name.md"; exit 0 ;;
esac
dir="${TMPDIR:-/tmp}/wpb-agent-text"
mkdir -p "$dir"
out="$dir/$name.$$.md"
trap 'rm -f "$out"' EXIT   # no-op after the mv below: the final file is the cache
# Sorted under the C locale so the bytes do not depend on the caller's LC_COLLATE; an empty
# match is an error instead of cat being handed the literal glob.
mapfile -t refs < <(compgen -G "$root/skills/wp-audit-standards/references/$pat" | LC_ALL=C sort)
[ "${#refs[@]}" -gt 0 ] || { echo "agent-text.sh: no references match $pat" >&2; exit 1; }
[ -z "$extra" ] || refs+=("$root/skills/wp-audit-standards/references/$extra")
cat "$root/agents/$name.md" "${refs[@]}" > "$out"
mv -f "$out" "$dir/$name.md"
echo "$dir/$name.md"
