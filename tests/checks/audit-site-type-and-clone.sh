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

# --- Local-clone detection from the manifest: the real field paths, verified against the
#     restore flow's own manifest write, not invented ones. `project.source` is nested
#     under `project`; the pre-restore URL is `wordpress.url_origin`, beside
#     `wordpress.url`; `restore` itself holds only files_archive/db_archive/url_rewritten
#     and never an origin URL. ---
for token in 'project.source: "restore"' 'wordpress.url_origin' 'local_clone'; do
  grep -Fq "$token" <<<"$step23" || fail "$audit Step 2.3 lost clone-detection token: $token"
done
grep -Fq 'N/A (local clone)' <<<"$step23" \
  || fail "$audit Step 2.3 does not reclassify clone artifacts as N/A (local clone)"
# Negative gate: the nonexistent path must not come back anywhere it was fixed.
for f in "$audit" "$std" CHANGELOG.md; do
  grep -Fq 'restore.url_origin' "$f" \
    && fail "$f still references restore.url_origin, which does not exist in the manifest the restore flow writes -- the field is wordpress.url_origin"
  grep -Eq '`?source: *restore`?' "$f" \
    && fail "$f still treats source as a root-level manifest field -- the restore flow nests it under project.source"
done
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

# --- Non-public host detection defers to bin/geo-scan.sh as the one list, and that list
#     actually recognizes this plugin's own default local domain (<slug>.local.com from
#     /wp-create, local-clone.local.com from /wp-clone) -- missing from the original
#     hand-written list, which never widened past *.local. ---
grep -Fq 'bin/geo-scan.sh' <<<"$step23" \
  || fail "$audit Step 2.3 does not name bin/geo-scan.sh as the source of truth for a non-public host"
grep -Fq '*.local.com' <<<"$step23" \
  || fail "$audit Step 2.3 does not recognize *.local.com (this plugin's own default local domain) as a non-public host"
grep -Fq '*.local.com' bin/geo-scan.sh \
  || fail "bin/geo-scan.sh does not recognize *.local.com, though Step 2.3 claims it defers to this script for the exact list"
# Functional, not just textual: the pattern in the case statement actually matches and
# actually exits 3 (not publicly reachable), the same as any other dev host.
out=$(bash bin/geo-scan.sh "some-project.local.com" 2>&1) && status=0 || status=$?
[ "$status" -eq 3 ] || fail "bin/geo-scan.sh does not exit 3 for a *.local.com host (got $status)"
grep -q 'NOT PUBLIC' <<<"$out" || fail "bin/geo-scan.sh does not report a *.local.com host as NOT PUBLIC"

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

# --- Step 2's forward-reference to the GEO live scan defers to Step 2.3, rather than
#     repeating its own wordpress.url fallback (a third live-URL site, same class as 6.5
#     and geo-scan above). Scoped to Step 2 itself so this does not match Step 2.3's own
#     text about the same idea. ---
step2=$(sed -n '/^## Step 2: Read Project Context/,/^## Step 2\.2:/p' "$audit")
[ -n "$step2" ] || fail "$audit: could not extract the Step 2 section (heading renamed?)"
step2_flat=$(printf '%s\n' "$step2" | tr '\n' ' ' | sed 's/  */ /g')
grep -Fq "Step 2.3's local-clone override" <<<"$step2_flat" \
  || fail "$audit Step 2's geo/wordpress.url note does not defer to Step 2.3's local-clone override"

# --- Step 2.3 no longer implies the commerce checks it names already exist as written ---
grep -Fq 'marked commerce' "$audit" \
  && fail "$audit still claims the SEO checks are 'marked commerce' in skills/wp-audit-seo-standards, which has no such marking"
grep -Fq 'commerce-specific section' <<<"$step23_flat" \
  || fail "$audit Step 2.3 does not reword the SEO-commerce example as a section still to be added"

# --- What Step 2.3 suppresses on a clone is recorded, not just applied: the security
#     agent (and the plugin-inventory work stacked on this PR) needs the exact items,
#     not only that "some plugins were deactivated". ---
for token in 'clone_suppressed_plugins' 'clone_parked_dropins'; do
  grep -Fq "$token" <<<"$step23" \
    || fail "$audit Step 2.3 does not record $token from the clone-artifact walk"
done
grep -Fq 'Empty, never absent, when the clone deactivated none of them' <<<"$step23" \
  || fail "$audit Step 2.3 does not say clone_suppressed_plugins is an empty list, not absent, when nothing was deactivated"
grep -Fq 'Empty, never absent, when none were' <<<"$step23_flat" \
  || fail "$audit Step 2.3 does not say clone_parked_dropins is an empty list, not absent, when nothing was parked"
# Both directions again: suppression is narrow, not a blanket excuse for the same plugin
# elsewhere. Anchored on the flattened section since the sentence wraps.
grep -Fq 'clone rule silences "it is off", never "it is off' <<<"$step23_flat" \
  || fail "$audit Step 2.3 does not say the clone suppression covers only the deactivated/parked finding, not other findings on the same item"

# --- The Step 6 dispatch template passes all four fields to every audit agent ---
dispatch=$(sed -n '/^Project context:/,/^Run all checks for your tier level\./p' "$audit")
[ -n "$dispatch" ] || fail "$audit: could not extract the Step 6 dispatch template (markers renamed?)"
for line in 'Site type (commerce):' 'Local clone:' 'Clone-suppressed plugins:' 'Parked drop-ins:'; do
  grep -Fq "$line" <<<"$dispatch" \
    || fail "$audit Step 6 dispatch template lost the '$line' line"
done
dispatch_flat=$(printf '%s\n' "$dispatch" | tr '\n' ' ' | sed 's/  */ /g')
grep -Fq 'covers only the "deactivated"/"parked" finding' <<<"$dispatch_flat" \
  || fail "$audit Step 6 dispatch template does not restate that clone suppression is narrow, not blanket, for the fields it just passed"

# --- The methodology is mirrored in the standards skill ---
grep -Fq 'Site type and local clones' "$std" \
  || fail "$std lost the site-type / local-clone methodology section"
grep -Fq 'N/A (local clone)' "$std" \
  || fail "$std does not document the N/A (local clone) status"
grep -Eiq 'would this also be true on production' "$std" \
  || fail "$std lost the production-posture test"

echo PASS
