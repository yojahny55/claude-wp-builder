#!/usr/bin/env bash
set -euo pipefail

# Deeper plugin-inventory checks (SEC-041/042/043) and the /wp-adopt misclassification
# they surface.
#
# Two defects this contract prevents:
#   1. SEC-032/033/034 only counted outdated/inactive plugins — a plugin could carry a
#      disclosed vulnerability, or have been unmaintained for years, and the audit would
#      never say so unless an update happened to be pending. SEC-041 (known-vulnerable) and
#      SEC-042 (abandoned) close that gap, but both need a live external feed, so they must
#      share the exact SEC-038 network gate (unreachable → UNMEASURED, never PASS) instead of
#      inventing a second gate or, worse, a hardcoded CVE/abandonment list that goes stale the
#      day it is written.
#   2. /wp-adopt classifies code_scope from the update-transient signal alone, so a
#      commercial plugin with no updater of its own (a paid multi-currency plugin, a paid
#      slider) was proposed as the site's OWN editable code, when it is vendor code nobody at
#      the site can safely patch. /wp-adopt now re-verifies that signal against the plugin's
#      header and wp.org listing before confirming, and /wp-audit prints a reminder as a
#      safety net for sites adopted before this existed.
#
# The wording IS the behavior, so assert both directions where a wrong old shape existed:
# the network gate is REUSED not reinvented, no CVE list is hardcoded, and vendor plugins
# with no public listing are UNMEASURED rather than FAIL.

fail() { echo "FAIL: $1"; exit 1; }

cd "$(dirname "$0")/../.." || fail "cannot cd to the repository root"

sec=agents/wp-audit-security.md
adopt=commands/wp-adopt.md
for f in "$sec" "$adopt"; do
  [ -f "$f" ] || fail "$f is missing"
  [ -r "$f" ] || fail "$f exists but cannot be read"
done

# --- New codes exist, and only the three assigned to this PR ---
for code in 'SEC-041' 'SEC-042' 'SEC-043'; do
  grep -Fq "$code" "$sec" || fail "$sec does not define $code"
done
# SEC-039 and SEC-040 belong to sibling PRs — this PR must not claim them.
for code in 'SEC-039' 'SEC-040'; do
  grep -Fq "$code" "$sec" && fail "$sec claims $code, which belongs to a sibling PR"
done
true

# --- SEC-041/042 are gated exactly like SEC-038, not a second gate ---
grep -Fq 'SEC-038' "$sec" || fail "$sec lost the SEC-038 network-gate check entirely"
grep -Eq 'SEC-041.*SEC-038|SEC-038.*SEC-041' "$sec" \
  || fail "$sec does not tie SEC-041 to the SEC-038 network gate"
grep -Eq 'SEC-042.*SEC-038|SEC-038.*SEC-042' "$sec" \
  || fail "$sec does not tie SEC-042 to the SEC-038 network gate"
grep -Fq 'Same gate as SEC-038, reused exactly, not reimplemented' "$sec" \
  || fail "$sec does not say the SEC-041/042 gate reuses SEC-038 rather than adding a new one"
grep -Fq 'never `PASS`' "$sec" \
  || fail "$sec does not forbid PASS when the SEC-041/042 network gate fails"

# --- No hardcoded vulnerability/abandonment list ---
grep -Fq 'Do not hardcode a CVE list' "$sec" \
  || fail "$sec does not forbid hardcoding a CVE/vulnerability list"
# Both directions: the prohibition is stated AND no literal CVE identifier was actually baked in.
if grep -Eq 'CVE-[0-9]{4}-[0-9]+' "$sec"; then
  fail "$sec appears to hardcode a literal CVE identifier"
fi

# --- Vendor/premium plugins with no public listing are UNMEASURED, not FAIL ---
# Prose wraps across lines, so tolerate a line break (and its indent) between the two halves.
tr '\n' ' ' < "$sec" | tr -s ' ' | grep -Fq 'no public vulnerability database entry' \
  || fail "$sec does not mark an unlisted vendor plugin UNMEASURED for SEC-041"
grep -Fq 'no public metadata' "$sec" \
  || fail "$sec does not mark an unlisted vendor plugin UNMEASURED (\"no public metadata\") for SEC-042"

# --- SEC-043 is Tier 1 (code scan), no network ---
grep -Fq 'SEC-043' "$sec" || fail "$sec lost SEC-043"
joined="$(tr '\n' ' ' < "$sec" | tr -s ' ')"
echo "$joined" | grep -Eiq 'SEC-043.{0,400}Tier 1|Tier 1.{0,400}SEC-043' \
  || fail "$sec does not place SEC-043 in Tier 1"
echo "$joined" | grep -Fq 'no network and no vulnerability feed needed' \
  || fail "$sec does not say SEC-043 needs no network"
grep -Fq 'redeclare' "$sec" || fail "$sec does not describe the redeclare-fatal risk for SEC-043"

# --- Step 2.3 clone suppression carries over to the new codes ---
grep -Fq 'N/A (local clone)' "$sec" \
  || fail "$sec does not reference the Step 2.3 N/A (local clone) suppression"
grep -Eq 'SEC-041, SEC-042 and SEC-043 respect the Step 2.3 clone suppression|respect the Step 2.3 clone suppression' "$sec" \
  || fail "$sec does not say SEC-041/042/043 respect the Step 2.3 clone-suppression list"

# --- /wp-adopt misclassification fix: vendor-without-updater plugins move to read_only ---
grep -Fq 'Re-verify the first case before offering the list' "$adopt" \
  || fail "$adopt does not add a re-verification step to the code-scope detection section"
grep -Fq 'plugin_uri' "$adopt" \
  || fail "$adopt does not check the plugin's header (plugin_uri) during re-verification"
tr '\n' ' ' < "$adopt" | tr -s ' ' | grep -Fq 'move it to read-only' \
  || fail "$adopt does not tell the operator to move a vendor-without-updater plugin to read-only"

# --- /wp-audit surfaces a reminder for a vendor plugin left in code_scope.editable ---
grep -Fq 'Vendor-plugin re-check' "$sec" \
  || fail "$sec does not add the vendor-plugin re-check reminder to the adopted-site audit"
grep -Fq 'not a scored finding' "$sec" \
  || fail "$sec does not say the vendor-plugin reminder is unscored (must not move the denominator)"

echo PASS
