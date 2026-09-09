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

# The handoff: a DESIGN.md the demo was built from is worth nothing if /wp-init
# scrapes the demo's :root instead of reading it, or leaves it behind in demo/.
i=commands/wp-init.md
y=commands/wp-yolo.md
grep -Fq 'demo/DESIGN.md' "$i" || fail "$i does not read demo/DESIGN.md"
grep -Eqi 'before .*:root|first.*:root|instead of .*:root' "$i" || fail "$i does not prefer DESIGN.md over the :root scrape"
grep -Fq 'DESIGN.md' "$y" || fail "$y does not carry the DESIGN.md contract into the whole-site build"
grep -Fq 'browser' CLAUDE.md || fail "CLAUDE.md does not state the craft browser prerequisite"
grep -Fq 'demo/DESIGN.md' CLAUDE.md || fail "CLAUDE.md does not document the DESIGN.md handoff"

# The token seam. The compositions' CSS names a vocabulary the starter's :root
# has never defined, so a craft demo carried into the theme by name alone would
# reference undefined properties and render unstyled. /wp-init has to write the
# craft vocabulary AND alias the starter's own tokens onto it, or one of the two
# stylesheets goes dead — and the mapping has to be recorded where the next
# agent can read it rather than guess.
for t in --color-canvas --color-surface --color-ink-soft --color-accent-ink --color-hairline --font-display --font-text; do
  grep -Fq -- "$t" "$i" || fail "$i does not write the craft token $t into the theme"
done
for t in --color-primary --color-secondary --color-dark --color-light --color-gray --font-primary --font-secondary; do
  grep -Fq -- "$t" "$i" || fail "$i does not alias the starter token $t onto the craft vocabulary"
done
grep -Fqi 'alias' "$i" || fail "$i does not state that the starter tokens become aliases"
grep -Eqi 'alias table' "$i" || fail "$i does not require the alias table in the theme's copied DESIGN.md"

echo PASS
