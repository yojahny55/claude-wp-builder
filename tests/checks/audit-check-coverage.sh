#!/usr/bin/env bash
# Step 2.5d used to answer only "has this category ever run here". A category keeps
# answering yes forever while checks are added to it, so a project could carry a green
# coverage line for checks nobody had ever run on it -- CLAUDE.md listed that as a known
# ceiling. The per-check diff closes it, and this pins the parts of it that can rot.
#
# The rot that matters is the catalog pointer. The command tells the agent to read each
# category's check ids out of that category's own agent file rather than from a list kept
# somewhere else -- because a stored list is a second copy, and a stale second copy would
# report green coverage for checks nobody ran, which is precisely the defect the diff
# exists to prevent. So the pairing is asserted both ways: the command must name it, and
# the agent it names must actually hold ids of that prefix.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

c=commands/wp-audit.md
m=bin/lib/manifest.mjs
[ -f "$c" ] || fail "$c is missing"
[ -f "$m" ] || fail "$m is missing"

# The record itself, and the two properties that make it readable back.
grep -Fq 'audit.checks_run' "$c" || fail "$c never names audit.checks_run"
grep -Fq 'checks_run` is cumulative' "$c" \
  || fail "$c does not state that checks_run is cumulative -- overwriting it each run erases the history 2.5d reads back"
grep -Fq 'including the ones that passed' "$c" \
  || fail "$c does not say a passing check is recorded; a pass that is not recorded is indistinguishable from never-run, which is the whole point"

# A check reported UNMEASURED did not execute. Recording it would tell the next run that a
# check it still has not measured has been measured -- a false green that survives forever,
# because nothing later re-opens it.
grep -Fq 'UNMEASURED` did not execute and is not recorded' "$c" \
  || fail "$c does not exclude UNMEASURED checks from checks_run"

# A project audited before this record existed has no per-check history. Reporting all of
# its checks as never-measured would be true and useless, and it would bury the real signal
# on every legacy project the first time it is re-audited.
grep -Fq 'absent `audit.checks_run` is not "nothing has run"' "$c" \
  || fail "$c does not handle a project with no per-check history"

# The severity split: a never-run category has been examined by nothing, a category missing
# two checks out of forty has been examined and not completely. Collapsing them would either
# block on a warning or downgrade the blocking case.
grep -Fq 'This is a warning, not a block' "$c" \
  || fail "$c does not distinguish a partially-covered category from a never-run one"

# Both lists name the same six categories, and they live in different files: the module
# validates them, the command's prose enumerates them. Drift between two lists that must
# agree is the defect this whole feature is about.
cats=$(node --input-type=module -e \
  'import { AUDIT_CATEGORIES } from "./bin/lib/manifest.mjs"; process.stdout.write(AUDIT_CATEGORIES.join("\n"));')
[ -n "$cats" ] || fail "$m does not export AUDIT_CATEGORIES"
while IFS= read -r cat; do
  grep -Fq "\"$cat\"" "$c" || fail "$c never names the \"$cat\" category that $m validates"
done <<<"$cats"

# Every catalog pointer resolves. A prefix the command sends the agent to read out of a file
# that holds none of it is an instruction that silently yields an empty catalog -- and an
# empty catalog subtracts to nothing, so the coverage line reads green.
while IFS=' ' read -r prefix agent; do
  [ -n "$prefix" ] || continue
  grep -Fq "$agent" "$c" || fail "$c does not point $prefix-* at $agent"
  [ -f "$agent" ] || fail "$c points $prefix-* at $agent, which does not exist"
  # -q, not -c: the assertion is "the catalog is not empty", and a count invites a reader to
  # think it means something. (`grep -co` was worse than useless -- -c suppresses -o, so it
  # counted matching LINES: 2 for a file holding 3 ids on 2 lines.)
  grep -qE "\b${prefix}-[A-Z]?[0-9]+\b" "$agent" \
    || fail "$agent holds no ${prefix}-* check IDs, so the catalog it is named as would be empty"
done <<'PAIRS'
SEC agents/wp-audit-security.md
WP agents/wp-audit-practices.md
SEO agents/wp-audit-seo.md
A11Y agents/wp-audit-a11y.md
PERF agents/wp-audit-performance.md
GEO agents/wp-audit-geo.md
PAIRS

echo "PASS: check-level coverage is contracted, and all six catalog pointers resolve"
