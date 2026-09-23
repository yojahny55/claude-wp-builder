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
#      This holds everywhere a live URL is picked — Step 2.3 itself, the `--suite` dispatch
#      in Step 6.5, and the GEO live scan — not just where the rule is first stated.
#
# The wording IS the behavior, so assert both directions: the contract present, and the
# discarded shape (probing the local host, folding these into passes) named as wrong.
#
# Several tokens checked below (SEC-036, UNMEASURED) already appear elsewhere in
# commands/wp-audit.md for unrelated reasons (the coverage matrix, the page-scope rules),
# so a plain `grep -Fq` on the whole file would still pass with Step 2.3's own catalog row
# or fallback sentence deleted. Those checks run on the extracted Step 2.3 section instead.

fail() { echo "FAIL: $1"; exit 1; }

cd "$(dirname "$0")/../.." || fail "cannot cd to the repository root"

audit=commands/wp-audit.md
std=skills/wp-audit-standards/SKILL.md
for f in "$audit" "$std"; do
  [ -f "$f" ] || fail "$f is missing"
  [ -r "$f" ] || fail "$f exists but cannot be read"
done

# --- Step 2.3 exists, and is extractable as its own section ---
grep -Fq 'Step 2.3' "$audit" || fail "$audit lost Step 2.3 (site type and local clone)"

step23=$(sed -n '/^## Step 2\.3:/,/^## Step 2\.5:/p' "$audit")
[ -n "$step23" ] || fail "$audit: could not extract the Step 2.3 section (heading renamed?)"
# Flattened so a wrapped sentence does not break a literal multi-word match.
step23_flat=$(printf '%s\n' "$step23" | tr '\n' ' ' | sed 's/  */ /g')
audit_flat=$(tr '\n' ' ' < "$audit" | sed 's/  */ /g')

grep -Fq 'plugin is-active woocommerce' <<<"$step23" \
  || fail "$audit Step 2.3 does not detect WooCommerce with is-active"
# is-active, not is-installed: a deactivated store is not a live store to audit.
grep -Eq 'is-active`?,? not `?is-installed' <<<"$step23" \
  || fail "$audit Step 2.3 does not justify is-active over is-installed"

# --- Site-type gating: commerce checks N/A on non-commerce, out of the denominator ---
grep -Fq 'site.commerce' <<<"$step23" || fail "$audit Step 2.3 does not record site.commerce"
grep -Fq 'no WooCommerce' <<<"$step23" \
  || fail "$audit Step 2.3 does not give the N/A reason for a non-commerce site"
# The commerce-only examples are a contract for checks the sibling PRs add, not a claim
# that they already exist — but the literal phrases are grep-gated by those PRs' own tests
# (audit-gateway-credentials.sh among them), so they must survive rewording verbatim.
for phrase in 'gateway-credential check' 'download-protection check' 'multi-currency check'; do
  grep -Fq "$phrase" <<<"$step23" \
    || fail "$audit Step 2.3 lost the literal phrase '$phrase' — a sibling PR's test greps for it"
done
grep -Fq 'commerce-only check' <<<"$step23_flat" \
  || fail "$audit Step 2.3 does not state the general commerce-gating contract for checks not yet added"

# --- Local-clone detection from the manifest ---
for token in 'source: restore' 'restore.url_origin' 'local_clone'; do
  grep -Fq "$token" <<<"$step23" || fail "$audit Step 2.3 lost clone-detection token: $token"
done
grep -Fq 'N/A (local clone)' <<<"$step23" \
  || fail "$audit Step 2.3 does not reclassify clone artifacts as N/A (local clone)"
# The catalog must name the artifacts, or a later edit quietly narrows it to nothing.
# SEC-036 alone is anchored to its catalog row: the bare code also appears elsewhere in
# the file (coverage-matrix examples), so a bare `grep -Fq 'SEC-036'` on the whole file
# would still pass with this row deleted.
grep -Fq 'Dev host stored in the database (SEC-036)' <<<"$step23" \
  || fail "$audit Step 2.3 clone-artifact catalog lost its SEC-036 row"
for artifact in 'DISABLE_WP_CRON' 'object-cache' 'predates the database'; do
  grep -Fq "$artifact" <<<"$step23" || fail "$audit Step 2.3 clone-artifact catalog lost: $artifact"
done
# Both directions: the suppression must not become a blanket excuse for real defects.
grep -Fq 'would this be true on' <<<"$step23" \
  || fail "$audit Step 2.3 lost the 'would this be true on production?' test that bounds suppression"

# --- Live checks: production host, asked and confirmed, never the clone ---
grep -Fq 'must never be probed' <<<"$step23" \
  || fail "$audit Step 2.3 does not forbid probing the local clone for live checks"
grep -Fq 'false PASS' <<<"$step23" \
  || fail "$audit Step 2.3 does not explain why a local live check is a false PASS"
grep -Eiq 'ask the user for the production URL' <<<"$step23" \
  || fail "$audit Step 2.3 does not require asking for the production URL"
# Anchored to the actual fallback sentence: bare `UNMEASURED` already appears many times
# elsewhere in the file (Step 2.7, the status vocabulary, the suite exit codes), so a
# plain `grep -Fq 'UNMEASURED'` would still pass with this fallback sentence deleted.
grep -Fq 'the live check is `UNMEASURED` with "needs the public' <<<"$step23_flat" \
  || fail "$audit Step 2.3 does not fall back to UNMEASURED without a public URL"

# --- Step 6.5 (--suite dispatch) and the GEO live scan must not fall back to
#     wordpress.url on a local clone — Step 2.3's rule has to reach both call sites, not
#     just state itself once and be forgotten where a URL is actually picked. ---
grep -Fq "the suite must not probe the clone's own host" <<<"$audit_flat" \
  || fail "$audit Step 6.5 (audit-suite.sh dispatch) does not gate its URL fallback on local_clone"
grep -Fq "the live scan must not probe the clone's own host" <<<"$audit_flat" \
  || fail "$audit's GEO live-scan dispatch (geo-scan.sh) does not gate its URL fallback on local_clone"

# --- The methodology is mirrored in the standards skill ---
grep -Fq 'Site type and local clones' "$std" \
  || fail "$std lost the site-type / local-clone methodology section"
grep -Fq 'N/A (local clone)' "$std" \
  || fail "$std does not document the N/A (local clone) status"
grep -Eiq 'would this also be true on production' "$std" \
  || fail "$std lost the production-posture test"

echo PASS
