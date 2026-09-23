#!/usr/bin/env bash
set -uo pipefail

# SEC-039 — paid WooCommerce downloads reachable without a purchase.
#
# The defect the check exists for: a store's paid files live under
# wp-content/uploads/woocommerce_uploads/, guarded only by an .htaccess `deny from all`.
# Apache honours it; nginx ignores it. With the `force`/`xsendfile` download method the store
# looks correctly configured from the admin while every paid file is fetchable by URL on an
# nginx host. `redirect` serves them from a public URL with no gate at all.
#
# What must not rot:
#   1. It is commerce-gated — N/A (no WooCommerce) on a non-commerce site, so adding it does
#      not move a generic site's score.
#   2. The live probe targets PRODUCTION, never the local clone, or a local Apache returns a
#      false PASS for a site wide open behind nginx.
#   3. The fix names the server layer (nginx location block, not .htaccess) and the check
#      reads the status of a HEAD/path-only request without downloading the paid file.

fail() { echo "FAIL: $1"; exit 1; }

cd "$(dirname "$0")/../.." || fail "cannot cd to the repository root"

sec=agents/wp-audit-security.md
[ -f "$sec" ] || fail "$sec is missing"
[ -r "$sec" ] || fail "$sec exists but cannot be read"

# The code exists, in the table and as a procedure.
grep -Fq 'SEC-039' "$sec" || fail "$sec lost the SEC-039 code"
grep -Fq 'woocommerce_file_download_method' "$sec" \
  || fail "SEC-039 does not read the download method"
grep -Fq 'woocommerce_uploads' "$sec" \
  || fail "SEC-039 does not name the woocommerce_uploads directory"

# Commerce gating (relies on Step 2.3's site.commerce, does not re-detect).
grep -Fq 'N/A (no WooCommerce)' "$sec" \
  || fail "SEC-039 is not gated N/A on a non-commerce site"

# The nginx-vs-Apache reason is the crux; if it goes, the check looks like a config lookup.
grep -Fq 'nginx does not' "$sec" \
  || fail "SEC-039 lost the reason the .htaccess is inert on nginx"
# The fix must name the server layer, not propose editing the (inert) .htaccess.
grep -Fiq 'location' "$sec" \
  || fail "SEC-039 fix does not name an nginx location block"

# Live probe targets production, never the clone (false PASS on local Apache).
grep -Fq 'false PASS' "$sec" \
  || fail "SEC-039 does not warn that a local probe is a false PASS"
grep -Eiq 'production' "$sec" \
  || fail "SEC-039 does not require probing the production host"

# Reads status without downloading the paid body.
grep -Fq 'curl -sI' "$sec" \
  || fail "SEC-039 does not use a header-only request (would download the paid file)"
grep -Fq 'do not enumerate or download more files' "$sec" \
  || fail "SEC-039 lost the 'one 200 is enough, do not download' bound"

echo PASS
