#!/usr/bin/env bash
# The usability catalog's Owner column is a second copy of the browser suite's own
# classification (aplicacion() in templates/audit-suite/lib/plan.js), and it had drifted on 7
# of 36 rows -- UX-015 and UX-038, which the suite emits, among them. With --suite the measured
# row wins the merge and carries the suite's owner, so the same broken external link was `code`
# when the suite ran and `content` when it did not: the drift scripts/to-run.js names as the
# reason it translates the suite's split instead of re-deriving it.
#
# The suite is vendored and never edited here, so for every criterion it actually emits the
# catalog follows it. A row the suite never emits keeps the catalog's owner: plan.js classifies
# some of those too, but nothing the suite runs ever produces them.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

k=skills/wp-audit-ux-standards/SKILL.md
plan=templates/audit-suite/lib/plan.js
bridge=templates/audit-suite/scripts/to-run.js
for f in "$k" "$plan" "$bridge"; do [ -r "$f" ] || fail "$f is missing or unreadable"; done

flat=$(tr '\n' ' ' < "$k" | sed 's/  */ /g')
case "$flat" in
  *"the owner here is the suite's (\`aplicacion()\` in \`templates/audit-suite/lib/plan.js\`)"*) ;;
  *) fail "$k does not say that the suite's owner governs the criteria the suite emits" ;;
esac

# The bridge's word mapping is what turns the suite's Spanish labels into owners.
for pair in "Codigo: 'code'" "Ajuste: 'setting'" "Contenido: 'content'" "Manual: 'manual'"; do
  grep -Fq "$pair" "$bridge" || fail "$bridge no longer maps $pair -- update this check's mapping"
done

node - "$k" <<'JS'
const fs = require('fs');
const path = require('path');
const { aplicacion } = require(path.resolve('templates/audit-suite/lib/plan.js'));
const OWN = { Codigo: 'code', Ajuste: 'setting', Contenido: 'content', Manual: 'manual' };
const fail = (m) => { console.log(`FAIL: ${m}`); process.exit(1); };

// What the suite emits: every R('<criterion>', ...) result in its helpers.
const lib = 'templates/audit-suite/lib';
const emitted = new Set();
for (const f of fs.readdirSync(lib)) {
  if (!f.endsWith('.js') || f.includes('selfcheck')) continue;
  for (const m of fs.readFileSync(path.join(lib, f), 'utf8').matchAll(/\bR\(\s*['"](\d+)['"]/g)) emitted.add(m[1]);
}
if (emitted.size < 10) fail(`found only ${emitted.size} criteria the suite emits -- the R(...) pattern no longer matches its helpers`);

const rows = fs.readFileSync(process.argv[2], 'utf8').split('\n')
  .map((l) => l.match(/^\| UX-(\d{3}) \|.*\| *(code|setting|content|manual) *\|\s*$/))
  .filter(Boolean);
if (rows.length < 30) fail(`read only ${rows.length} catalog rows with an owner`);

let compared = 0;
const drift = [];
for (const [, id, owner] of rows) {
  const c = String(Number(id));
  if (!emitted.has(c)) continue;
  compared += 1;
  const suite = OWN[aplicacion({ c })];
  if (!suite) fail(`plan.js classifies criterion ${c} as ${aplicacion({ c })}, which maps to no owner`);
  if (suite !== owner) drift.push(`UX-${id}: catalog says ${owner}, the suite emits it as ${suite}`);
}
if (compared < 10) fail(`only ${compared} catalog rows are criteria the suite emits -- the comparison proves too little`);
if (drift.length) fail(`the catalog's owner disagrees with the suite's for criteria the suite emits:\n  ${drift.join('\n  ')}`);
JS

echo "PASS: every usability criterion the suite emits carries the suite's owner"
