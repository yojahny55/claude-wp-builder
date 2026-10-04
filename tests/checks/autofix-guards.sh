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
# ...and no second use of it rides a branch or tag beside the pinned one.
unpinned=$(grep -E 'uses:[[:space:]]*alibaba/open-code-review@' "$OCR" \
  | grep -Ev 'uses:[[:space:]]*alibaba/open-code-review@[0-9a-f]{40}([[:space:]]|$)')
[ -z "$unpinned" ] || fail "$OCR: a use of alibaba/open-code-review is not a 40-hex SHA: $unpinned"

# A gate that fails after the eyes reaction must still leave a comment.
grep -Fq "always() && needs.gate.result != 'skipped'" "$AF" \
  || fail "$AF: report no longer runs when the gate fails"

# A thread is resolved on evidence: the pushed patch changed its file. The evidence is
# filter's patch (no PR code ran there), not anything verify (agent-edited code) wrote.
grep -Fq 'for l in read("filtered/filtered.patch").splitlines():' "$AF" \
  || fail "$AF: report no longer derives the changed files from filter's patch"
grep -Fq 'verify/changed.txt' "$AF" \
  && fail "$AF: report reads changed files from verify, a VM that ran agent-edited code"
grep -Fq 'if st == "fixed" and f["path"] in changed:' "$AF" \
  || fail "$AF: a thread is resolved on the agent's word alone, without its file in the patch"

# Agent-influenced text quoted into a comment cannot close the fence or ping anyone. The
# zero-width space is asserted by its bytes: a "strip invisible characters" cleanup of both
# files would otherwise turn defang into a no-op and keep a literal-character grep green.
zwsp=$(printf '\xe2\x80\x8b')
grep -Fq "return s.replace(\"@\", \"@${zwsp}\")" "$AF" \
  || fail "$AF: defang no longer puts a U+200B (e2 80 8b) after @"
grep -Fq "lambda m: \"${zwsp}\".join(m.group())" "$AF" \
  || fail "$AF: defang no longer breaks backtick runs with U+200B (e2 80 8b)"
for use in 'new_out = defang(' 'why = defang(' '`{defang(d[0])}`' '`{defang(u[0])}`'; do
  grep -Fq -- "$use" "$AF" || fail "$AF: agent-influenced text reaches the comment undefanged (missing: $use)"
done

# Filter: an unnamed typechange is dropped like a deletion; an unnamed modification is kept
# but listed for the maintainer, never silently.
grep -Fq 'if [ -z "$why" ] && [ "$st" = T ] && [ "$named" = false ]; then why=' "$AF" \
  || fail "$AF: filter no longer drops a typechange no finding asked for"
grep -Fq '>> "$out/unrequested.txt"' "$AF" && grep -Fq 'read("filtered/unrequested.txt")' "$AF" \
  || fail "$AF: unnamed modifications are no longer recorded and shown in the summary"

# The invariants that make this a maintainer tool rather than an anyone-can-push path.
job() { awk -v j="$1" '$0 ~ "^  "j":" {on=1; print; next} on && /^  [A-Za-z0-9_-]+:/ {exit} on' "$AF"; }
grep -Fq 'admin|maintain|write) ;;' "$AF" \
  || fail "$AF: the maintainer gate (admin|maintain|write) is gone"
grep -Fq 'if [ "$head_repo" != "$REPO" ] || [ "$state" != open ]; then' "$AF" \
  || fail "$AF: the same-repo / open-PR refusal is gone"
fixjob=$(job fix)
printf '%s\n' "$fixjob" | grep -Eq '^      contents: read$' \
  && ! printf '%s\n' "$fixjob" | grep -Eq '^      [a-z-]+: write$' \
  && [ "$(printf '%s\n' "$fixjob" | grep -c 'persist-credentials: false')" -eq "$(printf '%s\n' "$fixjob" | grep -c 'uses: actions/checkout@')" ] \
  || fail "$AF: the fix job (the agent) holds more than contents: read, or checks out with persisted credentials"
pub=$(job publish)
hash_line=$(printf '%s\n' "$pub" | grep -n '\[ "$got" = "$PATCH_SHA" \] ||' | head -1 | cut -d: -f1)
apply_line=$(printf '%s\n' "$pub" | grep -nE '^[[:space:]]*git apply' | head -1 | cut -d: -f1)
[ -n "$hash_line" ] && [ -n "$apply_line" ] && [ "$hash_line" -lt "$apply_line" ] \
  || fail "$AF: publish no longer checks the patch hash before applying it"
pushes=$(printf '%s\n' "$pub" | grep -E '^[[:space:]]*(if )?git push')
[ -n "$pushes" ] && ! printf '%s\n' "$pushes" | grep -Eq -- '--force|[[:space:]]-f([[:space:]]|$)|[[:space:]]"?\+' \
  || fail "$AF: publish's push is forced (--force, -f or a + refspec) or gone"

# ocr-review.yml runs on pull_request_target on a self-hosted rig: safe only while no PR
# code runs there. The sentence stays, and no checkout of the PR head appears.
grep -Fq 'Do not add a step that checks out or runs PR code while this runs on' "$OCR" \
  || fail "$OCR: the no-PR-code-on-the-rig rule is gone from the header"
awk '
  /^[[:space:]]*-[[:space:]]/ { inco = 0 }
  /uses:[[:space:]]*actions\/checkout/ { inco = 1 }
  inco && /(ref|repository):.*(head|refs\/pull|merge)/ { bad = 1 }
  END { exit bad }
' "$OCR" || fail "$OCR: a checkout of the PR head runs on the self-hosted rig under pull_request_target"

if [ "$fails" -gt 0 ]; then
  printf 'FAILED %d\n' "$fails"
  exit 1
fi
printf 'PASS: /autofix guards (protected paths, maintainer gate, read-only agent, hashed non-forced push, base_ref, OCR pin and rig rule, report on gate failure, evidence-based resolution, defanged text)\n'
