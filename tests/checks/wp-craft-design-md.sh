#!/usr/bin/env bash
# The catalogue is the craft skill's positive vocabulary: real tokens from real
# sites. It travels with its licence, is indexed so a build can find a nearest
# match without reading dozens of files, and ships one neutral file the
# composition previews render against so the previews show the compositions,
# not a brand. Only 64 of the upstream repo's 74 domains are vendored: the
# other ten carry no YAML front matter (pure prose, pre-dating the front-matter
# convention) and so cannot supply the parseable colours/typography this
# catalogue depends on — that omission is deliberate, not a botched copy.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

d=skills/wp-demo-craft/references/design-md

[ -f "$d/LICENSE" ] || fail "$d/LICENSE is missing; the catalogue is MIT and the licence travels"
grep -Fqi 'MIT' "$d/LICENSE" || fail "$d/LICENSE is not the MIT text"
[ -f "$d/INDEX.md" ] || fail "$d/INDEX.md is missing"
n=$(find "$d" -mindepth 2 -name DESIGN.md | wc -l)
[ "$n" -ge 60 ] || fail "expected at least 60 vendored DESIGN.md files, found $n"
# Every entry is indexed, every index row exists.
for f in "$d"/*/DESIGN.md; do
  dom=$(basename "$(dirname "$f")")
  grep -Fq "| $dom |" "$d/INDEX.md" || fail "INDEX.md is missing the row for $dom"
  awk 'NR==1 && /^---$/ { f = 1 } END { exit !f }' "$f" || fail "$f has no front matter"
done
grep -Eq '^\| domain \| industry \| tone \| display \| accent \|' "$d/INDEX.md" \
  || fail "INDEX.md header row is not: domain, industry, tone, display, accent"

# The neutral preview reference defines the token vocabulary compositions use.
p="$d/_preview.md"
[ -f "$p" ] || fail "$p is missing"
for t in canvas surface ink ink-soft accent accent-ink hairline; do
  grep -Eq "^  $t: " "$p" || fail "$p does not define the token: $t"
done
grep -Eq '^  display:' "$p" || fail "$p does not define the display face"
grep -Eq '^  text:' "$p" || fail "$p does not define the text face"

echo PASS
