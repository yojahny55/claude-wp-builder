#!/usr/bin/env bash
# Cinematic starter: functions.php rescanned fields/*.php (glob, file reads, regex) on every
# request even when every group already had Local JSON. The scan must be skipped on a
# matching signature, and the signature must NOT be stored after a bootstrapping pass or
# with an unwritable acf-json/, or a failed persist would never be retried.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
f=starter-theme/__cinematic__/functions.php
[ -f "$f" ] || fail "$f is missing"

grep -Fq "\$option = '__starter___fields_scan';" "$f" || fail "no scan signature option"
grep -Fq 'if (get_option($option) === $signature()) { return; }' "$f" \
  || fail "a matching signature does not skip the scan"
grep -Fq "filemtime(\$json_dir)" "$f" || fail "signature ignores the acf-json/ directory mtime"

# The scan loop must come after the early return, and the store must sit in the
# nothing-bootstrapped branch only.
awk '/get_option\(\$option\)/{a=NR} /foreach \(glob\(\$fields_dir/{b=NR} END{exit !(a&&b&&a<b)}' "$f" \
  || fail "the signature check does not precede the scan loop"
[ "$(grep -c 'update_option(\$option' "$f")" = 1 ] || fail "signature must be stored in exactly one place"
awk '/if \(!\$bootstrapped\) \{/{f=1} f&&/update_option\(\$option/{ok=1} f&&/return;/{exit} END{exit !ok}' "$f" \
  || fail "signature is not stored in the nothing-bootstrapped branch"

if command -v php >/dev/null 2>&1; then php -l "$f" >/dev/null || fail "functions.php does not parse"; fi
echo PASS
