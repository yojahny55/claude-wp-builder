#!/usr/bin/env bash
# PERF-075/076/077: a review found CMYK ICC profiles bloating image files, a widget's
# register_controls() running an unbounded query on every front-end render, and Elementor CSS
# files that 404 or redirect to the home page. No audit named any of them. The rows must be
# tabulated with a procedure each, stay clone-safe, and never be auto-applied.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
perf=agents/wp-audit-performance.md

for c in 075 076 077; do
  grep -qE "^\| PERF-$c \|" "$perf" || fail "PERF-$c not tabulated"
  ! grep -Eq "^\| PERF-$c \|.*\| INFO \|$" "$perf" || fail "PERF-$c row must not be INFO-only"
done
grep -Fq 'Procedure — embedded ICC profiles on images (PERF-075)' "$perf" || fail "no PERF-075 procedure"
grep -Fq 'Procedure — Elementor widget controls queried on the front end (PERF-076)' "$perf" || fail "no PERF-076 procedure"
grep -Fq 'Procedure — missing Elementor generated CSS (PERF-077)' "$perf" || fail "no PERF-077 procedure"

# Each assertion runs inside its own procedure section, so deleting the section fails it.
section() { awk -v h="$1" 'index($0,h)==1{f=1; next} f && /^##+ /{exit} f{print}' "$perf"; }
icc=$(section '### Procedure — embedded ICC profiles on images (PERF-075)')
ctl=$(section '### Procedure — Elementor widget controls queried on the front end (PERF-076)')
css=$(section '### Procedure — missing Elementor generated CSS (PERF-077)')
[ -n "$icc" ] || fail "PERF-075 procedure section is empty"
[ -n "$ctl" ] || fail "PERF-076 procedure section is empty"
[ -n "$css" ] || fail "PERF-077 procedure section is empty"

grep -Fq '%[profile:icc]' <<<"$icc" || fail "PERF-075 lost the identify detection"
grep -Fq 'CMYK' <<<"$icc" || fail "PERF-075 lost the CMYK criterion"
grep -Fq 'never auto-applied' <<<"$icc" || fail "PERF-075 lost the never-auto-applied rule"
grep -Fq 'register_controls' <<<"$ctl" || fail "PERF-076 lost register_controls"
grep -Fq 'WP-026' <<<"$ctl" || fail "PERF-076 must cross-reference WP-026, not duplicate it"
grep -Fq 'identical' <<<"$ctl" || fail "PERF-076 fix lost the identical-HTML verification"
grep -Fq 'relative only' <<<"$ctl" || fail "PERF-076 lost the clone-timing caveat"
grep -Fq 'elementor flush-css' <<<"$css" || fail "PERF-077 lost the flush-css fix"
grep -Fq 'text/css' <<<"$css" || fail "PERF-077 lost the content-type test"
grep -Fq 'CSS Print Method' <<<"$css" || fail "PERF-077 lost the print-method note"
grep -Fq 'inconclusive' <<<"$css" || fail "PERF-077 lost the clone-without-uploads outcome"

# WP-026 must still exist for the cross-reference to resolve.
grep -qE '^\| WP-026 \|' agents/wp-audit-practices.md || fail "WP-026 vanished, PERF-076 points at it"
# PERF-071..074 now exist (db bloat attribution); ids must stay unique.
[ "$(grep -cE '^\| PERF-07[5-7] \|' "$perf")" = 3 ] || fail "PERF-075..077 must each be tabulated exactly once"

echo PASS
