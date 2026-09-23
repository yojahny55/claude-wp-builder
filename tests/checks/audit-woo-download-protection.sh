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
#   5. The probe file comes from _downloadable_files on published products AND published
#      variations, under /woocommerce_uploads/, printed as a percent-encoded relative path (the
#      stored URL carries the clone host); a bare 404 is PASS only for a file known to exist.
#   6. No request can pull the paid body: HEAD with a timeout, and a ranged GET capped by
#      --max-filesize when HEAD is refused.
#
# Every gate below runs on the SEC-039 procedure section only, so a phrase elsewhere in the
# agent (the file mentions "production" in other checks) cannot satisfy it.

fail() { echo "FAIL: $1"; exit 1; }

cd "$(dirname "$0")/../.." || fail "cannot cd to the repository root"

sec=agents/wp-audit-security.md
[ -f "$sec" ] || fail "$sec is missing"
[ -r "$sec" ] || fail "$sec exists but cannot be read"

# The code exists in the table, at CRITICAL.
grep -Eq '^\| SEC-039 \|.*\| CRITICAL \|$' "$sec" \
  || fail "$sec lost the SEC-039 table row, or it is no longer CRITICAL"

# Extract the procedure section, up to the next heading of level 2 or 3.
proc=$(awk '/^### Procedure — SEC-039/{on=1; print; next} on && /^##/{exit} on{print}' "$sec")
[ -n "$proc" ] || fail "$sec has no '### Procedure — SEC-039' section"
[ "$(printf '%s\n' "$proc" | wc -l)" -gt 20 ] || fail "SEC-039 procedure section is truncated"

# Prose wraps at 96 columns; flatten it so a phrase split across a line break still matches.
flat=$(printf '%s\n' "$proc" | tr '\n' ' ' | tr -s ' ')
has()  { printf '%s\n' "$flat" | grep -Fq -- "$1"; }
# Exact code lines are matched unflattened, as whole lines.
line() { printf '%s\n' "$proc" | grep -Fxq -- "$1"; }

has 'woocommerce_file_download_method' || fail "SEC-039 does not read the download method"

# Commerce gating (relies on Step 2.3's site.commerce, does not re-detect).
has 'N/A (no WooCommerce)' || fail "SEC-039 is not gated N/A on a non-commerce site"

# redirect is CRITICAL by configuration, but only when a paid file lives in woocommerce_uploads.
has 'the redirect method with a probe path is CRITICAL' \
  || fail "SEC-039 lost the redirect-method CRITICAL rule"
has 'with `NO-DOWNLOADS` or `EXTERNAL-ONLY` it is `N/A`, exactly as for the other methods' \
  || fail "SEC-039 flags redirect CRITICAL even with no woocommerce_uploads download"

# The nginx-vs-Apache reason is the crux; if it goes, the check looks like a config lookup.
has 'nginx does not' || fail "SEC-039 lost the reason the .htaccess is inert on nginx"
# The fix must name the server layer, not propose editing the (inert) .htaccess.
has 'a `location` block that denies direct access' \
  || fail "SEC-039 fix does not name an nginx location block"

# Live probe targets production, never the clone (false PASS on local Apache).
has 'returns a false PASS' || fail "SEC-039 does not warn that a local probe is a false PASS"
has '**production**, never the local clone' \
  || fail "SEC-039 does not require probing the production host"
has 'fire nothing until it is confirmed' \
  || fail "SEC-039 may fire the probe before the production host is confirmed"
has 'with no public URL the check is `UNMEASURED`, not `PASS`' \
  || fail "SEC-039 does not report a missing public URL as UNMEASURED"

# Probe-file selection: published stored downloads, variations included, relative + encoded.
has '_downloadable_files' || fail "SEC-039 does not read _downloadable_files"
has 'p.post_type=\"product_variation\"' || fail "SEC-039 misses downloads attached to variations"
has 'AND p.post_status=\"publish\"' || fail "SEC-039 probes trashed or draft products"
has 'par.post_status=\"publish\"' || fail "SEC-039 probes variations of unpublished products"
has '$seg="/woocommerce_uploads/"' \
  || fail "SEC-039 does not cut the stored URL at /woocommerce_uploads/"
