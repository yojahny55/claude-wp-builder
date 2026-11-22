#!/usr/bin/env bash
# tests/mutation.sh is a tool, and a tool that always says "killed" is worse than none. Run
# it on two known checks and assert it detects the mutant, and that it leaves the tree alone.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
before=$(git status --porcelain=v1 -uall | sha256sum; git ls-files -z -co --exclude-standard | xargs -0 sha256sum 2>/dev/null | sha256sum)
out=$(bash tests/mutation.sh -c "audit-catalog-gaps.sh audit-clone-health-preflight.sh" 2>&1) || fail "harness reported a survivor or failed:
$out"
[ "$(grep -c '^killed ' <<<"$out")" -ge 1 ] || fail "harness killed no mutant:
$out"
grep -F 'mutants: 2 killed, 0 survived' <<<"$out" >/dev/null || fail "unexpected summary:
$out"
after=$(git status --porcelain=v1 -uall | sha256sum; git ls-files -z -co --exclude-standard | xargs -0 sha256sum 2>/dev/null | sha256sum)
[ "$before" = "$after" ] || fail "mutation.sh changed the real tree"
echo PASS
