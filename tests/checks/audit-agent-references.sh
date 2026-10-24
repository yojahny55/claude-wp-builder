#!/usr/bin/env bash
# wp-audit-performance (84 KB) and wp-audit-security (79 KB) were loaded whole on every
# dispatch, so each run paid for procedures it never reached. The long procedures now live in
# skills/wp-audit-standards/references/{perf,sec}-*.md and the agent keeps the check tables and
# an index. This check keeps that split honest: every reference is named in the agent's index and
# in SKILL.md, every code in the agent's tables still has its row, the agent has not grown back,
# and the index reads the references through ${CLAUDE_PLUGIN_ROOT}.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
refs=skills/wp-audit-standards/references
skill=skills/wp-audit-standards/SKILL.md
# agent  prefix  code-regex  byte budget
while read -r agent pfx codes budget; do
  f="agents/$agent.md"
  size=$(wc -c < "$f")
  [ "$size" -le "$budget" ] || fail "$f is $size bytes, over its $budget budget; move the new procedure to $refs/$pfx-*.md and index it"
  n=0
  for r in "$refs"/$pfx-*.md; do
    [ -e "$r" ] || continue
    n=$((n + 1))
    b=$(basename "$r")
    grep -Fq "\${CLAUDE_PLUGIN_ROOT}/$refs/$b" "$f" || fail "$f never tells the agent to read $b"
    grep -Fq "$b" "$skill" || fail "$skill does not list $b"
    grep -Eq '^## Contents' "$r" || fail "$r has no Contents list"
  done
  [ "$n" -ge 3 ] || fail "$agent has only $n $pfx-*.md references; the split is gone"
  # Every check code in a reference is also in the agent: the table row is the index, so a
  # procedure cannot hold a check the agent never lists.
  for c in $(grep -ohE "(^|[^A-Za-z0-9])$codes-[0-9]{3}([^0-9]|$)" "$refs"/$pfx-*.md | grep -oE "$codes-[0-9]{3}" | sort -u); do
    grep -Eq "^\| $c(@[0-9]+)? \|" "$f" || grep -Fq "$c" "$f" || fail "$c is in a $pfx reference but not in $f"
  done
done <<'LIST'
wp-audit-performance perf PERF 40000
wp-audit-security sec SEC 32000
LIST
echo PASS
