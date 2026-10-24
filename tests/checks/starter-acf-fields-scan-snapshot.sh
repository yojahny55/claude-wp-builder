#!/usr/bin/env bash
# The ACF scan stored a signature from a second glob after registration. If a PHP field was
# added between the first scan and that signature, it was marked scanned without bootstrap.
set -euo pipefail
cd "$(dirname "$0")/../.."
f=starter-theme/__tailwind__/functions.php
fail() { echo "FAIL: $*"; exit 1; }

[ "$(grep -Fc "glob( \$fields_dir . '/*.php' )" "$f")" = 1 ] \
  || fail "the field list is not captured once for both scanning and its signature"
grep -Fq 'function( $files ) use ( $json_dir )' "$f" \
  || fail "the signature does not use the scanned file snapshot"
grep -Fq 'foreach ( $files as $file )' "$f" \
  || fail "the bootstrap loop does not use the signed file snapshot"
grep -Fq '$current_signature = $signature( $files );' "$f" \
  || fail "the cache-miss path does not reuse its first signature calculation"
grep -Fq 'update_option( $option, $current_signature, false );' "$f" \
  || fail "the no-bootstrap path recalculates an unchanged signature"
grep -Fq 'global $wp_version;' "$f" \
  || fail "the WordPress compatibility check does not use the unfiltered version"
echo PASS
