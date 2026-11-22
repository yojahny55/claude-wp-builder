#!/usr/bin/env bash
set -euo pipefail
# /wp-init asked the template, the custom-fields plugin and the i18n question, and Step 0.5
# could already dispatch to /wp-cinematic-init, BEFORE the manifest was validated and before
# the `demo/FAILED.md` stop. A project with an invalid manifest or a demo that never passed
# verification was therefore interviewed (and, for cinematic, handed to another command)
# before anything refused it. The refusals must come first.
#
# Asserts on heading order in the command as a run reads it. The self-test reorders a copy
# to prove the assertion fires.
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
. tests/checks/lib/expand-command.sh; expand_command commands/wp-init.md; cmd=$EXPANDED

line() { grep -n -m1 -E "$2" "$1" | cut -d: -f1; }

# order_problems <file>: prints a line per misordered pair.
order_problems() {
  local f=$1 val stop q dispatch
  val=$(line "$f" '^## Pre-Step: Check for `\.wp-create\.json` Manifest')
  stop=$(line "$f" '^## Step 0\.45: Stop on a Failed Demo')
  [ -n "$val" ] && [ -n "$stop" ] || { echo "missing the manifest validation or the FAILED.md stop heading"; return; }
  for q in 0.5 0.6 0.7; do
    n=$(line "$f" "^## Step $q:")
    [ -n "$n" ] || { echo "missing Step $q"; continue; }
    [ "$val" -lt "$n" ] || echo "Step $q asks before the manifest is validated"
    [ "$stop" -lt "$n" ] || echo "Step $q asks before the demo/FAILED.md stop"
  done
  dispatch=$(line "$f" 'Any other cinematic run')
  [ -n "$dispatch" ] || { echo "no dispatch to /wp-cinematic-init found"; return; }
  [ "$val" -lt "$dispatch" ] || echo "the /wp-cinematic-init dispatch precedes the manifest validation"
  [ "$stop" -lt "$dispatch" ] || echo "the /wp-cinematic-init dispatch precedes the demo/FAILED.md stop"
}

scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
# Self-test: move the Step 0.5 heading line above the Pre-Step heading.
awk '/^## Step 0\.5:/ {next} /^## Pre-Step:/ {print "## Step 0.5: Select Starter Template"} {print}' "$cmd" >"$scratch/bad.md"
[ -n "$(order_problems "$scratch/bad.md")" ] || fail "self-test: a question placed before the manifest validation went unreported"

problems=$(order_problems "$cmd")
[ -z "$problems" ] || { echo "$problems"; fail "/wp-init asks or dispatches before it validates"; }
echo PASS
