#!/usr/bin/env bash
# A second /wp-audit asked report-only, suite and production URL all over again and the
# report never said it was a re-audit. Pins the contract: detection, one reuse prompt,
# safe reuse, scoped mode, persistence, and the manifest validation of audit.last_answers.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

. tests/checks/lib/expand-command.sh; expand_command commands/wp-audit.md
c=$EXPANDED
need() { grep -Fq -- "$1" "$c" || fail "$2"; }

need '## Step 1.5: Recognize a re-audit' 'Step 1.5 is gone'
need 'Re-audit of <YYYY-MM-DD>' 'no "Re-audit of <date>" line'
need 'ask **one** `AskUserQuestion`' 'reuse is not a single question'
need 'Same, but re-measure only what changed (scoped mode)' 'no scoped option'
need 'Reuse is never silent' 'reuse safety rules are gone'
need 'there is no "reuse by default" path' 'silent default reuse is not ruled out'
need 'older than 30 days' 'no staleness rule'
need 'do not offer A or B' 'a stale production URL can be reused'
need 'An explicit flag always wins over a' 'flags no longer win over stored answers'
need 'Not re-measured' 'scoped mode lost the not-re-measured rule'
need 'git log --since=<last_run> --name-only' 'scoped mode lost its changed-file source'
need 'compared against <baseline source>' 'the report does not state its baseline'
need '`last_answers` records what the operator chose' 'Step 10 does not persist last_answers'

# Manifest validation: valid and invalid cases.
cat > ./.probe-reaudit.mjs <<'JS'
import { validateManifest } from './bin/lib/manifest.mjs';
const base = { manifest_version: 3, wp_cli: { wrapper: 'wp' }, wordpress: { url: 'http://x.test' } };
const good = { mode: 'report-only', suite: true, production_url: 'https://example.com', answered: '2026-10-01T10:00:00Z' };
const probe = (a) => validateManifest({ ...base, audit: { last_answers: a } }).filter((p) => p.includes('last_answers'));
const cases = {
  valid: [good, 0],
  valid_clone_only: [{ ...good, production_url: null, clone_only: true }, 0],
  bad_mode: [{ ...good, mode: 'yolo' }, 1],
  bad_suite: [{ ...good, suite: 'yes' }, 1],
  bad_url: [{ ...good, production_url: 'example.com' }, 1],
  clone_and_url: [{ ...good, clone_only: true }, 1],
  bad_date: [{ ...good, answered: 'yesterday' }, 1],
  lenient_date: [{ ...good, answered: '2026' }, 1],
  unknown_key: [{ ...good, password: 'x' }, 1],
  not_object: ['report-only', 1],
};
let bad = 0;
for (const [name, [a, want]] of Object.entries(cases)) {
  const got = probe(a).length > 0 ? 1 : 0;
  if (got !== want) { console.log(`FAIL: last_answers ${name}: expected ${want ? 'rejected' : 'accepted'}`); bad++; }
}
process.exit(bad ? 1 : 0);
JS
trap 'rm -f ./.probe-reaudit.mjs' EXIT
node ./.probe-reaudit.mjs || fail "manifest validation of audit.last_answers"
echo PASS
