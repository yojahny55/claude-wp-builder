#!/usr/bin/env bash
# CONTRIBUTING.md told contributors for months to put their changes in
# `starter-theme/__starter__/` -- a directory that does not exist and has not for
# several releases. Nothing caught it because a path in prose is just prose: the
# repo can be reorganised and the sentence describing it stays green forever.
#
# So this asserts the one property that makes those sentences worth reading: every
# repo path the contributor-facing docs name is a path that exists. It covers the
# paths in backticks (restricted to the repo's own top-level directories, so a
# user-project path like `wp-content/uploads/` is not mistaken for one of ours) and
# every relative markdown link target, which is what BACKLOG.md's reconciliation
# evidence is made of -- a rotted link there turns a delivered item back into a claim.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

DOCS=(CLAUDE.md CONTRIBUTING.md BACKLOG.md)
# The top-level directories this repo ships, read FROM the repo rather than typed here.
# A hard-coded list is a second copy: add a top-level directory, reference it in these
# docs, and every path under it is skipped silently -- the check still passes, having
# validated less than the reader believes. Deriving it cannot go stale.
OWNED_DIRS=$(git ls-tree -d --name-only HEAD 2>/dev/null | paste -sd'|' -)
[ -n "$OWNED_DIRS" ] || fail "could not read the repo's top-level directories from git"
OWNED="^($OWNED_DIRS)/"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
: >"$tmp/paths"

# One extraction, one redirect, and `|| true` scoped to the grep that legitimately finds
# nothing -- never to the pipeline. Attached to the whole pipeline it also swallows a
# failed write, and since the only emptiness guard below passes as long as SOME path was
# extracted, one doc's paths could vanish while the check still reported PASS.
emit() { # <doc> ; reads candidate paths on stdin
  local doc=$1 p
  while IFS= read -r p; do
    printf '%s\t%s\n' "$doc" "$p"
  done
}

for doc in "${DOCS[@]}"; do
  [ -f "$doc" ] || fail "$doc is missing -- this check names it explicitly"

  # Paths in backticks: `bin/wp-config.mjs`, `starter-theme/__tailwind__/`.
  # A backtick span is often an invocation rather than a bare path
  # (`bin/demo-verify.mjs --probe`), so only its first token is a candidate.
  { grep -oE '`[^`]+`' "$doc" || true; } \
    | tr -d '`' \
    | awk '{print $1}' \
    | { grep -E "$OWNED" || true; } \
    | sed 's|/$||' \
    | emit "$doc" >>"$tmp/paths"

  # Relative markdown link targets: [wp-acf](agents/wp-acf.md).
  # `[^)]*` and not `+`: an empty target is broken by definition, and skipping it would
  # be this check declining to look at the most broken link there is.
  # `/` is excluded with the URL schemes: an absolute path is not a repo path, and
  # testing one would answer about the machine the check happens to run on.
  { grep -oE '\]\([^)]*\)' "$doc" || true; } \
    | sed -e 's|^](||' -e 's|)$||' -e 's|#.*$||' \
    | { grep -vE '^(https?:|mailto:|#|/)' || true; } \
    | sed 's|/$||' \
    | emit "$doc" >>"$tmp/paths"
done

# A glob or an angle-bracket placeholder describes a shape, not a file. `bin/*.mjs`
# and `skills/<skill-name>/SKILL.md` are both correct prose and neither is resolvable.
grep -vE $'\t.*[*?<>]' "$tmp/paths" >"$tmp/checkable" || true

[ -s "$tmp/checkable" ] || fail "extracted no checkable paths -- the extraction broke, not the docs"

missing=0
while IFS=$'\t' read -r doc p; do
  # $p is quoted in the message because an empty markdown target -- [text]() -- is one of
  # the things this now looks for, and unquoted it prints as a blank nobody can act on.
  [ -e "$p" ] || { echo "  $doc names '$p' -- which does not exist"; missing=$((missing + 1)); }
done <"$tmp/checkable"

[ "$missing" -eq 0 ] || fail "$missing path(s) named in the contributor docs do not exist"

echo "PASS: $(sort -u "$tmp/checkable" | wc -l) repo paths named in ${DOCS[*]} all exist"
