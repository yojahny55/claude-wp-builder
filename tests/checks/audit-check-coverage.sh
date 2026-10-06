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

# Both lists name the same categories, and they live in different files: the module
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
UX skills/wp-audit-ux-standards/SKILL.md
PAIRS

# Usability keeps its catalog in its skill's table, not in its agent. The command used to
# point UX-* at agents/wp-audit-ux.md, which names 8 of the 36 criteria -- so the other 28
# could never be reported as never measured, and the coverage line read green for them. A
# bare id grep of the skill is wrong too: its prose names ids that are not criteria. The
# catalog is the table rows, and every table row has to be one the documented pattern reads.
ux=skills/wp-audit-ux-standards/SKILL.md
flatc=$(tr '\n' ' ' < "$c" | sed 's/  */ /g')
case "$flatc" in
  *'`UX-*` in `agents/wp-audit-ux.md`'*) fail "$c still reads the UX catalog from the agent, which names a fraction of it" ;;
esac
case "$flatc" in
  *'`UX-*` is every **table row** of `skills/wp-audit-ux-standards/SKILL.md` — a line starting `| UX-NNN |`'*) ;;
  *) fail "$c does not read the UX catalog from the skill's table rows" ;;
esac
case "$flatc" in
  *'for usability the table rows of its skill'*) ;;
  *) fail "$c Step 6.8 computes usability coverage against something other than the skill's table rows" ;;
esac
all_rows=$(grep -cE '^\|[[:space:]]*UX-[0-9]' "$ux" || true)
pat_rows=$(grep -cE '^\| UX-[0-9]{3} \|' "$ux" || true)
[ "$all_rows" -gt 0 ] || fail "$ux has no UX table rows"
[ "$all_rows" -eq "$pat_rows" ] \
  || fail "$ux has $all_rows UX table rows but only $pat_rows match '| UX-NNN |', so the catalog read would drop some"
dupes=$(grep -oE '^\| UX-[0-9]{3} \|' "$ux" | sort | uniq -d)
[ -z "$dupes" ] || fail "$ux tabulates the same criterion twice: $dupes"
for id in $(grep -oE '\bUX-[0-9]{3}\b' agents/wp-audit-ux.md | sort -u); do
  grep -qE "^\| $id \|" "$ux" || fail "agents/wp-audit-ux.md reports $id, which is not a row of the catalog in $ux"
done

# --- check revisions ----------------------------------------------------------------------
# checks_run recorded IDs, and an ID is an address rather than a version: a project holding
# SEC-036 stayed "covered" after SEC-036 was rewritten to look for something else, so its
# coverage read green for a rule it had never been measured against. That is this diff's own
# failure mode, one level down.
grep -Fq 'A check whose rule changed is a check this project has not run' "$c" \
  || fail "$c does not treat a revised check as unmeasured coverage"
grep -Fq 'SEC-036@2' "$c" || fail "$c does not show the revision syntax"
grep -Fq 'revision 1, which is what every existing entry' "$c" \
  || fail "$c does not say what a bare ID means -- every checks_run entry written so far is one, and they must stay valid"
grep -Fq 'reworded finding message is not a bump' "$c" \
  || fail "$c does not say when to bump a revision, so the revision would mean whatever each author decided"
grep -Fq 'revision it ran at' "$c" \
  || fail "$c does not require the revision to be written back into checks_run -- recording the bare ID after running a revised check is what makes the record lie"

# The validator has to accept the suffix, or recording an honest revision makes the manifest
# invalid and the next command refuses to run.
grep -Fq '@[1-9]' "$m" \
  || fail "$m does not accept a revision suffix on a check ID -- writing SEC-036@2 would fail validation"

echo "PASS: check-level coverage is contracted, and every catalog pointer resolves"
