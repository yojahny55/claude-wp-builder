#!/usr/bin/env bash
# An audit that produces nothing anyone can hand over is an audit that has to be run again
# by whoever asks for its result. /wp-audit printed to the console and wrote a ledger:
# the first is gone with the scrollback, the second is a working file of check ids.
#
# Two contracts are pinned here, and both are the kind that erode silently.
#
# The renderer is real code, so it is exercised rather than grepped: fixtures in, documents
# out, and the assertions are on what it wrote. What a grep over the prose cannot see is a
# table that shifted a column because an evidence string carried a pipe, or an HTML file
# that renders perfectly on this machine because it fetches a stylesheet this machine has
# cached.
#
# The command's prose is grepped, because that is all it is. The needle that matters most
# is the four-way split of a fix: code travels with the commit, a setting does not. Drop
# that distinction and every database fix applied on a local clone reads as delivered.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

c=commands/wp-audit.md
r=bin/audit-report.mjs
for f in "$c" "$r"; do
  [ -f "$f" ] || fail "$f is missing"
  [ -r "$f" ] || fail "$f exists but cannot be read"
done
[ -x "$r" ] || fail "$r is not executable -- the command invokes it directly"

need() { grep -Fq -- "$1" "$c" || fail "$c $2"; }

# ---------------------------------------------------------------------------
# 1. The command's contract
# ---------------------------------------------------------------------------
need '--report md|html|both' 'has no --report flag, so an audit still produces no deliverable'
need 'Step 8.5: Write the dated deliverable' 'has no step that writes the deliverable'

# Ownership is the whole point of the plan table. Four owners, and the one that gets lost.
for owner in '`code`' '`setting`' '`content`' '`manual`'; do
  need "$owner" "does not name the $owner owner of a fix"
done
need 'does not travel with the commit' \
  'does not say that a setting stays behind -- a database fix applied on a local clone would read as delivered'
need 'staging panel has no WP-CLI' \
  'does not say why a setting cannot simply be re-applied the same way, which is what makes it a step to repeat'
need 'never from whether the audit can do it' \
  'lets ownership be derived from what the audit can automate, which collapses setting into code'

# Report before fix, or the baseline the next run compares against never existed.
need 'before Step 9, always' 'does not require the report to be written before the fix phase'
need 'no before to compare with' 'does not say what fixing first costs'

# The renderer is invoked, not reimplemented, and its refusal is part of the contract.
grep -Fq 'bin/audit-report.mjs' "$c" || fail "$c does not invoke $r"
need 'refuses a finding with no `ownership`' \
  'does not state that the renderer rejects an unowned finding, so the last column could ship blank'

# Two sources of findings, one report. The rule and the key it matches on have to live in
# the step that executes them -- the first version of this stated the rule in Step 6.5 and
# left Step 7 saying something else, so nothing would ever have applied it.
need 'A measurement beats an inference' 'does not resolve a measured finding against an inferred one'
need 'same defect only when the check' \
  'does not say what makes two findings the same defect, so the merge key is whatever each reader assumes'
need '| a site-level judgement | `site` |' 'does not give site-level findings a resource'
need 'one row per page, not one per occurrence' \
  'does not fix the granularity of a page-level finding, so the agent and the suite count differently and both copies survive'
grep -Fq -- '--merge' "$c" || fail "$c does not pass the suite run file to the renderer, leaving the merge to be done by hand"

# Every agent has to emit an owner, or the renderer refuses the run it was handed.
need 'Owner: <code|setting|content|manual>' \
  'does not ask the agents for an owner, so every non-UX finding would be refused by the renderer'
need 'still `setting` if it wrote to the database' \
  'does not stop an auto-applied database fix being reported as code'

# The sidecar, and the reason it is not the ledger.
need 'never parses its own Markdown back' \
  'does not forbid reading the rendered report back, so a hand-edited report could rewrite the next comparison'
need 'a sidecar is one dated snapshot' 'does not distinguish the snapshot from the ledger'

# ---------------------------------------------------------------------------
# 2. The renderer, exercised
# ---------------------------------------------------------------------------
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

# A pipe in the evidence and in the fix: the value most likely to carry one is a shell
# pipeline, and a Markdown cell ends at the next pipe.
cat > "$tmp/run1.json" <<'JSON'
{
  "site": "fixture",
  "date": "2026-09-01",
  "tier": "Code + Runtime",
  "categories": ["security", "seo"],
  "findings": [
    {"check":"SEC-036","resource":"wp_options.siteurl","severity":"CRITICAL","ownership":"setting","category":"security","page":"/","message":"Development host in siteurl","fix":"wp option get siteurl | grep local"},
    {"check":"SEO-012","resource":"post:412","severity":"WARNING","ownership":"content","category":"seo","page":"/services","message":"Missing meta description","fix":"Write 150-160 characters"},
    {"check":"A11Y-003","resource":"style.css:88","severity":"WARNING","ownership":"code","category":"a11y","page":"/","message":"Contrast 3.2:1","fix":"Raise to 4.5:1"}
  ],
  "unmeasured": [{"check":"PERF-LCP","reason":"no browser tool available"}]
}
JSON

