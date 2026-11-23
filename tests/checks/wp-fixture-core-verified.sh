#!/usr/bin/env bash
# The WordPress fixture verifies core against its checksums before anything is built on it.
#
# WP-CLI extracts the core .tar.gz with PHP's PharData, which ignores the PAX headers the
# WordPress tarball uses for paths longer than 100 characters. Those files land with their
# names cut at 100, so a fixture was missing core classes, and a real audit over it reported
# modified core: correctly, about a broken install. provision.sh must verify right after the
# download, re-extract the cached tarball with the system tar (which reads PAX) on a
# mismatch, and stop if core still does not verify.
#
# Contract grep only: exercising it needs the network and a database (WP_FIXTURE=1).
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

p=tests/fixtures/wp/provision.sh
need_token "$p" 'core verify-checksums' "provision.sh no longer verifies core against its checksums"
need_token "$p" 'wp_cli_cache_dir_path' "provision.sh no longer finds the tarball WP-CLI cached"
[ "$(grep -cE '^[[:space:]]+tar -xzf "\$tarball" -C "\$DIR"' "$p")" -gt 0 ] \
  || fail "provision.sh no longer re-extracts the cached tarball with the system tar"
need_token "$p" 'even after re-extracting with tar' "provision.sh no longer stops when core still does not verify"

line_of() { grep -nF -- "$1" "$p" | sed -n 1p | cut -d: -f1; }
dl=$(line_of 'core download --version')
verify=$(line_of 'core verify-checksums')
config=$(line_of 'config create')
[ -n "$dl" ] && [ -n "$verify" ] && [ -n "$config" ] || fail "provision.sh: core download, verify-checksums or config create not found"
[ "$dl" -lt "$verify" ] && [ "$verify" -lt "$config" ] \
  || fail "provision.sh must verify checksums after core download and before config create (lines $dl, $verify, $config)"
# Every verify must decide something: a `|| true`, an `if false &&` or a bare call would let a
# broken core through.
while IFS= read -r l; do
  [[ "$l" =~ ^[[:space:]]*# ]] && continue
  [[ "$l" =~ ^[[:space:]]*if\ !\ \$WP\ core\ verify-checksums ]] && continue
  [[ "$l" =~ ^[[:space:]]*\$WP\ core\ verify-checksums.*\|\|\ die ]] && continue
  fail "provision.sh runs verify-checksums without stopping on a mismatch: $l"
done < <(grep -F -- 'core verify-checksums' "$p")
echo PASS
