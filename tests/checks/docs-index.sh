#!/usr/bin/env bash
# Every docs/*.md must be linked from docs/README.md, so no document is orphaned
# (two of them were linked from nowhere before the index existed).
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $1"; exit 1; }
[ -f docs/README.md ] || fail "docs/README.md is missing"
n=0
for f in docs/*.md; do
  b=$(basename "$f")
  [ "$b" = README.md ] && continue
  grep >/dev/null -cF "]($b)" docs/README.md || fail "docs/README.md does not link $b"
  n=$((n + 1))
done
[ "$n" -gt 0 ] || fail "no docs found"
# the reverse: every link in the index resolves
while read -r l; do
  [ -f "docs/$l" ] || fail "docs/README.md links $l, which does not exist"
done < <(grep -oE '\]\([a-z0-9.-]+\.md\)' docs/README.md | sed -E 's/^\]\((.*)\)$/\1/')
echo PASS
