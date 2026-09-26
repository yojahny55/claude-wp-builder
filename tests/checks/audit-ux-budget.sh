#!/usr/bin/env bash
# wp-audit-ux ran 25 minutes on an 8-page store audit while the other six agents finished in
# 8-14: 16 browser launches (one per question), a sweep of 1801 links pulled from a
# mega-menu, and a serial retry loop against production links behind a CDN bot challenge.
# The agent must carry a budget and a stop rule, one harness per run, and a scoped UX-014.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

a=agents/wp-audit-ux.md
std=skills/wp-audit-ux-standards/SKILL.md
[ -f "$a" ] && [ -f "$std" ] || fail "agent or standards missing"

budget=$(awk '/^## Budget and stop rule/{on=1;next} /^## /{on=0} on' "$a")
[ -n "$budget" ] || fail "$a has no Budget and stop rule section"
grep -Fq 'At most 3 browser launches per run' <<<"$budget" || fail "launch cap missing"
grep -Fq 'At most 2 attempts per criterion' <<<"$budget" || fail "per-criterion attempt limit missing"
grep -Fq 'each selector tried' <<<"$budget" || fail "UNMEASURED after attempts must name the selectors tried"
grep -Fq '15 minutes of wall clock' <<<"$budget" || fail "wall-clock target missing"
grep -Fq 'run_in_background' <<<"$budget" || fail "long commands are not sent to the background"
grep -Fq 'Never a `while read` loop over URLs' <<<"$budget" || fail "serial URL loop not forbidden"

# The budget has to be read before measuring starts, not after.
b=$(grep -n '^## Budget and stop rule' "$a" | cut -d: -f1)
s1=$(grep -n '^## Step 1:' "$a" | cut -d: -f1)
[ "$b" -lt "$s1" ] || fail "budget section comes after Step 1"

grep -Fq '**One harness, many probes.**' "$a" || fail "one-harness rule missing"
grep -Fq 'one-off script with its own browser launch' "$a" || fail "one-off scripts not forbidden"
grep -Fq 'not `networkidle`' "$a" || fail "networkidle wait not discouraged"

for t in 'Classify each `href`.' 'Resolve internal targets through WP-CLI first.' \
         '**Deduplicate.**' 'Cap the HTTP sample at 50 per page' '--per-page 50' \
         'Never request the clone-origin host' 'A CDN bot challenge is not a broken link.' \
         'Never retry it'; do
  grep -Fq -- "$t" "$a" || fail "UX-014 scope lost: $t"
done
grep -Fq 'Add `--follow-clone-origin` **only** when the operator confirmed' "$a" \
  || fail "the agent does not say when clone-origin links may be followed"
grep -Fq 'resolve-link-targets.php' "$a" || fail "the agent does not resolve internal targets through the database"
grep -Fq 'Collect every `href`' "$a" && fail "$a still says collect every href"
grep -Fq 'collect every internal `href`' "$std" && fail "$std still says collect every internal href"
grep -Fq 'at most 50 HTTP' "$std" || fail "$std UX-014 lost the 50-per-page cap"
grep -Fq -- '--per-page' bin/link-sweep.mjs || fail "bin/link-sweep.mjs lost --per-page"

echo PASS
