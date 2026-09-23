#!/usr/bin/env bash
set -euo pipefail

# Site type and local-clone awareness (wp-audit Step 2.3).
#
# Three defects this contract prevents, each one an audit reporting on the wrong site:
#   1. Commerce checks added for stores fire on a generic blog and score it for a cart it
#      never had — a store feature counted as a failure. Every commerce check must read
#      `N/A` (out of the denominator) when WooCommerce is not active, so adding commerce
#      depth leaves a non-commerce site's score unchanged.
#   2. A site restored to run locally is deliberately altered — dev host in the DB,
#      deactivated payment/cache/mail plugins, cron disabled, debug on, media newer than the
#      file backup. Reporting those audits the copy, not the site. On a clone they are
#      `N/A (local clone)`, suppressed, out of the denominator.
#   3. Live checks (headers, paid-file reachability) answered against the local server are
#      false: a local Apache reads an `.htaccess` a production nginx ignores. They must run
#      against a confirmed production URL, never the clone, and be `UNMEASURED` without one.
#
# The wording IS the behavior, so assert both directions: the contract present, and the
# discarded shape (probing the local host, folding these into passes) named as wrong.

fail() { echo "FAIL: $1"; exit 1; }

cd "$(dirname "$0")/../.." || fail "cannot cd to the repository root"

audit=commands/wp-audit.md
std=skills/wp-audit-standards/SKILL.md
for f in "$audit" "$std"; do
  [ -f "$f" ] || fail "$f is missing"
  [ -r "$f" ] || fail "$f exists but cannot be read"
done

# --- Step 2.3 exists and reads both facts ---
grep -Fq 'Step 2.3' "$audit" || fail "$audit lost Step 2.3 (site type and local clone)"
grep -Fq 'plugin is-active woocommerce' "$audit" \
  || fail "$audit does not detect WooCommerce with is-active"
# is-active, not is-installed: a deactivated store is not a live store to audit.
grep -Eq 'is-active`?,? not `?is-installed' "$audit" \
  || fail "$audit does not justify is-active over is-installed"

# --- Site-type gating: commerce checks N/A on non-commerce, out of the denominator ---
grep -Fq 'site.commerce' "$audit" || fail "$audit does not record site.commerce"
grep -Fq 'no WooCommerce' "$audit" \
  || fail "$audit does not give the N/A reason for a non-commerce site"

# --- Local-clone detection from the manifest ---
for token in 'source: restore' 'restore.url_origin' 'local_clone'; do
  grep -Fq "$token" "$audit" || fail "$audit lost clone-detection token: $token"
done
grep -Fq 'N/A (local clone)' "$audit" \
  || fail "$audit does not reclassify clone artifacts as N/A (local clone)"
# The catalog must name the artifacts, or a later edit quietly narrows it to nothing.
for artifact in 'SEC-036' 'DISABLE_WP_CRON' 'object-cache' 'predates the database'; do
  grep -Fq "$artifact" "$audit" || fail "$audit clone-artifact catalog lost: $artifact"
done
# Both directions: the suppression must not become a blanket excuse for real defects.
grep -Fq 'would this be true on' "$audit" \
  || fail "$audit lost the 'would this be true on production?' test that bounds suppression"

# --- Live checks: production host, asked and confirmed, never the clone ---
grep -Fq 'must never be probed' "$audit" \
  || fail "$audit does not forbid probing the local clone for live checks"
grep -Fq 'false PASS' "$audit" \
  || fail "$audit does not explain why a local live check is a false PASS"
grep -Eiq 'ask the user for the production URL' "$audit" \
  || fail "$audit does not require asking for the production URL"
grep -Fq 'UNMEASURED' "$audit" \
  || fail "$audit does not fall back to UNMEASURED without a public URL"

# --- The methodology is mirrored in the standards skill ---
grep -Fq 'Site type and local clones' "$std" \
  || fail "$std lost the site-type / local-clone methodology section"
grep -Fq 'N/A (local clone)' "$std" \
  || fail "$std does not document the N/A (local clone) status"
grep -Eiq 'would this also be true on production' "$std" \
  || fail "$std lost the production-posture test"

echo PASS
