#!/usr/bin/env bash
# CHANGELOG.md is marked merge=union in .gitattributes so that concurrent branches appending
# under the same heading merge instead of conflicting. The cost, stated in the release chores
# in CLAUDE.md, is that union never reports a conflict -- so a structural mistake lands
# silently, passes every test, and is found only by someone reading the top of the file.
#
# It has landed twice. Both times a branch added a "### Added" or "### Fixed" heading under
# ## [Unreleased] without checking whether that block already had one, and the release went
# out carrying two of the same section. Nothing in the suite looked at the file's shape.
#
# This looks at the shape: within any one version block, a section heading appears at most
# once, and ## [Unreleased] exists for the next branch to append to.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

f=CHANGELOG.md
[ -f "$f" ] || fail "$f is missing"

# The release chore inserts a new version heading BELOW ## [Unreleased] and leaves it empty,
# because renaming it would delete the anchor every open branch is appending to and turn one
# release into a CHANGELOG conflict on every open PR at once.
grep -qx '## \[Unreleased\]' "$f" \
  || fail "$f has no '## [Unreleased]' heading -- a release renamed it instead of inserting below it, and every open branch now appends to a heading that is gone"

problems=$(awk '
  /^## \[/ { version = $0; delete seen; next }
  /^### / {
    if (version == "") next
    if ($0 in seen) {
      printf "%s carries a duplicate \"%s\" section (line %d)\n", version, $0, NR
    }
    seen[$0] = 1
  }
' "$f")

if [ -n "$problems" ]; then
  echo "$problems" | sed 's/^/  /'
  fail "a version block repeats a section heading -- merge=union never reports this as a conflict, so it ships unless something looks"
fi

versions=$(grep -c '^## \[' "$f" || true)
[ "${versions:-0}" -ge 2 ] || fail "$f lists ${versions:-0} version block(s); the extraction is broken, not the file"

echo "PASS: $versions version blocks, no repeated section headings, Unreleased intact"