node "$r" --run "$tmp/run1.json" --out "$tmp/out" --format both >/dev/null \
  || fail "$r exited non-zero on a valid run"

md="$tmp/out/informe-2026-09-01.md"
html="$tmp/out/informe-2026-09-01.html"
side="$tmp/out/informe-2026-09-01.json"
for f in "$md" "$html" "$side"; do
  [ -s "$f" ] || fail "$r did not write $(basename "$f")"
done

# The sidecar is the file every later comparison is built from, so "it exists and is not
# empty" is the wrong assertion: a truncated one passes it and then fails section 3 with an
# error about the comparison rather than about the file.
node -e 'const d=require(process.argv[1]); if(!Array.isArray(d.findings)) { console.error("no findings array"); process.exit(1); }' "$side" \
  || fail "$side is not a readable sidecar -- the next run would diff against nothing"

# The dated name is what makes two reports comparable, and what stops a re-run overwriting
# the baseline it is supposed to be measured against.
grep -Fq '2026-09-01' "$md" || fail "$md does not carry the audit date"

# Every plan row ends with an owner. A blank last column is the state this file exists to
# refuse, and it looks exactly like a populated one until someone reads it.
for owner in Code Setting Content; do
  grep -Fq "$owner" "$md" || fail "$md never prints the $owner owner"
done
grep -Fq '| Setting |' "$md" || fail "$md does not end the setting row with its owner"

# The pipe survived as content instead of splitting the row: the cell is still one cell.
grep -Fq 'wp option get siteurl \| grep local' "$md" \
  || fail "$md did not escape a pipe inside a table cell -- the row silently shifts a column"

# These assertions quote the renderer's STRINGS templates verbatim on purpose: the wording
# is what the client reads, so a reword in bin/audit-report.mjs that looks cosmetic breaks
# them, and that is the point.
# The split is stated as a count, which is the sentence that answers "how much is mine?".
grep -Fq '1 in code, 1 in settings, 1 content, 0 manual' "$md" \
  || fail "$md does not print the four-way count of the plan"

# A setting is a step to repeat, and the report has to say so where the client reads it,
# not only in the command's prose where nobody outside the session ever looks.
grep -Fq 'travel with the commit' "$md" \
  || fail "$md carries no warning that a setting does not travel with the commit"
grep -Fq 'staging and production' "$md" \
  || fail "$md does not say where a setting has to be repeated"

# UNMEASURED is not a pass, and a report that omits it reads as complete.
grep -Fq 'PERF-LCP' "$md" || fail "$md drops the unmeasured checks"

# The HTML is one file. Not "mostly one file": a single fetch that fails offline or inside
# a mail client turns a deliverable into a broken page, and it always renders on the
# machine that made it.
# Every way a page reaches the network, not only the one that was easiest to grep. The
# comment above promises the file fetches nothing, and a check that only caught
# `src="https://` let `url(//cdn...)` inside the <style> block through while still passing.
if grep -Eq '(src|href|srcset|data|poster)[[:space:]]*=[[:space:]]*"?'"'"'?(https?:)?//' "$html"; then
  fail "$html references an external resource by URL -- it must survive being opened offline"
fi
if grep -Eq 'url\([[:space:]]*"?'"'"'?(https?:)?//' "$html"; then
  fail "$html fetches a stylesheet resource with url() -- it must survive being opened offline"
fi
if grep -Eq '@import|<link[^>]+rel="stylesheet"' "$html"; then
  fail "$html imports a stylesheet -- every style must be inline"
fi
if grep -Fq '<script' "$html"; then
  fail "$html carries a script -- a printed report needs none"
fi
grep -Fq '<!DOCTYPE html>' "$html" || fail "$html is not a complete document"
grep -Fq '@media print' "$html" || fail "$html has no print rules, so printing to PDF is what it looks like"

# ---------------------------------------------------------------------------
# 3. The comparison, on a second run
# ---------------------------------------------------------------------------
cat > "$tmp/run2.json" <<'JSON'
{
  "site": "fixture",
  "date": "2026-09-15",
  "categories": ["security", "seo"],
  "findings": [
    {"check":"SEC-036","resource":"wp_options.siteurl","severity":"CRITICAL","ownership":"setting","category":"security","page":"/","message":"Development host in siteurl"},
    {"check":"A11Y-003","resource":"style.css:88","severity":"WARNING","ownership":"code","category":"a11y","page":"/","message":"Contrast 3.2:1"},
    {"check":"WP-048","resource":"post:412.related_posts","severity":"WARNING","ownership":"code","category":"best-practices","page":"/","message":"Orphan ACF id still rendered"}
  ]
}
JSON

