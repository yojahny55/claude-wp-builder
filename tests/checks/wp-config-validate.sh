#!/usr/bin/env bash
# The manifest has about thirty readers and, before this, no writer contract: only
# /wp-audit knew manifest_version existed and /wp-create never wrote it. A malformed
# manifest therefore failed thirty different ways, late, inside whichever command
# happened to read it first. These assertions pin the single early failure instead.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

cfg="node bin/wp-config.mjs"
fx=tests/fixtures/manifests

# --- A valid manifest passes and says nothing alarming. ---------------------
out=$($cfg validate "$fx/valid" 2>&1) || fail "a valid manifest did not exit 0: $out"

# --- A missing manifest is exit 3, distinct from invalid. -------------------
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
set +e
$cfg validate "$tmp" >"$tmp/out" 2>&1; code=$?
set -e
[ "$code" = "3" ] || fail "a missing manifest exited $code, want 3"
grep -q '.wp-create.json' "$tmp/out" || fail "the missing-manifest message does not name the file"

# --- A malformed manifest is exit 1 and names the problem field. ------------
set +e
$cfg validate "$fx/malformed" >"$tmp/bad" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "a malformed manifest exited $code, want 1"
grep -q 'project.slug' "$tmp/bad" || fail "the invalid-manifest message does not name the missing field"

echo PASS
