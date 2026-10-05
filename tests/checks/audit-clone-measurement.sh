#!/usr/bin/env bash
set -euo pipefail

# Issue-159 contract: a clone audit measures what is clone-safe, gates coverage, scans GEO in
# report-only, writes nothing in report-only, and flags a live mail transport before any submit.

fail() { echo "FAIL: $1"; exit 1; }
cd "$(dirname "$0")/../.." || fail "cannot cd to the repository root"

audit=commands/wp-audit.md
has() { grep -Fq -- "$2" "$1" || fail "$1 lacks: $2"; }

has "$audit" "### Clone-safe versus production-only measurement"
has "$audit" "Measurement split:"
has "$audit" "- Report-only: <yes|no>"
has "$audit" "### A clone with a live mail transport is a finding, before any form is submitted"
sec() { sed -n "/^$1/,/^$2/p" "$audit"; }
sec "### A clone with a live mail transport" "Print the two facts" | grep -Fq 'no `pre_wp_mail`' \
  || fail "mail-transport section lost its pre_wp_mail rule"
has "$audit" "## Step 6.2: Live GEO scan"
has "$audit" "in every mode including"
has "$audit" "## Step 6.8: Coverage gate"
sec "## Step 6.8" "## Step 6.9" | grep -Fq "rejected and its agent re-dispatched" \
  || fail "Step 6.8 lost the browser-evidence rejection rule"
sec "## Step 6.8" "## Step 6.9" | grep -Fq "Re-dispatch once." \
  || fail "Step 6.8 lost the single re-dispatch rule"
has "$audit" "**\`Report-only: yes\` means the audit writes nothing.**"

# Step 6.2 must precede Step 9, and the scan must not be left pending by a report-only run.
l62=$(grep -n '^## Step 6.2' "$audit" | cut -d: -f1)
l9=$(grep -n '^## Step 9' "$audit" | cut -d: -f1)
[ "$l62" -lt "$l9" ] || fail "Step 6.2 must come before Step 9"
has "$audit" "(produced by Step 6.2's scan; Step 9 adds before"
if grep -Eq "pending and fill it" "$audit"; then
  fail "Live scan line is still left pending by Step 9 only"
fi

for a in agents/wp-audit-security.md agents/wp-audit-practices.md; do
  has "$a" "Report-only: no"
  has "$a" "Report-only: yes"
done
has skills/wp-cli-patterns/SKILL.md "## Guard a clone against outbound mail and calls"
has skills/wp-cli-patterns/SKILL.md "pre_http_request"

sec "## Step 6.8" "## Step 6.9" | grep -Fq '`checks_executed`' || fail "Step 6.8 lost checks_executed"
sec "## Step 6.8" "## Step 6.9" | grep -Fq 'the report says `INCOMPLETE`' || fail "Step 6.8 lost the INCOMPLETE rule"

echo PASS