has 'file_exists($dir.$p)' || fail "SEC-039 does not prefer a probe file that exists locally"
has 'array_map("rawurlencode",explode("/",$p))' \
  || fail "SEC-039 does not percent-encode the probe path"
has '`NO-DOWNLOADS` — no published product or variation stores a download: `N/A (no downloadable products)`' \
  || fail "SEC-039 lost the NO-DOWNLOADS marker"
has 'EXTERNAL-ONLY' && has 'N/A (downloads served from outside woocommerce_uploads)' \
  || fail "SEC-039 does not report external-only downloads as N/A with a reason"
has '`NO-CONTROL` — no public upload to calibrate against: `UNMEASURED`' \
  || fail "SEC-039 lost the NO-CONTROL marker"
has 'Never `PASS` without a probe file and a control file' \
  || fail "SEC-039 may PASS without a probe file"

# Control request calibrates the host before the paid file is judged.
has '**Control request first.**' || fail "SEC-039 lost the control request"
line 'curl -sI --max-time 15 -A "Mozilla/5.0" "https://<production-host>/wp-content/uploads/<control-path>"' \
  || fail "SEC-039 control request is not a timed HEAD on a public upload"
has 'It must come back `200` with a non-HTML `content-type`' \
  || fail "SEC-039 lost the control's 200 / non-HTML criterion"
has 'redirects are not followed (no `-L`)' \
  || fail "SEC-039 does not say which response the verdict is read from"

# The paid-file probe itself, header-only and timed, plus the capped ranged fallback.
line 'curl -sI --max-time 15 -A "Mozilla/5.0" "https://<production-host>/wp-content/uploads/woocommerce_uploads/<path>"' \
  || fail "SEC-039 lost the header-only probe of the paid file"
line 'curl -s -o /dev/null -D - -r 0-0 --max-filesize 1024 --max-time 15 -A "Mozilla/5.0" "https://<production-host>/wp-content/uploads/woocommerce_uploads/<path>"' \
  || fail "SEC-039 ranged fallback is missing or uncapped (could download the paid file)"
has 'Any other non-zero exit, or no status line at all, is `UNMEASURED`, quoting the curl exit code' \
  || fail "SEC-039 does not report a curl error as UNMEASURED"

# Verdict table.
has '| `200` or `206` with any `content-type` other than `text/html` | the file is served without a purchase → **CRITICAL** |' \
  || fail "SEC-039 CRITICAL rule does not cover any non-HTML 200/206"
has "| \`403\` from the site's own server — no challenge headers (below) and the control returned \`200\` | protected → PASS |" \
  || fail "SEC-039 403 PASS is not limited to the site's own 403 after a good control"
has "| \`404\` from the site's own server, same conditions, and the probe file was \`FOUND\` | protected → PASS |" \
  || fail "SEC-039 404 PASS does not require a probe file known to exist"
has '| `404` on an `UNVERIFIED` probe file | the file may simply be gone → `UNMEASURED` |' \
  || fail "SEC-039 reads a 404 on an unverified file as protected"
has 'cf-mitigated: challenge' || fail "SEC-039 does not recognise a Cloudflare challenge"
has 'a 403 from a WAF is not protection' || fail "SEC-039 reads a WAF 403 as protected"
has '`200` with `text/html` (a soft 404' || fail "SEC-039 does not treat an HTML 200 as UNMEASURED"
has 'Only the table'"'"'s first three rows produce a verdict; everything else is `UNMEASURED`, never `PASS`' \
  || fail "SEC-039 lets unclassified responses fall through to PASS"

# One 200 is enough.
has 'do not enumerate or download more files' \
  || fail "SEC-039 lost the 'one 200 is enough, do not download' bound"

echo PASS
