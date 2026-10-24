#!/usr/bin/env bash
# CI linted PHP and ES modules but never shell, and the shell scripts (bin/*.sh,
# skills/*/scripts/*.sh) are the ones that run sudo, rm and sed with user-derived arguments.
# Pin that ci.yml parses every one of them and runs shellcheck, that shellcheck stays
# blocking (no continue-on-error), and that every exclusion in .shellcheckrc carries its reason.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
CI=.github/workflows/ci.yml

grep -Fq "bash -n" "$CI" || fail "ci.yml does not run bash -n on the shell scripts"
grep -Fq "find bin skills -name '*.sh'" "$CI" || fail "ci.yml does not cover bin/ and skills/*/scripts/"
grep -Fq 'shellcheck --severity=warning' "$CI" || fail "ci.yml does not run shellcheck at warning severity"
awk '/name: shellcheck/{f=1} f&&/continue-on-error/{bad=1} /^  [a-z][a-z0-9_-]*:[[:space:]]*$/{f=0} END{exit bad?1:0}' "$CI" \
  || fail "shellcheck regained continue-on-error: it is a blocking gate"

[ -f .shellcheckrc ] || fail ".shellcheckrc is missing"
for code in $(sed -n 's/^disable=//p' .shellcheckrc | tr ',' ' '); do
  grep -Eq "^#.*$code" .shellcheckrc || fail ".shellcheckrc excludes $code without saying why"
done

# the gate it adds must be green on the tree as it stands
n=0
while IFS= read -r f; do
  bash -n "$f" || fail "$f does not parse"
  n=$((n + 1))
done < <(find bin skills -name '*.sh' -not -path '*/node_modules/*' | sort)
[ "$n" -gt 0 ] || fail "found no shell scripts to parse"
if command -v shellcheck >/dev/null 2>&1; then
  mapfile -t sc_files < <(find bin skills -name '*.sh' -not -path '*/node_modules/*' | sort)
  shellcheck --severity=warning "${sc_files[@]}" >/dev/null 2>&1 \
    || fail "shellcheck reports findings (blocking in CI)"
fi
echo PASS
