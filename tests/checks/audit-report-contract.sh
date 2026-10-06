#!/usr/bin/env bash
# wp-audit-standards said "All audit agents MUST output findings in this format" and showed an
# `issues` array with lowercase severities, `code` and `fix_method`. No agent emitted that, and
# neither did the renderer read it: bin/audit-report.mjs wants a `findings` array whose
# entries carry `check`, an uppercase `severity`, `ownership` and `message`, and it refuses
# anything else with exit 1. Each agent had drifted into its own shape meanwhile (`code` beside
# `check` meaning the check's NAME in one, `title`/`details`/`autofix` in another, severity
# `ERROR` in a third), and the skill had no `status` field for the N/A and UNMEASURED answers
# its own body demands. So the run file every report is built from had to be re-mapped by hand
# from six vocabularies, which is where a check id and a check name get swapped.
#
# Pinned here: the skill states the contract the renderer enforces, every agent's report
# example uses those field names and values, and the dispatch prompt names the prefixes the
# catalogs actually use (it said `BP-NNN`, which no agent emits, and left out `UX-NNN`).
# Also the WCAG large-text threshold the same skill got wrong (18px is not 18pt).
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

std=skills/wp-audit-standards/SKILL.md
cmd=commands/wp-audit.md
rep=bin/audit-report.mjs
for f in "$std" "$cmd" "$rep"; do [ -r "$f" ] || fail "$f is missing or unreadable"; done

# --- the skill states what the renderer enforces -------------------------------------------
# The renderer's own required fields and enums, read from its source so a change there is a
# change here.
grep -Fq 'has no "findings" array' "$rep" \
  || fail "$rep no longer requires a findings array -- re-read it before trusting this check"
for field in check severity ownership message; do
  grep -Fq "has no \"$field\"" "$rep" \
    || fail "$rep no longer refuses a finding without $field -- re-read it before trusting this check"
  grep -Fq "| \`$field\` |" "$std" || fail "$std does not define the \`$field\` field the renderer requires"
done
sev=$(sed -n 's/^const SEVERITY_ORDER = { *\(.*\) *};$/\1/p' "$rep" | grep -oE '[A-Z]+' | tr '\n' ' ')
[ "$sev" = "CRITICAL WARNING INFO " ] || fail "$rep severities changed to '$sev' -- update the contract"
grep -Fq '| `severity` | on `FAIL` | `CRITICAL`, `WARNING` or `INFO`, uppercase |' "$std" \
  || fail "$std does not give the renderer's three uppercase severities"
own=$(sed -n "s/^const OWNERSHIP = \[\(.*\)\];$/\1/p" "$rep" | tr -d "' ")
[ "$own" = "code,setting,content,manual" ] || fail "$rep ownership values changed to '$own'"
grep -Fq '| `ownership` | on `FAIL` | `code`, `setting`, `content` or `manual`' "$std" \
  || fail "$std does not give the four ownership values"
grep -Fq '| `status` | always | `PASS`, `FAIL`, `UNMEASURED` or `N/A` |' "$std" \
  || fail "$std has no status field, so N/A and UNMEASURED have nowhere to go"
grep -Fq '`checks_executed`' "$std" || fail "$std does not require checks_executed"
grep -Fq 'a GEO `ERROR` is written `CRITICAL`' "$std" \
  || fail "$std does not map GEO's ERROR grade onto a severity the renderer accepts"
grep -Fq 'a GEO finding graded `ERROR` is written `CRITICAL`' "$cmd" \
  || fail "$cmd Step 8.5 does not map GEO's ERROR grade when it writes the run file"

# The old schema, gone.
grep -Fq '"issues": [' "$std" && fail "$std still shows the issues array no renderer reads"
grep -Fq '"severity": "critical' "$std" && fail "$std still shows lowercase severities"
grep -Fq 'fix_method' "$std" && fail "$std still names fix_method"
grep -Fq 'MUST output findings in this format' "$std" && fail "$std still claims a format no agent emits"

# --- every agent's report example uses those names -----------------------------------------
node - agents/wp-audit-a11y.md agents/wp-audit-geo.md agents/wp-audit-performance.md \
  agents/wp-audit-security.md agents/wp-audit-seo.md <<'JS' || exit 1
