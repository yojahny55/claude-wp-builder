#!/usr/bin/env bash
# /wp-section --visual: the second phase of the visual QA loop. bin/section-diff.mjs measures a
# built section against its demo section; Step 6.6 runs it after the CSS is compiled and hands
# a viewport over tolerance back to the CSS agent, at most three rounds. This pins the contract
# that keeps the loop safe: opt-in, skipped on cinematic, no page created to measure, exits 2
# and 4 never fail a section, the fix touches only this section's rules with demo values, and
# the loop stops when the difference stops shrinking.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

cmd=commands/wp-section.md
ref=skills/wp-section-run/references/visual-check.md
[ -f "$ref" ] || fail "$ref is missing"

need_token "$cmd" '- **`--visual` flag** ='
need_token "$cmd" '[--no-blog-page] [--visual] [--force-adopted]"'
need_token "$cmd" '## Step 6.6: Visual check (`--visual` only)'
need_token "$cmd" 'skills/wp-section-run/references/visual-check.md'
need_token "$cmd" '  - Visual: pass | pass after <n> fix rounds | over tolerance'
need_token skills/wp-section-run/SKILL.md '[references/visual-check.md](references/visual-check.md)'

# Step order: the check runs on compiled CSS, before the blog step and the summary.
l65=$(grep -n '^## Step 6.5:' "$cmd" | cut -d: -f1)
l66=$(grep -n '^## Step 6.6:' "$cmd" | cut -d: -f1)
l67=$(grep -n '^## Step 6.7:' "$cmd" | cut -d: -f1)
[ "$l65" -lt "$l66" ] && [ "$l66" -lt "$l67" ] || fail "Step 6.6 must sit between Step 6.5 (CSS rebuilt) and Step 6.7"

need_token "$ref" 'bin/section-diff.mjs" --demo demo/<page>.html --site <url>'
need_token "$ref" '--section <slug> --out "$out" --json'
need_token "$ref" 'create a page to measure.'
need_token "$ref" 'Exits 2 and 4 never fail the section'
need_token "$ref" '`Template: cinematic`: skip'
need_token "$ref" '**Fix only this section'"'"'s own rules.**'
need_token "$ref" '**Take the value from the demo, never from the pixels.**'
need_token "$ref" '`not CSS: <reason>`'
need_token "$ref" 'three fix rounds done'
need_token "$ref" 'fell by less than half a point'
need_token "$ref" 'directory so each round'"'"'s images stay apart'
need_token "$ref" 'content not seeded yet'
need_token "$ref" '**Before each round, keep a copy**'
need_token "$ref" '**A round that made it worse is undone.**'
need_token "$ref" '**Never rename the section'"'"'s root class or its block.**'
need_token "$ref" "meta_key LIKE %s"

# The ref names the fields and exit codes section-diff really has.
for f in diffPercent widthDeltaPercent heightDeltaPercent; do
  need_token bin/section-diff.mjs "$f"
  need_token "$ref" "\`$f\`"
done
for code in 0 1 2 4 64; do
  grep >/dev/null -cE "^\| $code \|" "$ref" || fail "$ref has no row for section-diff exit $code"
done
need_token bin/lib/exit-codes.mjs "'section-diff.mjs': {"
node -e '
  import("./bin/lib/exit-codes.mjs").then(({ TOOLS }) => {
    const want = ["0", "1", "2", "4", "64"];
    const got = Object.keys(TOOLS["section-diff.mjs"]).sort();
    if (got.join() !== want.slice().sort().join()) { console.error("section-diff exit codes changed: " + got.join()); process.exit(1); }
  });' || fail "section-diff.mjs exit codes no longer match the table in $ref"

need_token BACKLOG.md 'tests/checks/section-visual-loop.sh'
echo "PASS: /wp-section --visual measures the section against its demo and loops the CSS agent at most three rounds"
