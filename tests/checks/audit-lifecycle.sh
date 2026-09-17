#!/usr/bin/env bash
set -euo pipefail

# The audit lifecycle: what a project carries between runs, and what a run is allowed to
# conclude from an absence.
#
# Every rule pinned here exists because a site built with this plugin shipped with a defect
# that a passing audit never mentioned. The common shape is an absence reported as a
# success — a category that never ran, a manifest never re-measured, a scan skipped for a
# reason that had a fix. None of them is detectable by reading the theme, which is what the
# audit used to read.

fail() { echo "FAIL: $1"; exit 1; }

audit=commands/wp-audit.md
yolo=commands/wp-yolo.md
geo=agents/wp-audit-geo.md
seo=agents/wp-audit-seo.md
sec=agents/wp-audit-security.md
prac=agents/wp-audit-practices.md
scan=bin/geo-scan.sh

for f in "$audit" "$yolo" "$geo" "$seo" "$sec" "$prac" "$scan"; do
  [ -f "$f" ] || fail "$f is missing"
done

# --- Reconciliation step exists and runs before tier detection -----------------
grep -q '^## Step 2.5: Reconcile the Manifest' "$audit" \
  || fail "$audit must reconcile the manifest before it trusts it"
awk '/^## Step 2.5: Reconcile the Manifest/ { r = NR } /^## Step 3: Detect Environment/ { t = NR }
     END { exit !(r > 0 && t > r) }' "$audit" \
  || fail "$audit: reconciliation must come before tier detection — it can turn Tier 3 back on"

# --- Schema version is the current one, and the absent bucket is widened ------
# /wp-create writes manifest_version 3 as of the credential-contract change (Task 6). A
# project this same /wp-create just scaffolded must not be treated as older than the
# plugin understands, so 2.5a's absent bucket has to cover every version before 3, not
# just the literal absence.
grep -Fq 'Read `manifest_version`. The current version is `3`.' "$audit" \
  || fail "$audit's 2.5a must state manifest_version 3 as the current version"
grep -Fq '| absent or `< 3` |' "$audit" \
  || fail "$audit's 2.5a must widen the absent bucket to \`absent or < 3\`, not just absent"

# --- categories_run is read back, not only written ----------------------------
# The original defect: a single occurrence, a write. Nothing ever asked which categories had
# never run, so a project could sit forever with a whole category unexecuted.
grep -q 'NEVER RUN' "$audit" || fail "$audit must report a never-run category"
grep -q 'cumulative' "$audit" \
  || fail "$audit: categories_run must accumulate — overwriting it erases the coverage history"
grep -q 'manifest_version' "$audit" || fail "$audit must version the manifest"

# --- a fallback must not be reported as a decision ----------------------------
grep -qF 'A fallback is a guess, and this step reports it as one' "$audit" \
  || fail "$audit must report a missing recorded decision as unknown, not default it silently"

# --- measured, not trusted ----------------------------------------------------
grep -qF 'Measure, do not trust' "$audit" \
  || fail "$audit must re-measure plugins/PHP/web server instead of trusting the manifest"
grep -q 'RE-PROBED' "$audit" \
  || fail "$audit must re-probe Tier 3 rather than trusting a recorded capability"
grep -q 'STALE' "$audit" || fail "$audit must warn on a stale audit record"
grep -q 'carry-over' "$audit" || fail "$audit must re-open findings that were never fixed"

# --- the four statuses stay distinct ------------------------------------------
# N/A and UNMEASURED were one status. Merging them hides "applies but nothing ran it"
# behind "does not apply here", and only the first one needs action.
grep -q 'UNMEASURED' "$audit" || fail "$audit must distinguish UNMEASURED from N/A"
grep -qF 'never fold `UNMEASURED` into the passing total' "$audit" \
  || fail "$audit must keep UNMEASURED out of the passing count"
grep -q 'UNMEASURED' "$geo" || fail "$geo report schema must carry UNMEASURED"

