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
#   4. A WAF/bot-challenge 403 is not read as protection: a control request to a public
#      upload calibrates the host first, and every response outside CRITICAL (200/206 non-HTML)
#      or PASS (the server's own 403/404) is UNMEASURED, never PASS.
#   5. The probe file comes from _downloadable_files on products AND variations, under
#      /woocommerce_uploads/, printed as a relative path (the stored URL carries the clone host).
#
# Every gate below runs on the SEC-039 procedure section only, so a phrase elsewhere in the
# agent (the file mentions "production" in other checks) cannot satisfy it.

fail() { echo "FAIL: $1"; exit 1; }

cd "$(dirname "$0")/../.." || fail "cannot cd to the repository root"

sec=agents/wp-audit-security.md
[ -f "$sec" ] || fail "$sec is missing"
[ -r "$sec" ] || fail "$sec exists but cannot be read"

# The code exists in the table.
grep -Fq '| SEC-039 |' "$sec" || fail "$sec lost the SEC-039 row in the check table"

# Extract the procedure section, up to the next heading of level 2 or 3.
proc=$(awk '/^### Procedure — SEC-039/{on=1; print; next} on && /^##/{exit} on{print}' "$sec")
[ -n "$proc" ] || fail "$sec has no '### Procedure — SEC-039' section"
[ "$(printf '%s\n' "$proc" | wc -l)" -gt 20 ] || fail "SEC-039 procedure section is truncated"

# Prose wraps at 96 columns; flatten it so a phrase split across a line break still matches.
flat=$(printf '%s\n' "$proc" | tr '\n' ' ' | tr -s ' ')
has()  { printf '%s\n' "$flat" | grep -Fq -- "$1"; }
hasi() { printf '%s\n' "$flat" | grep -Fiq -- "$1"; }

has 'woocommerce_file_download_method' || fail "SEC-039 does not read the download method"

# Commerce gating (relies on Step 2.3's site.commerce, does not re-detect).
has 'N/A (no WooCommerce)' || fail "SEC-039 is not gated N/A on a non-commerce site"

# The nginx-vs-Apache reason is the crux; if it goes, the check looks like a config lookup.
has 'nginx does not' || fail "SEC-039 lost the reason the .htaccess is inert on nginx"
# The fix must name the server layer, not propose editing the (inert) .htaccess.
has 'a `location` block that denies direct access' \
  || fail "SEC-039 fix does not name an nginx location block"

# Live probe targets production, never the clone (false PASS on local Apache).
hasi 'returns a false PASS' || fail "SEC-039 does not warn that a local probe is a false PASS"
has 'must go to' && has '**production**, never the local clone' \
  || fail "SEC-039 does not require probing the production host"

# Probe-file selection: stored downloads, variations included, relative path only.
has '_downloadable_files' || fail "SEC-039 does not read _downloadable_files"
has 'product_variation' || fail "SEC-039 misses downloads attached to variations"
has '$seg="/woocommerce_uploads/"' \
  || fail "SEC-039 does not cut the stored URL at /woocommerce_uploads/"
has 'EXTERNAL-ONLY' && has 'N/A (downloads served from outside woocommerce_uploads)' \
  || fail "SEC-039 does not report external-only downloads as N/A with a reason"
has 'Never `PASS` without a probe file and a control file' \
  || fail "SEC-039 may PASS without a probe file"

# Control request calibrates the host before the paid file is judged.
has '**Control request first.**' || fail "SEC-039 lost the control request"
has 'wp-content/uploads/<control-path>' || fail "SEC-039 control request does not hit a public upload"

# A WAF challenge 403 is not protection.
has 'cf-mitigated: challenge' || fail "SEC-039 does not recognise a Cloudflare challenge"
has 'a 403 from a WAF is not protection' || fail "SEC-039 reads a WAF 403 as protected"
has "\`403\` or \`404\` from the site's own server" \
  || fail "SEC-039 PASS is not limited to the site's own 403/404"

# Everything else is UNMEASURED, never PASS.
has '`200` or `206` with any `content-type` other than `text/html`' \
  || fail "SEC-039 CRITICAL rule does not cover any non-HTML 200/206"
has 'everything else is `UNMEASURED`, never `PASS`' \
  || fail "SEC-039 lets unclassified responses fall through to PASS"
has '`200` with `text/html` (a soft 404' || fail "SEC-039 does not treat an HTML 200 as UNMEASURED"

# Reads status without downloading the paid body.
has 'curl -sI' || fail "SEC-039 does not use a header-only request (would download the paid file)"
has 'curl -s -o /dev/null -D - -r 0-0' \
  || fail "SEC-039 lacks the one-byte ranged GET fallback for HEAD 405"
has 'do not enumerate or download more files' \
  || fail "SEC-039 lost the 'one 200 is enough, do not download' bound"

echo PASS
