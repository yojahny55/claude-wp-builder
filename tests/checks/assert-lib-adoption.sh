#!/usr/bin/env bash
# A check that defines its own fail() is one more copy of a helper that lives in
# tests/lib/assert.sh. 220-odd checks already do; migrating them all at once would be a
# diff nobody can review, so the existing ones are frozen in tests/checks/lib/fail-allowlist.txt
# and shrink as they are touched. A NEW check must source the library instead.
# Also pins that every check is executable in git (mode 100755): CI runs `bash "$f"`, so a
# missing bit goes unnoticed there and breaks `./check.sh` locally.
set -euo pipefail
. "$(dirname "$0")/../lib/assert.sh"
cd "$(dirname "$0")/../.." || exit 1

allow=tests/checks/lib/fail-allowlist.txt
[ -f "$allow" ] || fail "$allow is missing"

for f in tests/checks/*.sh; do
  b=$(basename "$f")
  if grep >/dev/null -qE '^[[:space:]]*(function +)?fail *\(\)' "$f" 2>/dev/null; then
    [ "$(grep -Fxc -- "$b" "$allow")" -gt 0 ] \
      || fail "$b defines its own fail(): source tests/lib/assert.sh instead (the allowlist is frozen)"
  elif [ "$(grep -Fxc -- "$b" "$allow")" -gt 0 ]; then
    fail "$b is on $allow but no longer defines fail(): remove it from the list"
  fi
done

# Executable bit, as git records it.
if git rev-parse --git-dir >/dev/null 2>&1; then
  bad=$(git ls-files -s -- 'tests/checks/*.sh' | grep -Ev $'^100755 |\ttests/checks/lib/' || true)
  [ -z "$bad" ] || fail "checks without the executable bit (git update-index --chmod=+x): $(printf '%s\n' "$bad" | cut -f2 | tr '\n' ' ')"
fi
for f in tests/checks/*.sh; do
  [ -x "$f" ] || fail "$f is not executable"
done
echo PASS
