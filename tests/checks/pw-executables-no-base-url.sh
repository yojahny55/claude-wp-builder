#!/usr/bin/env bash
# The suite preload blocks every host outside an allowlist built from BASE_URL. With no usable
# BASE_URL the list is loopback only: the block stays closed (it keeps a run off production
# properties) and the preload says so on stderr instead of blocking silently.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
command -v node >/dev/null || { echo "PASS (SKIP: no node)"; exit 0; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
js='const m=require("./bin/lib/pw-executables.cjs");console.log(JSON.stringify(m.block))'

out=$(env -u BASE_URL -u WP_AUDIT_ALLOW_HOSTS WP_AUDIT_BLOCK_THIRD_PARTY=1 node -e "$js" 2>"$tmp/err")
[ "$out" = '["localhost","127.0.0.1","[::1]"]' ] || fail "without BASE_URL the allowlist is not loopback only: $out"
grep >/dev/null -c 'BASE_URL is not set' "$tmp/err" || fail "no stderr warning when BASE_URL is missing"
BASE_URL="not a url" WP_AUDIT_BLOCK_THIRD_PARTY=1 node -e "$js" 2>"$tmp/err" >/dev/null
grep >/dev/null -c 'BASE_URL is not set' "$tmp/err" || fail "no stderr warning when BASE_URL is invalid"

BASE_URL="http://site.example" WP_AUDIT_BLOCK_THIRD_PARTY=1 node -e "$js" 2>"$tmp/err" >"$tmp/out"
[ ! -s "$tmp/err" ] || fail "a valid BASE_URL printed a warning: $(cat "$tmp/err")"
grep >/dev/null -c 'site.example' "$tmp/out" || fail "a valid BASE_URL is not in the allowlist"
env -u BASE_URL -u WP_AUDIT_BLOCK_THIRD_PARTY node -e "$js" 2>"$tmp/err" >/dev/null
[ ! -s "$tmp/err" ] || fail "the warning fired with the block off"
echo PASS
