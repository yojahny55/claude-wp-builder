#!/usr/bin/env bash
# CI linted PHP and ES modules but never shell, and the shell scripts (bin/*.sh,
# skills/*/scripts/*.sh) are the ones that run sudo, rm and sed with user-derived arguments.
# Pin that ci.yml parses every one of them and runs shellcheck, that shellcheck stays
# blocking (no continue-on-error), and that every exclusion in .shellcheckrc carries its reason.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
CI=.github/workflows/ci.yml

# lint_ci FILE: prints the first reason FILE is not an acceptable shell-lint gate, returns 1.
lint_ci() {
  local ci=$1 job step
  grep -Fq "bash -n" "$ci" || { echo "ci.yml does not run bash -n on the shell scripts"; return 1; }
  grep -Fq "find bin skills tests -name '*.sh'" "$ci" || { echo "ci.yml does not parse bin/, skills/*/scripts/ and tests/"; return 1; }
  [ "$(grep -Fc 'no shell scripts found' "$ci")" -ge 2 ] || { echo "ci.yml lost a zero-script guard"; return 1; }
  grep -Fq 'shellcheck --severity=warning' "$ci" || { echo "ci.yml does not run shellcheck at warning severity"; return 1; }
  # the whole shell-lint job, from its header to the next job at the same level
  job=$(awk '/^  shell-lint:[[:space:]]*$/{f=1;next} f&&/^  [a-z][a-z0-9_-]*:[[:space:]]*$/{f=0} f' "$ci")
  [ -n "$job" ] || { echo "ci.yml has no shell-lint job"; return 1; }
  if grep -Eq 'continue-on-error' <<<"$job"; then
    echo "shell-lint carries continue-on-error (job or step): it is a blocking gate"; return 1
  fi
  # the shellcheck step: from its name to the next step
  step=$(awk '/^      - name: shellcheck/{f=1;print;next} f&&/^      - /{f=0} f' <<<"$job")
  [ -n "$step" ] || { echo "shell-lint has no shellcheck step"; return 1; }
  if grep -Eq '\|\|[[:space:]]*(true|:)' <<<"$step"; then
    echo "the shellcheck step swallows its exit status with || true"; return 1
  fi
  grep -Fq 'exit "$rc"' <<<"$step" || { echo 'the shellcheck step does not end by propagating its exit status (exit "$rc")'; return 1; }
  return 0
}

reason=$(lint_ci "$CI") || fail "$reason"

# the gate must reject the ways it could be quietly disarmed
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sed '/^  shell-lint:/,/timeout-minutes/ s/^    timeout-minutes: 10$/&\n    continue-on-error: true/' "$CI" > "$tmp/job-coe.yml"
sed 's/^          exit "\$rc"$/          exit "$rc" || true/' "$CI" > "$tmp/or-true.yml"
sed 's/^      - name: shellcheck (blocking, severity warning)$/&\n        continue-on-error: true/' "$CI" > "$tmp/step-coe.yml"
sed 's/^          exit "\$rc"$/          true/' "$CI" > "$tmp/no-exit.yml"
for neg in job-coe or-true step-coe no-exit; do
  cmp -s "$CI" "$tmp/$neg.yml" && fail "negative case $neg did not alter ci.yml (fixture drifted)"
  lint_ci "$tmp/$neg.yml" >/dev/null && fail "negative case $neg was accepted: the gate can be disarmed unnoticed"
done

[ -f .shellcheckrc ] || fail ".shellcheckrc is missing"
for code in $(sed -n 's/^disable=//p' .shellcheckrc | tr ',' ' '); do
  grep -Eq "^#.*$code" .shellcheckrc || fail ".shellcheckrc excludes $code without saying why"
done

# the gate it adds must be green on the tree as it stands
n=0
while IFS= read -r f; do
  bash -n "$f" || fail "$f does not parse"
  n=$((n + 1))
done < <(find bin skills tests -name '*.sh' -not -path '*/node_modules/*' | sort)
[ "$n" -gt 0 ] || fail "found no shell scripts to parse"
if command -v shellcheck >/dev/null 2>&1; then
  mapfile -t sc_files < <(find bin skills -name '*.sh' -not -path '*/node_modules/*' | sort)
  shellcheck --severity=warning "${sc_files[@]}" >/dev/null 2>&1 \
    || fail "shellcheck reports findings (blocking in CI)"
fi
echo PASS
