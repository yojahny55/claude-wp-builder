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
#   3. The first draft excluded every plugin Step 2.3 suppressed on a local clone from the
#      new checks — and those are exactly the plugins active on PRODUCTION (payment
#      gateways, cache, mail). Step 2.3 suppresses the "deactivated" finding, never the
#      inventory entry, so they are scanned and count as loaded.
#
# The wording IS the behavior, so assert both directions where a wrong old shape existed,
# and assert inside the section that owns the rule, not anywhere in the file: the network
# gate is REUSED not reinvented, no CVE list is hardcoded, vendor plugins with no public
# listing are UNMEASURED rather than FAIL, and no site-own slug goes to a third-party feed.

fail() { echo "FAIL: $1"; exit 1; }

cd "$(dirname "$0")/../.." || fail "cannot cd to the repository root"

# section <file> <start-literal> <end-literal>: the lines from the first line containing
# start up to (not including) the next line containing end, joined into one line so prose
# wrapped across lines still matches.
section() {
  awk -v a="$2" -v b="$3" 'f && index($0, b) { exit } index($0, a) { f = 1 } f' "$1" \
    | tr '\n' ' ' | tr -s ' '
}

sec=agents/wp-audit-security.md
adopt=commands/wp-adopt.md
for f in "$sec" "$adopt"; do
  [ -f "$f" ] || fail "$f is missing"
  [ -r "$f" ] || fail "$f exists but cannot be read"
done

# --- New codes exist, each defined by exactly one table row ---
for code in 'SEC-041' 'SEC-042' 'SEC-043'; do
  grep -Fq "$code" "$sec" || fail "$sec does not define $code"
done
# A collision gate that survives sibling PRs adding their own codes: no SEC-NNN may head
# two table rows.
dupes="$(grep -oE '^\| SEC-[0-9]{3} \|' "$sec" | sort | uniq -d)"
[ -z "$dupes" ] || fail "$sec defines these codes in more than one table row: $dupes"

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

# --- Step 2.3 suppresses a finding, never an inventory entry ---
proc="$(section "$sec" '### Procedure — SEC-041 and SEC-042' '## Step 3')"
s43="$(section "$sec" '**SEC-043 — Duplicate/redeclared function' '## Step 2: Tier 2')"
rules="$(section "$sec" '9. **SEC-041 and SEC-042 share' '11. **No slug')"
[ -n "$proc" ] && [ -n "$s43" ] && [ -n "$rules" ] || fail "$sec lost a SEC-041/042/043 section"
echo "$proc" | grep -Fq 'It does **not** take the plugin out of the inventory' \
  || fail "$sec does not say Step 2.3 leaves suppressed plugins in the SEC-041/042 inventory"
echo "$proc" | grep -Fq 'every plugin Step 2.3 reclassified `N/A (local clone)`** — treat those as active' \
  || fail "$sec does not count clone-suppressed plugins as loaded for SEC-041/042"
echo "$proc" | grep -Fq 'excluding anything Step 2.3' \
  && fail "$sec still excludes clone-suppressed plugins from SEC-041/042"
echo "$s43" | grep -Fq 'Step 2.3 does not remove a plugin from this scan' \
  || fail "$sec does not keep clone-suppressed plugins in the SEC-043 scan"
echo "$s43" | grep -Fq 'is not scanned here either' \
  && fail "$sec still drops clone-suppressed plugins from SEC-043"
echo "$rules" | grep -Fq 'Step 2.3 suppresses a finding, never an inventory entry' \
  || fail "$sec rule 10 does not state that Step 2.3 keeps suppressed plugins in the inventory"
echo "$rules" | grep -Fq 'respect the Step 2.3 clone suppression' \
  && fail "$sec rule 10 still tells SEC-041/042/043 to skip clone-suppressed plugins"

# --- SEC-041 has one concrete feed, credentials, and an explicit no-credentials state ---
echo "$proc" | grep -Fq 'https://wpscan.com/api/v3/plugins/<slug>' \
  || fail "$sec does not name the SEC-041 feed endpoint"
echo "$proc" | grep -Fq 'WPSCAN_API_TOKEN' || fail "$sec does not say how the feed token is supplied"
echo "$proc" | grep -Fq '`UNMEASURED` ("no vulnerability feed credentials")' \
  || fail "$sec does not make a missing/refused token UNMEASURED"
echo "$proc" | grep -Fq '`PASS` for that item, for this feed' \
  || fail "$sec does not define a wp.org slug with no feed entry as PASS for the feed"
grep -Eq 'wp.org security advisories|advisory data' "$sec" \
  && fail "$sec still names wp.org advisories as a vulnerability source (wp.org publishes none)"

# --- No site-own slug goes to a third-party feed ---
echo "$proc" | grep -Fq 'No slug in `code_scope.editable` is ever sent to a third-party vulnerability feed' \
  || fail "$sec does not forbid sending code_scope.editable slugs to the vulnerability feed"
echo "$proc" | grep -Fq 'is sent to the vulnerability feed only when it is a public wp.org slug' \
  || fail "$sec does not restrict the feed to public wp.org slugs"

# --- SEC-043 scans everything that can declare a global function ---
for needle in 'active and inactive' 'wp-content/mu-plugins/**' 'the drop-ins' \
              'the active theme and its parent' '`vendor/`' '`tests/`' '`examples/`' \
              '**CRITICAL** when one side is an inactive plugin' '**WARNING** otherwise'; do
  echo "$s43" | grep -Fq -- "$needle" || fail "$sec SEC-043 scope/severity lacks: $needle"
done
echo "$s43" | grep -Fq -- '--status=active --format=json` for the plugin slugs' \
  && fail "$sec SEC-043 still scans active plugins only"

# --- /wp-adopt re-verification proposes, never moves in silence ---
adoptsec="$(section "$adopt" 'Re-verify the first case before offering the list' '2. **Function prefix.**')"
[ -n "$adoptsec" ] || fail "$adopt does not add a re-verification step to the code-scope detection section"
echo "$adoptsec" | grep -Fq 'plugin_uri' \
  || fail "$adopt does not check the plugin's header (plugin_uri) during re-verification"
echo "$adoptsec" | grep -Fq 'Never move a plugin in silence' \
  || fail "$adopt does not forbid moving a plugin to read-only without showing the operator"
echo "$adoptsec" | grep -Fq 'Anything deselected goes back to editable' \
  || fail "$adopt does not let the operator return a vendor-looking plugin to editable"
echo "$adoptsec" | grep -Fq 'not verified (wp.org unreachable)' \
  || fail "$adopt does not keep the transient signal when the wp.org lookup fails"
echo "$adoptsec" | grep -Fq 'a slug match alone proves nothing' \
  || fail "$adopt does not compare a matching wp.org listing against the plugin header"
echo "$adoptsec" | grep -Fq 'never to a third-party vulnerability feed' \
  || fail "$adopt does not keep the lookup to wp.org"
echo "$adoptsec" | grep -Fq 'move it to read-only before presenting the list' \
  && fail "$adopt still moves vendor-looking plugins to read-only before the operator sees them"

# --- /wp-audit surfaces a reminder for a vendor plugin left in code_scope.editable ---
grep -Fq 'Vendor-plugin re-check' "$sec" \
  || fail "$sec does not add the vendor-plugin re-check reminder to the adopted-site audit"
grep -Fq 'not a scored finding' "$sec" \
  || fail "$sec does not say the vendor-plugin reminder is unscored (must not move the denominator)"
grep -Fq 'not verified: no route to api.wordpress.org' "$sec" \
  || fail "$sec vendor-plugin re-check assumes a result when wp.org is unreachable"

echo PASS
