#!/usr/bin/env bash
# CHANGELOG.md is written only at release, by bin/changelog-release.sh from changes/
# fragments (see changes/README.md), so branches no longer append to it concurrently. This
# guards the shape of the compiled file, which a hand edit at release can still break.
#
# Before fragments, merge=union hid every concurrent edit and a structural mistake landed
# silently. It landed twice. Both times a branch added a "### Added" or "### Fixed" heading under
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
# -f proves it exists, not that it can be read, and every assertion below is a grep. Without
# this an unreadable file reports whichever assertion happens to run first -- "no Unreleased
# heading", "lists 0 version blocks" -- each pointing at the file's contents rather than at
# the fact that nothing could read them.
[ -r "$f" ] || fail "$f exists but cannot be read"

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
  fail "a version block repeats a section heading -- a hand-edited release can ship this unless something looks"
fi

# `grep -c` exits 1 on zero matches and 2 on a real error, and collapsing both into `|| true`
# would report an unreadable file as "lists 0 version blocks" -- a diagnostic pointing at the
# wrong thing. `-f` above proves the file exists, not that it can be read.
if ! versions=$(grep -c '^## \[' "$f"); then
  status=$?
  [ "$status" -eq 1 ] || fail "could not read $f (grep exited $status)"
  versions=0
fi
[ "$versions" -ge 2 ] || fail "$f lists $versions version block(s); the extraction is broken, not the file"

echo "PASS: $versions version blocks, no repeated section headings, Unreleased intact"