node "$r" --run "$tmp/run2.json" --out "$tmp/out" --format md >/dev/null \
  || fail "$r exited non-zero on the second run"
md2="$tmp/out/informe-2026-09-15.md"
[ -s "$md2" ] || fail "$r did not write the second report"

# Identity, not arithmetic: one resolved, one new, one carried, and the counts are equal
# either side. A report that only counted would call this "no change".
grep -Fq 'Resolved since the previous run:** 1' "$md2" \
  || fail "$md2 does not report the finding that disappeared"
grep -Fq 'New since the previous run:** 1' "$md2" \
  || fail "$md2 does not report the finding that appeared"
grep -Fq 'Still failing:** 2' "$md2" || fail "$md2 does not report the carried findings"
grep -Fq 'SEO-012' "$md2" || fail "$md2 does not name the resolved finding"
grep -Fq '2026-09-01' "$md2" || fail "$md2 does not name the run it compared against"

# ---------------------------------------------------------------------------
# 3b. The merge: two sources, one report
# ---------------------------------------------------------------------------
cat > "$tmp/agents.json" <<'JSON'
{"site":"fixture","date":"2026-09-18","findings":[
  {"check":"A11Y-003","resource":"page:/contact/","severity":"WARNING","ownership":"code","message":"contrast inferred from the stylesheet"},
  {"check":"A11Y-003","resource":"assets/css/main.css:88","severity":"WARNING","ownership":"code","message":"a rule no audited page uses"},
  {"check":"WP-048","resource":"post:412","severity":"INFO","ownership":"code","message":"only the agent saw this"}
]}
JSON
cat > "$tmp/measured.json" <<'JSON'
{"site":"fixture","date":"2026-09-18","findings":[
  {"check":"A11Y-003","resource":"page:/contact/","severity":"WARNING","ownership":"code","measured":true,"message":"contrast measured at 3.1:1","evidence":"axe"}
]}
JSON
node "$r" --run "$tmp/agents.json" --merge "$tmp/measured.json" --out "$tmp/merged" --format md >/dev/null \
  || fail "$r failed to merge two run files"
m="$tmp/merged/informe-2026-09-18.md"
grep -Fq 'contrast measured at 3.1:1' "$m" || fail "$m dropped the measured finding -- a measurement must beat an inference"
grep -Fq 'contrast inferred from the stylesheet' "$m" \
  && fail "$m kept both copies of one defect, which inflates every count"
# Same check, different resource: two real findings, and the second is the one nobody would
# find again. Merging on the check alone would silently delete it.
grep -Fq 'a rule no audited page uses' "$m" \
  || fail "$m merged two findings that share a check but not a resource -- they are different defects"
grep -Fq 'only the agent saw this' "$m" || fail "$m dropped a finding only one source reported"

# ---------------------------------------------------------------------------
# 3c. The values that reach the document without passing through a table cell
# ---------------------------------------------------------------------------
# The plan table escapes every cell. The comparison bullets did not, and a message is
# author-supplied text: a newline breaks out of the list item, and a backtick closes the
# code span the identity is wrapped in.
cat > "$tmp/before.json" <<'JSON'
{"site":"fixture","date":"2026-09-20","findings":[
  {"check":"UX-001","resource":"page:/a/","severity":"WARNING","ownership":"code","message":"first line\nsecond line pretending to be a bullet"},
  {"check":"UX-002","resource":"weird`resource","severity":"INFO","ownership":"code","message":"a backtick in the resource"}
]}
JSON
cat > "$tmp/after.json" <<'JSON'
{"site":"fixture","date":"2026-09-21","findings":[
  {"check":"UX-003","resource":"page:/a/","severity":"INFO","ownership":"code","message":"something else"}
]}
JSON
node "$r" --run "$tmp/before.json" --out "$tmp/esc" --format md >/dev/null || fail "$r failed on a message carrying a newline"
node "$r" --run "$tmp/after.json" --out "$tmp/esc" --format md >/dev/null || fail "$r failed on the comparison run"
esc="$tmp/esc/informe-2026-09-21.md"
if grep -qx 'second line pretending to be a bullet' "$esc"; then
  fail "$esc lets a newline in a message break out of its list item"
fi
if grep -Fq '`UX-002:weird`resource`' "$esc"; then
  fail "$esc lets a backtick close the code span around a finding identity"
fi

