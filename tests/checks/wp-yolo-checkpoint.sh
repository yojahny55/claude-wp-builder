#!/usr/bin/env bash
# The default (flagless) /wp-yolo run must stop at the Step 3 checkpoint and
# show the build plan (pages, CPTs). A real run skipped it: the model read the
# command name as the --yolo flag and rolled straight into Step 4.
set -euo pipefail
cd "$(dirname "$0")/../.."
f=commands/wp-yolo.md
fail() { echo "FAIL: $1"; exit 1; }

grep -q "^allowed-tools:.*AskUserQuestion" "$f" || fail "wp-yolo cannot ask: AskUserQuestion missing from allowed-tools"
grep -Fq "that name is NOT the \`--yolo\` flag" "$f" || fail "Step 1 no longer says the command name is not the --yolo flag"

s3=$(awk "/^## Step 3:/,/^## Step 4:/" "$f")
[ -n "$s3" ] || fail "no Step 3 region"
grep -Fq "hard stop" <<<"$s3" || fail "Step 3 is not declared a hard stop"
grep -Fq "END YOUR TURN" <<<"$s3" || fail "Step 3 does not tell the model to end its turn"
grep -Fq "do not start Step 4 in the same turn" <<<"$s3" || fail "Step 3 does not forbid continuing into Step 4"
grep -Fq "Pages to build:" <<<"$s3" || fail "Step 3 build plan does not list pages"
grep -Fq "CPTs to register:" <<<"$s3" || fail "Step 3 build plan does not list CPTs"
grep -Fq "AskUserQuestion" <<<"$s3" || fail "Step 3 does not ask via AskUserQuestion"

echo PASS
