#!/usr/bin/env bash
# /autofix hands a write token, untrusted PR content and a paid LLM key to one pipeline, and
# its guards are YAML lines that read like tidy-up to a later edit. Each one below closed a
# real finding on PR #142; this pins the line that does it, so deleting one fails here
# instead of in a run that pushed something it should not have.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1
AF=".github/workflows/autofix.yml"
CI=".github/workflows/ci.yml"
OCR=".github/workflows/ocr-review.yml"
fails=0
fail() { printf 'FAIL: %s\n' "$1"; fails=$((fails + 1)); }

for f in "$AF" "$CI" "$OCR"; do
  [ -f "$f" ] || { printf 'FAIL: %s is missing\n' "$f"; exit 1; }
done

# The checks verify runs to judge the patch, and the baselines they compare against, are
# never agent-editable -- not even when a finding (untrusted text) names the file.
grep -Fq 'tests/checks/*|tests/baselines/*) why="protected path (never agent-editable' "$AF" \
  || fail "$AF: tests/checks/ and tests/baselines/ are no longer protected unconditionally in filter"

# A caller-supplied base_ref reaches git only after `--`, only in a branch-name shape, and
# only when HEAD is ahead of it (else both doc-sync gates pass having compared nothing).
grep -Fq 'git fetch --no-tags origin -- "$BASE_REF"' "$CI" \
  || fail "$CI: the base ref fetch lost its -- (a base_ref starting with - becomes a git option)"
grep -Fq '[[ "$BASE_REF" =~ ^[A-Za-z0-9._/-]+$ ]]' "$CI" \
  || fail "$CI: base_ref is no longer refused when it does not look like a branch name"
grep -Fq 'ahead=$(git rev-list --count "origin/$BASE_REF..HEAD")' "$CI" \
  && grep -Fq '[ "$ahead" -gt 0 ] || { echo "::error::HEAD is not ahead of' "$CI" \
  || fail "$CI: doc-sync no longer refuses a base_ref HEAD is not ahead of"

# A mutable action ref on pull_request_target runs any upstream push with the LLM key.
grep -Eq '^[[:space:]]+uses: alibaba/open-code-review@[0-9a-f]{40}([[:space:]]|$)' "$OCR" \
  || fail "$OCR: alibaba/open-code-review is not pinned to a full commit SHA"

# A gate that fails after the eyes reaction must still leave a comment.
grep -Fq "always() && needs.gate.result != 'skipped'" "$AF" \
  || fail "$AF: report no longer runs when the gate fails"

# A thread is resolved on evidence: the pushed patch changed its file.
grep -Fq 'changed = set(read("verify/changed.txt").splitlines())' "$AF" \
  || fail "$AF: report no longer reads verify's changed.txt"
grep -Fq 'if st == "fixed" and f["path"] in changed:' "$AF" \
  || fail "$AF: a thread is resolved on the agent's word alone, without its file in changed.txt"
grep -Fq 'cp "$RUNNER_TEMP/changed.txt" "$out/changed.txt"' "$AF" \
  || fail "$AF: verify no longer uploads changed.txt, so report cannot tell what was changed"

if [ "$fails" -gt 0 ]; then
  printf 'FAILED %d\n' "$fails"
  exit 1
fi
printf 'PASS: /autofix guards (protected checks and baselines, base_ref, OCR pin, report on gate failure, evidence-based resolution)\n'
