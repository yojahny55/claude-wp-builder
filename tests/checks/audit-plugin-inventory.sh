#!/usr/bin/env bash
set -euo pipefail

# Deeper plugin-inventory checks (SEC-041/042/043) and the /wp-adopt misclassification
# they surface.
#
# Defects this contract prevents:
#   1. SEC-032/033/034 only counted outdated/inactive plugins — a plugin could carry a
#      disclosed vulnerability, or have been unmaintained for years, and the audit would
#      never say so unless an update happened to be pending. SEC-041 (known-vulnerable) and
#      SEC-042 (abandoned) close that gap, but both need a live external feed, so they must
#      share the exact SEC-038 network gate (unreachable → UNMEASURED, never PASS) instead of
#      inventing a second gate or, worse, a hardcoded CVE/abandonment list that goes stale the
#      day it is written.
#   2. /wp-adopt classifies code_scope from the update-transient signal alone, so a
#      commercial plugin with no updater of its own (a paid multi-currency plugin, a paid
#      slider) was proposed as the site's OWN editable code. /wp-adopt now re-verifies that
#      signal against the plugin's header and wp.org listing and PROPOSES the move in a
#      reversible list; /wp-audit prints a reminder as a safety net.
#   3. The first draft excluded every plugin Step 2.3 suppressed on a local clone from the
#      new checks — and those are exactly the plugins active on PRODUCTION (payment
#      gateways, cache, mail). Step 2.3 suppresses the "deactivated" finding, never the
#      inventory entry, so they are scanned and count as loaded. The agent learns which
#      plugins those are from three named dispatch lines, never by guessing.
#   4. Snippets that could not run as written: `request[slug]=` without `curl -g` is a glob
#      error (exit 3), and `wp plugin get --field=plugin_uri` is "Invalid field". A grep for
#      `function name(` matched ~160k lines on a real site; SEC-043 ships a tokenizer script,
#      and this file executes it against a fixture.
#
# The wording IS the behavior, so assert both directions where a wrong old shape existed,
# and assert inside the section that owns the rule, not anywhere in the file.

fail() { echo "FAIL: $1"; exit 1; }

cd "$(dirname "$0")/../.." || fail "cannot cd to the repository root"

