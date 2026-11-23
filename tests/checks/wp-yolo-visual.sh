#!/usr/bin/env bash
# /wp-yolo --visual: the visual QA loop after seeding. /wp-section --visual cannot run inside
# /wp-yolo's build, because every section is built before /wp-seed and would measure an empty
# page, so /wp-yolo runs the same visual check itself at Step 5 item 3, once content exists.
# This pins what keeps that pass safe: opt-in, before /wp-finalize so the parity gate sees its
# fixes, one section at a time (a reverted round must not undo another section's CSS), never
# blocking the run, and the inner-page lookup by slug that page-<slug>.php pages need.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

cmd=commands/wp-yolo.md
ref=skills/wp-yolo-run/references/visual-pass.md
check=skills/wp-section-run/references/visual-check.md
[ -f "$ref" ] || fail "$ref is missing"

need_token "$cmd" '[--force] [--visual] [--resume'
need_token "$cmd" '- **`--visual`** = once the pages are seeded'
need_token "$cmd" '**With `--visual` only:** read'
need_token "$cmd" 'Visual:            <counts, only with --visual'
need_token docs/commands.md '/wp-yolo <demo-folder> [--yolo | --careful] [--visual]'

# The pointer sits in Step 5 item 3, after the rebuild and before /wp-finalize (item 4).
lp=$(grep -n 'skills/wp-yolo-run/references/visual-pass.md` now and follow it' "$cmd" | cut -d: -f1)
l3=$(grep -n '^3\. \*\*Rebuild Tailwind CSS\*\*' "$cmd" | cut -d: -f1)
l4=$(grep -n '^4\. \*\*`/wp-finalize`\*\*' "$cmd" | cut -d: -f1)
[ -n "$lp" ] && [ -n "$l3" ] && [ -n "$l4" ] || fail "$cmd lost Step 5 item 3, item 4 or the visual-pass pointer"
[ "$l3" -lt "$lp" ] && [ "$lp" -lt "$l4" ] || fail "the visual pass must run inside Step 5 item 3, before /wp-finalize"

need_token "$ref" 'skills/wp-section-run/references/visual-check.md` and follow its'
need_token "$ref" 'Never measure or fix two sections in parallel.'
need_token "$ref" '**It never makes the run incomplete.**'
need_token "$ref" '**It never creates or seeds content to measure.**'
need_token "$ref" '**An exit 2 for a missing tool stops the pass.**'
need_token "$ref" 'Any other exit 2 is one page that'
# The two stderr lines the pass stops on must still be the ones section-diff prints.
for m in 'playwright-core, pixelmatch or pngjs is not installed' 'no existing Chrome or Chromium'; do
  need_token "$ref" "$m"
  need_token bin/section-diff.mjs "$m"
done
need_token "$ref" '(`--resume --visual`)'
need_token "$cmd" '--resume [--accept-drift] [--visual]'
need_token "$ref" 'assets/css/src/tailwindcss/components/`, `layouts/` or `utilities/`'
need_token "$ref" 'before/.listing'
need_token "$ref" 'is `group_<slug>`, where `<slug>` is'
need_token "$ref" 'The three-round cap is per section.'
need_token "$ref" '`kind: "cpt-teaser"` sections'
need_token "$ref" 'visual: skipped'
need_token "$ref" 'Without `--visual`, Step 6 prints no `Visual:` line.'

# Inner pages get page-<slug>.php by slug, with no _wp_page_template meta, so the page lookup
# in visual-check must fall back to the slug or every inner section is "not measured".
need_token "$check" '--name=<slug> --fields=ID,url'
need_token "$check" '`/wp-yolo --visual` runs this file itself'
need_token "$check" 'find "<theme-dir>/assets/css/src/tailwindcss" -type f | sort > "$out/before/.listing"'
# The undo paragraph itself deletes the round's new files, by the listing, not by guesswork.
awk '/^\*\*A round that made it worse is undone\.\*\*/{on=1} on&&/^$/{exit} on' "$check" \
  | grep >/dev/null -c 'not in that round'"'"'s `before/.listing`' \
  || fail "$check: the undo step no longer deletes the round's new files by the listing"

echo "PASS: /wp-yolo --visual measures each seeded section, one at a time, before /wp-finalize, never blocking"
