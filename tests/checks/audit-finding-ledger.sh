#!/usr/bin/env bash
# Findings were three integers: issues_found, issues_fixed, carried_over. Three integers
# cannot answer the question every follow-up audit asks -- is this the same problem as last
# time? Fix one issue and find a new one and the count is unchanged while the contents
# changed completely, so Step 2.5e could report "25 carried over" and never say which 25.
# I09's own completion check, "fixing one issue resolves that issue without clearing
# others", is unreachable with counters.
#
# The ledger gives a finding an identity. What this pins is the parts that would quietly
# turn it back into a counter, or worse, into a record that reports problems as fixed.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

c=commands/wp-audit.md
m=bin/lib/manifest.mjs
for f in "$c" "$m"; do [ -f "$f" ] || fail "$f is missing"; done
need() { grep -Fq -- "$1" "$c" || fail "$c $2"; }

need 'Step 7.5: Reconcile against the finding ledger' 'has no finding ledger step'
need 'is its check and its resource' 'does not define what identifies a finding'

# The identity has to reuse the evidence Step 6.9 already demands. A ledger that collects
# its own evidence is a second contract to keep true, and the two would drift.
need 'No new evidence is collected for this' \
  'does not build the identity on the evidence Step 6.9 already requires'

# file:line as an identity churns: an import added above a finding moves it, and every
# finding in that file reports resolved-and-new.
need 'most stable thing the evidence names' 'does not say which part of the evidence to identify a finding by'
# Needles below are kept within one line and free of apostrophes: grep -F matches within a
# line, and the prose wraps.
need 'every finding as resolved-and-new after any edit' \
  'does not warn that a line-number identity churns on unrelated edits'

# resolved is the status that can lie. A check that did not run must never produce it,
# or auditing with less access than last time reports the site cleaning itself up.
need 'this run measured the same check and did not find it' \
  'does not require a measurement before a finding is called resolved'
need 'produces `unmeasured`, never `resolved`' \
  'lets a check that did not run mark its findings resolved -- a Tier 1 run would report every Tier 2 finding fixed'
need 'a report would show a site cleaning itself' \
  'does not say what a wrong resolved costs -- without it the precondition reads as pedantry'

# accepted is a human decision in both directions.
need 'set by a human and by nothing else' 'lets the audit promote its own finding to accepted'
need 'never demotes one' 'lets the audit re-raise an accepted finding'

# Absence is not success. A first run, a deleted ledger and an older plugin version are
# indistinguishable, and reporting any of them as "everything resolved" is a false all-clear.
need 'means "no history", never "nothing ever failed"' \
  'does not say what an absent ledger means -- a first run would otherwise read as a clean project'

# A resolved entry is kept, or a recurring defect looks new every time it returns.
need 'is kept, not deleted' 'deletes resolved entries, so a recurrence reports as new'
need 'last run that still **found** it' \
  'does not define last_seen on a resolved entry, so a timestamp that moves every clean run cannot date the fix'

# The separation from the manifest, and the reason, which is the part that gets "tidied".
need '.wp-audit-findings.json' 'does not give the ledger its own file'
need 'Putting that in the manifest makes' 'does not say what inlining the ledger costs every other command'
need 'stays a pointer' 'does not forbid the manifest pointer growing into the ledger'

# The counters survive as derived values; something still has to print a number.
need 'derived' 'does not say the manifest counts are now derived from the ledger'

# The validator owns the manifest, so the pointer goes through it -- including the refusal
# to inline, which is the shape the prose argues against.
grep -Fq 'findings_ledger' "$m" || fail "$m does not validate audit.findings_ledger"
grep -Fq 'it points at the ledger, it does not contain it' "$m" \
  || fail "$m does not refuse an inlined ledger"
grep -Fq 'must not climb out of it' "$m" \
  || fail "$m does not constrain the ledger path to the project"

echo "PASS: findings have identities, resolved requires a measurement, and the ledger stays out of the manifest"