const fs = require('fs');
const SEV = ['CRITICAL', 'WARNING', 'INFO'];
const OWN = ['code', 'setting', 'content', 'manual'];
const STATUS = ['PASS', 'FAIL', 'UNMEASURED', 'N/A'];
let bad = 0;
const err = (m) => { console.log(`FAIL: ${m}`); bad = 1; };
for (const file of process.argv.slice(2)) {
  const text = fs.readFileSync(file, 'utf8');
  const start = text.search(/^## Step \d+: Output Report/m);
  if (start < 0) { err(`${file} has no "Output Report" step`); continue; }
  const rest = text.slice(start + 1);
  const end = rest.search(/^## /m);
  const section = end < 0 ? rest : rest.slice(0, end);
  const blocks = [...section.matchAll(/```json\n([\s\S]*?)```/g)].map((m) => m[1]);
  if (!blocks.length) { err(`${file} Output Report has no JSON example`); continue; }
  let seen = 0;
  for (const block of blocks) {
    let doc;
    try { doc = JSON.parse(block); } catch (e) { err(`${file}: report example is not valid JSON (${e.message})`); continue; }
    const findings = Array.isArray(doc.findings) ? doc.findings : (doc.severity || doc.check || doc.code ? [doc] : []);
    if (Array.isArray(doc.findings) && !Array.isArray(doc.checks_executed)) {
      err(`${file}: report example has no checks_executed`);
    }
    for (const f of findings) {
      seen += 1;
      const id = f.check || f.code || '?';
      if ('code' in f) err(`${file} ${id}: names the check id "code" -- the contract and the renderer call it "check"`);
      for (const old of ['title', 'detail', 'details', 'description', 'auto_fix', 'autofix', 'fix_snippet', 'fix_method']) {
        if (old in f) err(`${file} ${id}: carries "${old}", which the contract does not define`);
      }
      if (typeof f.check !== 'string' || !/^[A-Z0-9]+(-[A-Z0-9]+)+(@[1-9][0-9]*)?$/.test(f.check)) err(`${file} ${id}: finding has no valid check id`);
      if (!STATUS.includes(f.status)) err(`${file} ${id}: status ${JSON.stringify(f.status)} is not one of ${STATUS.join(', ')}`);
      if (f.status === 'FAIL') {
        if (!SEV.includes(f.severity)) err(`${file} ${id}: severity ${JSON.stringify(f.severity)} is not one the renderer accepts`);
        if (!OWN.includes(f.ownership)) err(`${file} ${id}: ownership ${JSON.stringify(f.ownership)} is not one of ${OWN.join(', ')}`);
        if (!f.message) err(`${file} ${id}: a FAIL with no message`);
        if (!f.resource) err(`${file} ${id}: a FAIL with no resource, so the ledger cannot key it`);
      }
    }
  }
  if (!seen) err(`${file}: report example carries no finding to check`);
}
process.exit(bad);
JS

# The practices agent describes its report in prose rather than JSON.
p=agents/wp-audit-practices.md
grep -Fq 'each with `check`, `status`, `severity`, `ownership`, `resource`, `message`' "$p" \
  || fail "$p does not describe its findings with the contract's field names"
grep -Fq 'each with `code`, `severity`' "$p" && fail "$p still names the check id \`code\`"

# --- the dispatch prompt names the prefixes the catalogs use -------------------------------
dispatch=$(awk '/^## Step 6:/{on=1} /^## Step 6.5:/{on=0} on' "$cmd")
grep -Fq 'BP-NNN' <<<"$dispatch" && fail "$cmd Step 6 still names BP-NNN, which no agent emits (practices is WP-NNN)"
grep -Fq 'WP-NNN' <<<"$dispatch" || fail "$cmd Step 6 does not name the practices prefix WP-NNN"
grep -Fq 'UX-NNN' <<<"$dispatch" || fail "$cmd Step 6 does not name the usability prefix UX-NNN"
grep -Eq '^\| WP-[0-9]{3} \|' agents/wp-audit-practices.md || fail "the practices catalog no longer uses WP-NNN"

# --- WCAG 1.4.3 large text is 18pt (24px) or 14pt bold (about 18.66px) ---------------------
grep -Fq 'Large text contrast (≥24px, or ≥18.66px bold' "$std" \
  || fail "$std does not state WCAG's large-text threshold in CSS pixels"
grep -Fq '>=18px or >=14px bold' "$std" \
  && fail "$std still reads 18pt as 18px, holding 18-23px text to 3:1 when it needs 4.5:1"

echo "PASS: the report contract matches the renderer, every agent's example follows it, and the thresholds are WCAG's"