# section <file> <start-literal> <end-literal>: the lines from the first line containing
# start up to (not including) the next line containing end, joined into one line so prose
# wrapped across lines still matches. A marker that starts with `#` is a heading: it only
# matches at the start of a line outside a ``` fence, so a `## Step 3` quoted in a code
# block or in prose cannot cut the section short.
section() {
  awk -v a="$2" -v b="$3" '
    function hit(m) {
      if (substr(m, 1, 1) == "#") return !fence && index($0, m) == 1
      return index($0, m) > 0
    }
    /^[ \t]*```/ { fence = !fence }
    f && hit(b)   { exit }
    hit(a)        { f = 1 }
    f' "$1" \
    | tr '\n' ' ' | tr -s ' '
}
has() { printf '%s\n' "$1" | grep -Fq -- "$2"; }
# pos <text> <literal>: 1-based offset of the first occurrence, or empty.
pos() { printf '%s\n' "$1" | awk -v s="$2" '{ i = index($0, s); if (i) print i }'; }

sec=agents/wp-audit-security.md
adopt=commands/wp-adopt.md
script=skills/wp-cli-patterns/scripts/find-redeclared-functions.php
skill=skills/wp-cli-patterns/SKILL.md
for f in "$sec" "$adopt" "$script" "$skill"; do
  [ -f "$f" ] || fail "$f is missing"
done

tier1="$(section "$sec" '## Step 1: Tier 1' '## Step 2: Tier 2')"
tier2="$(section "$sec" '## Step 2: Tier 2' '## Step 3')"
inv="$(section "$sec" '## Plugin inventory — shared by' '## Step 1: Tier 1')"
recheck="$(section "$sec" '- **Vendor-plugin re-check.**' '## Plugin inventory')"
proc="$(section "$sec" '### Procedure — SEC-041 and SEC-042' '## Step 3')"
s43="$(section "$sec" '**SEC-043 — Duplicate/redeclared function' '## Step 2: Tier 2')"
rules="$(section "$sec" '9. **SEC-041 and SEC-042 share' '12. **The WPScan token')"
rules="$rules $(section "$sec" '12. **The WPScan token' 'never in a finding')"
adoptsec="$(section "$adopt" 'Re-verify the first case before offering the list' '2. **Function prefix.**')"
for v in tier1 tier2 inv recheck proc s43 rules adoptsec; do
  [ -n "$(echo "${!v}" | tr -d ' ')" ] || fail "section '$v' is missing — a heading the gates anchor on was renamed"
done

# --- Codes: one table row each, in the right tier ---
dupes="$(grep -oE '^\| SEC-[0-9]{3} \|' "$sec" | sort | uniq -d)"
[ -z "$dupes" ] || fail "$sec defines these codes in more than one table row: $dupes"
has "$tier1" '| SEC-043 |' || fail "$sec: the SEC-043 row is not in the Tier 1 table"
has "$tier2" '| SEC-043 |' && fail "$sec: SEC-043 has a row in the Tier 2 table"
for code in SEC-041 SEC-042; do
  has "$tier2" "| $code |" || fail "$sec: the $code row is not in the Tier 2 table"
  has "$tier1" "| $code |" && fail "$sec: $code has a row in the Tier 1 table"
done
has "$s43" 'This is Tier 1 — a code scan, no network and no vulnerability feed needed' \
  || fail "$sec does not say SEC-043 needs no network"

# --- SEC-041/042 are gated exactly like SEC-038 ---
has "$proc" 'Same gate as SEC-038, reused exactly, not reimplemented' \
  || fail "$sec does not say the SEC-041/042 gate reuses SEC-038"
for code in SEC-041 SEC-042; do
  grep -E "^\| $code \|" "$sec" | grep -Fq 'after the SEC-038 network gate passes' \
    || fail "$sec: the $code table row is not tied to the SEC-038 network gate"
done
has "$proc" 'When it fails, SEC-041 and SEC-042 are `UNMEASURED`' \
  || fail "$sec does not make SEC-041/042 UNMEASURED when the SEC-038 probe fails"
has "$proc" 'never `PASS`' || fail "$sec does not forbid PASS when the network gate fails"
has "$proc" 'Do not hardcode a CVE list' || fail "$sec does not forbid a hardcoded CVE list"
grep -Eq 'CVE-[0-9]{4}-[0-9]+' "$sec" && fail "$sec hardcodes a literal CVE identifier"

# --- Clone context: three named dispatch lines, one rule when absent ---
for line in 'Local clone: <yes|no>' 'Clone-suppressed plugins: <slug>' 'Parked drop-ins: <file>'; do
  has "$inv" "$line" || fail "$sec does not read the dispatch line '$line'"
done
has "$inv" 'When the three lines are absent, treat the project as **not a clone**' \
  || fail "$sec has no rule for a dispatch without the clone-context lines"
has "$inv" 'do not guess a list' || fail "$sec may still derive the clone-suppressed list by guessing"

# --- Step 2.3 suppresses a finding, never an inventory entry ---
has "$inv" 'It does not take the plugin out of the inventory' \
  || fail "$sec does not keep clone-suppressed plugins in the inventory"
has "$inv" '**plus every slug on the `Clone-suppressed plugins` line**' \
  || fail "$sec does not count clone-suppressed plugins as loaded"
has "$proc" 'excluding anything Step 2.3' && fail "$sec still excludes clone-suppressed plugins from SEC-041/042"
has "$s43" 'is not scanned here either' && fail "$sec still drops clone-suppressed plugins from SEC-043"
has "$rules" 'Step 2.3 suppresses a finding, never an inventory entry' \
  || fail "$sec rule 10 does not keep suppressed plugins in the inventory"
has "$rules" 'respect the Step 2.3 clone suppression' && fail "$sec rule 10 still skips clone-suppressed plugins"

# --- Runnable snippets: headers via get_plugins(), -g and a status on every info-API curl ---
grep -Fq -- '--field=plugin_uri' "$sec" "$adopt" && fail "a snippet still uses the nonexistent --field=plugin_uri"
for f in "$sec" "$adopt"; do
  grep -Fq '$h["PluginURI"]' "$f" || fail "$f does not read Plugin URI from get_plugins()"
  n_info="$(grep -c 'info/1.2/?action=' "$f" || true)"
  n_g="$(grep -B1 'info/1.2/?action=' "$f" | grep -c 'curl -gsS' || true)"
  n_w="$(grep -B1 'info/1.2/?action=' "$f" | grep 'curl -gsS' | grep -cF '%{http_code}' || true)"
  [ "$n_info" -gt 0 ] && [ "$n_info" = "$n_g" ] \
    || fail "$f: an info-API curl lacks -g ($n_g of $n_info) — the [slug] brackets glob and curl exits 3"
  [ "$n_info" = "$n_w" ] || fail "$f: an info-API curl does not print the HTTP status ($n_w of $n_info)"
done
has "$inv" 'themes/info/1.2/?action=theme_information&request[slug]=' \
  || fail "$sec has no theme route for deciding whether a theme slug is public"
has "$inv" '`update_themes`' || fail "$sec does not accept the update_themes transient for themes"

# --- Listing states and what "matches" means ---
for needle in '`error` is `Plugin not found.`' '`error` is `closed`' '**lookup failed**' \
              'strip HTML tags' 'case-fold' 'without a leading `www.`' \
              '`id` `w.org/plugins/<slug>`' 'counts as **no listing**' 'Read the body before the status'; do
  has "$inv" "$needle" || fail "$sec Plugin inventory lacks: $needle"
done
has "$inv" 'with `closed_date` and `reason`: the plugin was on wp.org and was closed. The slug is public' \
  || fail "$sec does not count a closed plugin's slug as public for SEC-041"
has "$proc" 'the lookup answers **closed**' || fail "$sec SEC-042 does not fail a closed plugin"
has "$proc" 'Name `closed_date` and `reason` in the finding' || fail "$sec SEC-042 does not name closed_date/reason"
has "$proc" '`UNMEASURED` per item, "wp.org error: <status>"' \
  || fail "$sec SEC-042 has no verdict for a failed per-item lookup"

# --- SEC-041: one feed, token on stdin, quota order, verdicts ---
has "$proc" 'https://wpscan.com/api/v3/plugins/<slug>' || fail "$sec does not name the SEC-041 endpoint"
has "$proc" 'WPSCAN_API_TOKEN' || fail "$sec does not say how the token is supplied"
has "$proc" '`UNMEASURED` ("no vulnerability feed credentials")' || fail "$sec: a missing token is not UNMEASURED"
has "$proc" '# Keep the token secret: never echo it' || fail "$sec lost the token-secrecy comment"
has "$proc" 'if [ -z "${WPSCAN_API_TOKEN:-}" ]; then' || fail "$sec: the snippet does not stop when the token is unset"
has "$proc" '| curl -sS --max-time 15 -K -' || fail "$sec: the token is not fed to curl on stdin"
grep -Eq 'echo[^|]*\$\{?WPSCAN_API_TOKEN' "$sec" && fail "$sec: a snippet echoes the token"
grep -Eq 'curl [^|]*-H[^|]*WPSCAN_API_TOKEN' "$sec" && fail "$sec: the token is on the curl command line"
has "$proc" 'Stop querying on `429`' || fail "$sec does not stop querying on 429"
has "$proc" '**loaded** plugins and themes before the inactive ones' || fail "$sec does not query loaded items first"
has "$proc" '`requests_remaining`' || fail "$sec does not read the WPScan quota first"
has "$proc" '**CRITICAL** for a loaded plugin/theme' || fail "$sec: a vulnerable loaded plugin is not CRITICAL"
has "$proc" '**WARNING** for an inactive one' || fail "$sec: a vulnerable inactive plugin is not WARNING"
has "$proc" '`PASS` for that item, for this feed' || fail "$sec: a public slug with no feed entry is not PASS"
has "$proc" 'no public vulnerability database entry' || fail "$sec: a non-public vendor plugin is not UNMEASURED"
has "$proc" 'no public metadata' || fail "$sec: SEC-042 does not mark an unlisted vendor plugin UNMEASURED"
grep -Eq 'wp.org security advisories|advisory data' "$sec" && fail "$sec names wp.org advisories as a source"

# --- Which slugs go where: one rule, stated once and repeated in the rules ---
has "$inv" '**`code_scope.editable` slugs go to wp.org only, and only from the vendor re-check**' \
  || fail "$sec does not state the single editable-slug rule"
has "$inv" 'never sent to a third-party vulnerability feed' || fail "$sec may send editable slugs to the feed"
has "$inv" '**Only public slugs are sent to the vulnerability feed.**' || fail "$sec does not restrict the feed to public slugs"
has "$rules" 'editable slugs go to wp.org only, from the vendor re-check; only public slugs reach WPScan' \
  || fail "$sec rule 11 disagrees with the editable-slug rule"
has "$rules" 'The WPScan token never leaves stdin' || fail "$sec has no rule keeping the token off the command line"
grep -Fq 'It is still skipped for' "$sec" && fail "$sec still carries the old contradictory editable-slug wording"
has "$inv" 'proved public there (this plugin'"'"'s listing, or closed): a public slug like any other' \
  || fail "$sec: a closed or listed editable plugin is not checked by SEC-041/042"
has "$inv" 'SEC-041 and SEC-042 do not look them up at all' && fail "$sec still drops every editable plugin from SEC-041/042"
has "$inv" 'the entry'"'"'s `package` host must be `downloads.wordpress.org` or its `url` host `wordpress.org`' \
  || fail "$sec trusts a transient entry a premium updater may have injected"
has "$inv" 'It is **this plugin'"'"'s listing** when the transient entry above proves it' \
  || fail "$sec does not accept a listing the transient ties to the plugin"
has "$proc" 'Pass: this plugin'"'"'s listing (tied by the transient or by author/home)' \
  || fail "$sec SEC-042 has no verdict for a transient-proved listing"

# --- Vendor re-check runs its own route probe first ---
has "$recheck" 'Run the SEC-038 route probe yourself, first' || fail "$sec: the vendor re-check does not run the route probe"
p_probe="$(pos "$recheck" 'Run the SEC-038 route probe yourself, first')"
p_lookup="$(pos "$recheck" 'look its slug up on wp.org')"
[ -n "$p_lookup" ] && [ "$p_probe" -lt "$p_lookup" ] || fail "$sec: the re-check looks up wp.org before probing the route"
has "$recheck" 'not verified: no route to api.wordpress.org' || fail "$sec: the re-check assumes a result offline"
has "$recheck" 'not a scored finding' || fail "$sec: the vendor reminder is not unscored"
has "$recheck" 'A **closed** listing gets no reminder' || fail "$sec: the re-check treats a closed plugin as vendor"
has "$recheck" 'reason `public wp.org plugin`' || fail "$sec: the re-check does not remind for a public wp.org plugin"
has "$recheck" 'A plugin proved public here (its own listing, or closed) is a public slug for SEC-041 and SEC-042' \
  || fail "$sec: the re-check's public answers do not reach SEC-041/042"
has "$recheck" 'Vendor-plugin re-check ===' || fail "$sec lost the re-check print block"

# --- SEC-043: scope, script, severity ---
for needle in 'active and inactive' 'wp-content/mu-plugins/*.php' '`Parked drop-ins` line' \
              '`*.php.disabled` or `*.bak` left in that folder is not loaded and is not scanned' \
              '[ -e "$p" ] || p="$p.php"' 'is `UNMEASURED` with the script'"'"'s stderr as the evidence line' \
              '`skipped: <path>` line on stderr' \
              'the active theme and its parent' 'find-redeclared-functions.php' 'Do not grep for it' \
              '**CRITICAL** — two or more **loaded** sources' \
              '**WARNING** — exactly one loaded source declares it; the inactive plugin cannot be activated' \
              '**INFO** — only inactive plugins declare it' 'activates a plugin in a sandbox' \
              'declared in a conditionally included file'; do
  has "$s43" "$needle" || fail "$sec SEC-043 lacks: $needle"
done
has "$s43" '**CRITICAL** when one side is an inactive plugin' && fail "$sec SEC-043 still makes an inactive side CRITICAL"
has "$s43" 'Pattern: top-level `function' && fail "$sec SEC-043 still describes a grep pattern"
has "$s43" 'within the 3 lines above' && fail "$sec SEC-043 still uses the 3-line guard heuristic"
# Every plugin loop in the snippet (at least loaded and inactive) must fall back to
# <slug>.php, or a single-file plugin is a missing source. The expected count comes from the
# loops present, so a new loop only has to carry the fallback too.
loops="$(grep -cF 'p=wp-content/plugins/$slug' "$sec")"
fallbacks="$(grep -cF 'p=wp-content/plugins/$slug; [ -e "$p" ] || p="$p.php"' "$sec")"
[ "$loops" -ge 2 ] \
  || fail "$sec: the SEC-043 snippet must hold both plugin loops (loaded and inactive); found $loops"
[ "$fallbacks" = "$loops" ] \
  || fail "$sec: $((loops - fallbacks)) of $loops plugin loops in the SEC-043 snippet lack the single-file <slug>.php fallback"
has "$s43" 'for f in wp-content/mu-plugins/*; do' && fail "$sec SEC-043 still scans every entry in mu-plugins as loaded"
grep -Fq '### `find-redeclared-functions.php`' "$skill" || fail "$skill does not document find-redeclared-functions.php"

# --- /wp-adopt: runnable lookup, branches, propose-then-confirm order ---
has "$adoptsec" '$h["PluginURI"]' || fail "$adopt does not read Plugin URI from get_plugins()"
for needle in 'Never move a plugin in silence' 'Anything deselected goes back to editable' \
              'not verified (wp.org unreachable)' 'a slug match alone proves nothing' \
              'never to a third-party vulnerability feed' '`error` is `Plugin not found.`' \
              '**Closed** — `error` is `closed`' 'do not propose it as vendor code' \
              'Read the body before the status' 'strip HTML tags' 'without a leading `www.`'; do
  has "$adoptsec" "$needle" || fail "$adopt re-verification lacks: $needle"
done
# The closed branch promises a SEC-042 finding; the agent must be able to deliver it.
has "$adoptsec" '`/wp-audit` reports the closure under SEC-042' \
  || fail "$adopt no longer tells the operator where a closed editable plugin is reported"
has "$adoptsec" '`/wp-audit` reports the closure under SEC-042' && ! has "$inv" 'a closed one fails SEC-042' \
  && fail "$adopt promises a SEC-042 finding the agent does not produce for an editable plugin"
has "$adoptsec" 'move it to read-only before presenting the list' && fail "$adopt still moves before presenting"
p_verify="$(pos "$adoptsec" 'Re-verify the first case before offering the list')"
p_present="$(pos "$adoptsec" 'Present two multi-selects')"
[ -n "$p_verify" ] && [ -n "$p_present" ] && [ "$p_verify" -lt "$p_present" ] \
  || fail "$adopt does not re-verify first and then present both lists"

# --- The SEC-043 script, executed against a fixture ---
if ! command -v php >/dev/null 2>&1; then
  # Not PASS: the tokenizer is what SEC-043 relies on, and a green line would claim it ran.
  echo "SKIP: php not found — the greps above passed, the script behavior test did not run"
  exit 0
fi
lint_err="$(php -l "$script" 2>&1)" || fail "$script does not parse: $lint_err"
fx="$(mktemp -d)"
trap 'rm -rf "$fx"' EXIT
mkdir -p "$fx/a" "$fx/b" "$fx/c" "$fx/d" "$fx/g" "$fx/h/vendor" "$fx/h/includes"
cat > "$fx/a/a.php" <<'PHP'
<?php
function acme_loaded_pair() {}
function Acme_Mixed_Case() {}
function acme_inactive_side() {}
class K { function acme_method_only() {} }
$f = function () {};
if ( ! function_exists( 'acme_guarded_one' ) ) {
	function acme_guarded_one() {}
	function acme_guarded_two() {}
}
if ( ! \function_exists( 'acme_alt' ) ) :
	function acme_alt() {}
endif;
PHP
# h holds only files the script must skip: a bundled library and a drop-in template.
echo '<?php function acme_skipped() {}' > "$fx/h/vendor/lib.php"
echo '<?php function acme_skipped() {}' > "$fx/h/includes/object-cache.php"
cat > "$fx/b/b.php" <<'PHP'
<?php
function acme_loaded_pair() {}
function acme_mixed_case() {}
function acme_method_only() {}
function acme_guarded_one() {}
function acme_guarded_two() {}
function acme_alt() {}
function acme_skipped() {}
PHP
cat > "$fx/c/c.php" <<'PHP'
<?php
namespace Acme\Tools;
function acme_loaded_pair() {}
PHP
cp "$fx/c/c.php" "$fx/g/g.php"
cat > "$fx/d/d.php" <<'PHP'
<?php
if ( function_exists( 'acme_early' ) ) { return; }
function acme_inactive_side() {}
function acme_early() {}
PHP
echo '<?php function acme_early() {}' > "$fx/object-cache.php.bak"

set +e
out="$(php "$script" loaded:a="$fx/a" loaded:b="$fx/b" inactive:c="$fx/c" inactive:d="$fx/d" \
  inactive:e="$fx/a/a.php" loaded:g="$fx/g" loaded:h="$fx/h" loaded:parked="$fx/object-cache.php.bak" 2>/dev/null)"
rc=$?
set -e
[ "$rc" = 1 ] || fail "$script must exit 1 on a finding (got $rc)"
# ENVIRON, not -v: awk -v expands backslash escapes, and a namespaced name holds a `\t`.
row() { printf '%s\n' "$out" | N="$1()" awk -F'\t' '$2 == ENVIRON["N"]'; }
row acme_loaded_pair | grep -q '^CRITICAL' || fail "$script: two loaded sources are not CRITICAL"
[ -z "$(row acme_skipped)" ] || fail "$script scanned vendor/ or a drop-in template inside a plugin"
row acme_loaded_pair | grep -Eq $'\t(c|g) ' && fail "$script collided a namespaced function with a global one"
row 'acme\tools\acme_loaded_pair' | grep -q '^WARNING' \
  || fail "$script does not qualify names by namespace (one loaded + one inactive namespaced copy)"
row acme_mixed_case | grep -q '^CRITICAL' || fail "$script is not case-insensitive"
row acme_inactive_side | grep -q '^WARNING' || fail "$script: one loaded + one inactive is not WARNING"
row acme_inactive_side | grep -q $'\td d.php' && fail "$script ignored a top-of-file early-return guard"
for n in acme_method_only acme_guarded_one acme_guarded_two acme_alt acme_early; do
  [ -z "$(row "$n")" ] || fail "$script reported $n, which is a method, guarded or behind an early return"
done
out="$(php "$script" inactive:e="$fx/a/a.php" inactive:f="$fx/b/b.php" 2>/dev/null || true)"
row acme_loaded_pair | grep -q '^INFO' || fail "$script: only-inactive collisions are not INFO"

# Second fixture: imports, braceless and nested functions, every guard form, enums, where
# drop-in templates are skipped, a parked drop-in, a missing source and an unreadable one.
# Source y declares every name once, so any name x also reports shows up as a collision.
mkdir -p "$fx/x/includes" "$fx/y"
# Imports sit in the global namespace: in a namespaced file a wrongly recorded import would
# be qualified (acme\lib\x) and could never collide with y, hiding the defect.
cat > "$fx/x/g.php" <<'PHP'
<?php
use function Other\imported_fn;
use function Other\{grouped_a, grouped_b};
use Other\{function mixed_fn, const MIXED_C};
use function imported_global;
if ( ! function_exists( 'brace_less' ) ) function brace_less() { return 1; }
function after_braceless() {}
function outer_fn() { function nested_fn() {} return 1; }
if ( ! class_exists( 'Foo' ) ) { function cls_guarded() {} }
if ( ! defined( 'X_LOADED' ) ) { function def_guarded() {} }
if ( is_admin() ) { $a = 1; } elseif ( ! function_exists( 'elif_guarded' ) ) { function elif_guarded() {} }
if ( is_admin() ) : $a = 1; elseif ( ! function_exists( 'alt_elif' ) ) : function alt_elif() {} else : function alt_else() {} endif;
enum Suit: string { case A = 'a'; public function enum_method() {} }
function after_enum() {}
PHP
echo '<?php function includes_db() {}' > "$fx/x/includes/db.php"
echo '<?php function tpl_skip() {}' > "$fx/x/includes/advanced-cache.php"
names='imported_fn grouped_a grouped_b mixed_fn imported_global brace_less after_braceless nested_fn outer_fn
cls_guarded def_guarded elif_guarded alt_elif alt_else enum_method after_enum includes_db tpl_skip parked_one'
{ echo '<?php'; for n in $names; do echo "function $n() {}"; done; } > "$fx/y/y.php"
echo '<?php function parked_one() {}' > "$fx/parked.php.bak"
set +e
out="$(php "$script" loaded:x="$fx/x" loaded:y="$fx/y" loaded:parked="$fx/parked.php.bak" 2>/dev/null)"
rc=$?
set -e
[ "$rc" = 1 ] || fail "$script: second fixture exited $rc, expected 1"
for n in imported_fn grouped_a grouped_b mixed_fn imported_global; do
  [ -z "$(row "$n")" ] || fail "$script counted the import 'use function $n' as a declaration"
done
[ -z "$(row brace_less)" ] || fail "$script missed a braceless function_exists guard"
row after_braceless | grep -q '^CRITICAL' || fail "$script kept a braceless guard open past its statement"
[ -z "$(row nested_fn)" ] || fail "$script counted a function declared inside a function body"
row outer_fn | grep -q '^CRITICAL' || fail "$script lost the enclosing named function"
for n in cls_guarded def_guarded elif_guarded alt_elif; do
  [ -z "$(row "$n")" ] || fail "$script missed the guard around $n (class_exists / defined / elseif)"
done
row alt_else | grep -q '^CRITICAL' || fail "$script treated the else branch of a guard chain as guarded"
[ -z "$(row enum_method)" ] || fail "$script counted an enum method as a global function"
row after_enum | grep -q '^CRITICAL' || fail "$script lost track of the enum body"
row includes_db | grep -q '^CRITICAL' || fail "$script skipped a plugin's own includes/db.php"
[ -z "$(row tpl_skip)" ] || fail "$script scanned an advanced-cache.php template inside a plugin"
row parked_one | grep -q $'	parked parked.php.bak:1' || fail "$script did not scan a parked *.php.bak drop-in"

set +e
err="$(php "$script" loaded:y="$fx/y" loaded:gone="$fx/does-not-exist" 2>&1 >/dev/null)"
rc=$?
set -e
[ "$rc" = 2 ] || fail "$script: a missing source exited $rc, not 2 — it would read as a pass"
has "$err" 'missing source: gone' || fail "$script does not name the missing source"
set +e
err="$(php "$script" loaded:single="$fx/y/y.php" 2>&1 >/dev/null)"
rc=$?
set -e
[ "$rc" = 0 ] || fail "$script: a single-file source exited $rc"
if [ "$(id -u)" != 0 ]; then    # root reads a mode-000 directory anyway
  mkdir -p "$fx/y/locked"
  chmod 000 "$fx/y/locked"
  set +e
  err="$(php "$script" loaded:y="$fx/y" 2>&1 >/dev/null)"
  rc=$?
  set -e
  chmod 755 "$fx/y/locked"
  [ "$rc" = 0 ] || fail "$script: an unreadable directory exited $rc instead of being skipped"
  has "$err" "skipped: $fx/y/locked" || fail "$script does not report an unreadable directory"
fi

echo PASS