# A run that measured nothing is not a run that found nothing. Without the distinction the
# next report calls every finding new, against a baseline that never looked.
cat > "$tmp/nothing.json" <<'JSON'
{"site":"fixture","date":"2026-09-22","findings":[],"unmeasured":[{"check":"UX-006","reason":"no browser"}]}
JSON
cat > "$tmp/something.json" <<'JSON'
{"site":"fixture","date":"2026-09-23","findings":[
  {"check":"UX-006","resource":"page:/","severity":"WARNING","ownership":"code","message":"142 characters on desktop"}
]}
JSON
node "$r" --run "$tmp/nothing.json" --out "$tmp/base" --format md >/dev/null \
  || fail "$r refused a run that only carried unmeasured checks"
node "$r" --run "$tmp/something.json" --out "$tmp/base" --format md >/dev/null || fail "$r failed on the follow-up run"
grep -Fq 'unmeasured' "$tmp/base/informe-2026-09-23.md" \
  || fail "the report does not say the previous run measured nothing -- its findings all read as newly broken"

# ---------------------------------------------------------------------------
# 4. The refusals
# ---------------------------------------------------------------------------
cat > "$tmp/unowned.json" <<'JSON'
{"site":"fixture","date":"2026-09-16","findings":[
  {"check":"SEC-001","severity":"CRITICAL","message":"No owner on this one"}
]}
JSON
set +e
out=$(node "$r" --run "$tmp/unowned.json" --out "$tmp/out2" --format md 2>&1)
code=$?
set -e
[ "$code" -eq 1 ] || fail "$r accepted a finding with no ownership (exit $code) -- the plan would ship a blank column"
case "$out" in *ownership*) : ;; *) fail "$r refused the unowned finding without naming ownership" ;; esac
if [ -e "$tmp/out2/informe-2026-09-16.md" ]; then
  fail "$r wrote a report it had already refused"
fi

# A truthy non-string check id passed validation, reached the plan comparator and threw on
# .localeCompare -- turning invalid input (exit 1, names the finding) into a crash (exit 3,
# names a line of the renderer).
cat > "$tmp/numeric.json" <<'JSON'
{"site":"fixture","date":"2026-09-19","findings":[
  {"check":404,"severity":"WARNING","ownership":"code","message":"a check id that is a number"},
  {"check":"UX-001","severity":"WARNING","ownership":"code","message":"and one that is not"}
]}
JSON
set +e
out=$(node "$r" --run "$tmp/numeric.json" --out "$tmp/out5" --format md 2>&1)
code=$?
set -e
[ "$code" -eq 1 ] || fail "a non-string check id exited $code instead of 1 -- it crashed rather than being refused"
case "$out" in *non-string*) : ;; *) fail "$r refused the numeric check id without saying why" ;; esac

# An unmeasured entry with no check renders a literal "undefined" in the section the client
# reads, in the part of the report whose whole job is to be trustworthy.
cat > "$tmp/nocheck.json" <<'JSON'
{"site":"fixture","date":"2026-09-19","findings":[
  {"check":"UX-001","severity":"WARNING","ownership":"code","message":"fine"}
],"unmeasured":[{"reason":"no check id on this one"}]}
JSON
set +e
node "$r" --run "$tmp/nocheck.json" --out "$tmp/out6" --format md >/dev/null 2>&1
code=$?
set -e
[ "$code" -eq 1 ] || fail "an unmeasured entry with no check id exited $code instead of 1 -- it would print \"undefined\" to the client"

# The run file is an argument, and its date becomes three file names under --out. --date
# was validated and this was not, so `x/../../evil` escaped the output directory: path.join
# only cancels a `..` that lands on its own segment, and one slash supplies exactly that.
cat > "$tmp/traversal.json" <<'JSON'
{"site":"fixture","date":"x/../../evil","findings":[
  {"check":"UX-001","severity":"WARNING","ownership":"code","message":"fine"}
]}
JSON
mkdir -p "$tmp/sandbox/out"
set +e
node "$r" --run "$tmp/traversal.json" --out "$tmp/sandbox/out" --format md >/dev/null 2>&1
code=$?
set -e
[ "$code" -eq 1 ] || fail "a run file whose date contains a path separator exited $code instead of 1"
if [ -n "$(find "$tmp/sandbox" -name 'evil*' 2>/dev/null)" ]; then
  fail "$r wrote outside its --out directory"
fi

cat > "$tmp/empty.json" <<'JSON'
{"site":"fixture","date":"2026-09-17","findings":[]}
JSON
set +e
node "$r" --run "$tmp/empty.json" --out "$tmp/out3" --format md >/dev/null 2>&1
code=$?
set -e
[ "$code" -eq 2 ] \
  || fail "a run with no findings exited $code -- a clean skip is 2, and 0 would claim a report exists"

set +e
node "$r" --run "$tmp/does-not-exist.json" --out "$tmp/out4" >/dev/null 2>&1
code=$?
set -e
[ "$code" -eq 1 ] || fail "a missing run file exited $code instead of 1"

echo "PASS: the audit writes a dated deliverable, every finding names who applies it, and the HTML stands alone"
