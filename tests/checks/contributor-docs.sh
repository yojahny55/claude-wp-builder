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
# Top-level directories this repo actually ships. A backtick path is only checked
# when it starts with one of these -- everything else in those docs is a path inside
# a generated WordPress project, not here.
OWNED='^(bin|agents|commands|skills|starter-theme|templates|tests|docs)/'

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
: >"$tmp/paths"

for doc in "${DOCS[@]}"; do
  [ -f "$doc" ] || fail "$doc is missing -- this check names it explicitly"

  # Paths in backticks: `bin/wp-config.mjs`, `starter-theme/__tailwind__/`.
  # A backtick span is often an invocation rather than a bare path
  # (`bin/demo-verify.mjs --probe`), so only its first token is a candidate.
  grep -oE '`[^`]+`' "$doc" \
    | tr -d '`' \
    | awk '{print $1}' \
    | grep -E "$OWNED" \
    | sed 's|/$||' \
    | while read -r p; do printf '%s\t%s\n' "$doc" "$p"; done >>"$tmp/paths" || true

  # Relative markdown link targets: [wp-acf](agents/wp-acf.md)
  grep -oE '\]\([^)]+\)' "$doc" \
    | sed -e 's|^](||' -e 's|)$||' -e 's|#.*$||' \
    | grep -vE '^(https?:|mailto:|#|$)' \
    | sed 's|/$||' \
    | while read -r p; do printf '%s\t%s\n' "$doc" "$p"; done >>"$tmp/paths" || true
done

# A glob or an angle-bracket placeholder describes a shape, not a file. `bin/*.mjs`
# and `skills/<skill-name>/SKILL.md` are both correct prose and neither is resolvable.
grep -vE $'\t.*[*?<>]' "$tmp/paths" >"$tmp/checkable" || true

[ -s "$tmp/checkable" ] || fail "extracted no checkable paths -- the extraction broke, not the docs"

missing=0
while IFS=$'\t' read -r doc p; do
  [ -e "$p" ] || { echo "  $doc names $p -- which does not exist"; missing=$((missing + 1)); }
done <"$tmp/checkable"

[ "$missing" -eq 0 ] || fail "$missing path(s) named in the contributor docs do not exist"

echo "PASS: $(sort -u "$tmp/checkable" | wc -l) repo paths named in ${DOCS[*]} all exist"
