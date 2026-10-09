#!/usr/bin/env bash
# Changelog entries live in changes/<slug>.<section>.md fragments, one file per PR, compiled
# into CHANGELOG.md at release by bin/changelog-release.sh.
#
# Why: every PR used to insert under the same `## [Unreleased]` heading. Git resolved that
# locally through `merge=union`, but GitHub ignores merge drivers, so merging one PR marked
# every other open PR as conflicting on CHANGELOG.md. Distinct files cannot conflict.
#
# This pins the fragment format and runs the release script against a scratch copy.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

order="added changed deprecated removed fixed security"
n=0
for f in changes/*.md; do
  [ "$f" = changes/README.md ] && continue
  n=$((n + 1))
  b=$(basename "$f" .md)
  [[ "$b" == *.* ]] || fail "$f: name must be <slug>.<section>.md"
  [[ " $order " == *" ${b##*.} "* ]] || fail "$f: section '${b##*.}' is not one of: $order"
  head -n1 "$f" | grep -q '^- ' || fail "$f: first line must start with '- '"
  grep -q '^#' "$f" && fail "$f: carries a heading; the release script adds the section heading"
done
[ -f changes/README.md ] || fail "changes/README.md is missing"
[ ! -f .gitattributes ] || ! grep -q 'CHANGELOG.md.*merge=union' .gitattributes \
  || fail "CHANGELOG.md is merge=union again: it hides the conflict locally and GitHub ignores it"

# Release script on a scratch copy: Unreleased text and fragments land in one block, in section
# order, fragments are consumed, and Unreleased stays as an empty anchor.
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/bin" "$t/changes"
cp bin/changelog-release.sh "$t/bin/"
printf '%s\n' '# Changelog' '' '## [Unreleased]' '' '### Added' '' '- old added' '' '## [1.0.0] - 2026-01-01' '' '### Added' '' '- first' > "$t/CHANGELOG.md"
printf '%s\n' '- frag fixed' > "$t/changes/a.fixed.md"
printf '%s\n' '- frag added' > "$t/changes/b.added.md"
printf '%s\n' 'x' > "$t/changes/README.md"
( cd "$t" && bash bin/changelog-release.sh 1.1.0 2026-02-02 >/dev/null )
out="$t/CHANGELOG.md"
grep -qx '## \[Unreleased\]' "$out" || fail "release script dropped the Unreleased anchor"
grep -qx '## \[1.1.0\] - 2026-02-02' "$out" || fail "release script wrote no release heading"
ls "$t/changes" | grep -qx 'a.fixed.md' && fail "release script left a compiled fragment behind"
[ -f "$t/changes/README.md" ] || fail "release script deleted changes/README.md"
awk '/^## \[Unreleased\]/{u=NR} /^## \[1.1.0\]/{r=NR} /^## \[1.0.0\]/{o=NR} END{exit !(u<r && r<o)}' "$out" \
  || fail "release block is not between Unreleased and the previous release"
awk '/- old added/{a=NR} /- frag added/{b=NR} /- frag fixed/{c=NR} END{exit !(a && b && c && a<b && b<c)}' "$out" \
  || fail "entries are not ordered old-Added, fragment-Added, then Fixed"
[ "$(grep -c '^### Added' "$out")" -eq 2 ] || fail "expected one Added section per release block"
( cd "$t" && bash bin/changelog-release.sh 1.1.0 2026-02-02 2>/dev/null ) && fail "release script re-ran for an existing version"

# No fragments (legacy Unreleased only): must not trip `set -u` on an empty array (bash < 4.4).
rm -f "$t"/changes/*.fixed.md "$t"/changes/*.added.md
printf '%s\n' '# Changelog' '' '## [Unreleased]' '' '### Fixed' '' '- only legacy' > "$t/CHANGELOG.md"
( cd "$t" && bash bin/changelog-release.sh 1.2.0 2026-03-03 >/dev/null 2>&1 ) || fail "release script failed with no fragments"
grep -q -- '- only legacy' "$t/CHANGELOG.md" || fail "legacy Unreleased entry lost when there are no fragments"
# Text outside any section must refuse, not vanish.
printf '%s\n' '# Changelog' '' '## [Unreleased]' '' '- bare entry' '' '### Added' '' '- a' > "$t/CHANGELOG.md"
( cd "$t" && bash bin/changelog-release.sh 1.3.0 2026-04-04 >/dev/null 2>&1 ) && fail "release script dropped text outside a section instead of refusing"
grep -q -- '- bare entry' "$t/CHANGELOG.md" || fail "refusal still rewrote CHANGELOG.md"

echo "PASS: $n fragment(s) well formed, release script compiles in order"