# The vocabulary has to hold in the agents that PRODUCE the statuses, not only in the
# command that prints them. An agent still writing SKIPPED puts the run back where it was:
# a check that applies, that nothing ran, counted as though nothing were wrong.
grep -q 'SKIPPED' "$sec" && fail "$sec still reports SKIPPED — use UNMEASURED"
grep -q 'note it as skipped' "$prac" && fail "$prac still reports a Tier 2 skip as benign"
grep -q 'UNMEASURED' "$sec" || fail "$sec must report an unrunnable check UNMEASURED"
grep -q 'UNMEASURED' "$prac" || fail "$prac must report an unrunnable Tier 2 check UNMEASURED"

# --- a dev host is a configuration problem, not an absent report --------------
grep -q -- '--host' "$audit" || fail "$audit must accept --host for a project whose manifest holds a dev URL"
grep -q 'NOT PUBLIC' "$scan" || fail "$scan must detect a non-public host itself"
grep -q 'exit 3' "$scan" || fail "$scan must exit 3 for a host it cannot reach publicly"
grep -q 'exit 3' "$yolo" || fail "$yolo must handle exit 3 distinctly from a skip"
# The gate must actually fire. A prose pin alone would pass on a script whose case
# statement never matches, so run it: every shape of non-public host must exit exactly 3.
# `|| rc=$?` is required — under `set -e` a bare non-zero call aborts before the test.
for h in localhost site.local example.test 127.0.0.1 192.168.1.9 10.0.0.4 172.20.1.1 intranet; do
  rc=0; bash "$scan" "$h" >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 3 ] || fail "$scan: non-public host $h exited $rc, expected 3"
done
# Control: a registrable public domain must NOT be refused by the gate. It may exit 0 or 2
# depending on whether a report exists and whether this machine has a network, but a 3 would
# mean the gate is rejecting hosts it should pass through.
rc=0; bash "$scan" example.com >/dev/null 2>&1 || rc=$?
[ "$rc" -ne 3 ] || fail "$scan refused the public host example.com as non-public"

# --- ownership of the surfaces that are not the theme -------------------------
grep -qF 'plugin configuration and DB options' "$audit" \
  || fail "$audit must name an owner for plugin config and DB options"
grep -q 'serving layer' "$audit" || fail "$audit must name an owner for the serving layer"

# --- the checks that were missing entirely ------------------------------------
grep -qE '^\| GEO-A26 \|' "$geo" || fail "$geo must tabulate GEO-A26 (root file precedence)"
grep -qE '^\| GEO-A27 \|' "$geo" || fail "$geo must tabulate GEO-A27 (canonical path served)"
grep -qE '^\| GEO-A28 \|' "$geo" || fail "$geo must tabulate GEO-A28 (surfaces agree)"
grep -qF 'wins over the theme' "$geo" \
  || fail "$geo GEO-A26 must state that a physical root file beats the theme rewrite"
grep -qF 'existence is not agreement' "$geo" \
  || fail "$geo GEO-A28 must check agreement, not just that a surface exists"

grep -qE '^\| SEO-053 \|' "$seo" || fail "$seo must tabulate SEO-053 (cannibalization)"
grep -qF "post_type IN ('post','page')" "$seo" \
  || fail "$seo SEO-023 must cover posts as well as pages"
grep -q 'NO DESC' "$seo" || fail "$seo SEO-023 must name the URLs, not report a count"

grep -qE '^\| WP-046 \|' "$prac" || fail "$prac must tabulate WP-046 (unquoted ABSPATH)"
grep -qE '^\| WP-047 \|' "$prac" || fail "$prac must tabulate WP-047 (template classes absent from CSS)"
grep -qF 'php -l` passes it' "$prac" \
  || fail "$prac must say a lint cannot catch the unquoted-constant fatal"
# WP-016's own pattern used to match the broken form as happily as the correct one.
grep -qF 'the **quoted** form only' "$prac" \
  || fail "$prac WP-016 must require the quoted form"

grep -qE '^\| SEC-036 \|' "$sec" || fail "$sec must tabulate SEC-036 (dev host in DB options)"
grep -qE '^\| SEC-037 \|' "$sec" || fail "$sec must tabulate SEC-037 (backup files in the theme)"
grep -qF 'are expected to hold it and are **not** findings' "$sec" \
  || fail "$sec SEC-036 must exempt home/siteurl or it fires on every healthy site"

echo PASS
