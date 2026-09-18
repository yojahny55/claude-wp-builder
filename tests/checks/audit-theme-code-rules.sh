#!/usr/bin/env bash
# Four theme-code rules that an audit of a real theme found missing or mis-severed.
#
# Each one is pinned in both directions — the code is tabulated, and the prose carries the
# distinction that stops the check producing a wrong fix or a wrong severity:
#
#   WP-030  named only the visible-text case, so an `_e()` inside placeholder= got rewritten
#           to esc_html_e(). That escapes for the document body, not the attribute: four
#           attributes were broken by the "fix".
#   WP-049  a conditional require of a file whose functions are called unconditionally. It
#           reads as a precaution; on the audited theme the missing file would have fataled
#           about nineteen templates instead of degrading.
#   WP-050  'status' => 'publish' in WP_Query args. WP_Query reads post_status and silently
#           ignores the key, and the default made the results look right.
#   WP-051  foreach straight over get_the_terms(), which returns false or WP_Error as well as
#           an array. The same audit also flagged a wp_list_pluck() call that was already
#           safe, so the check pins the exclusion too.
set -euo pipefail
cd "$(dirname "$0")/../.."

fail() { echo "FAIL: $1"; exit 1; }

F=agents/wp-audit-practices.md
[ -f "$F" ] || fail "$F is missing"

# --- every new code is tabulated; an agent only runs what Step 1 tabulates -----
for code in WP-049 WP-050 WP-051; do
  grep -qE "^\| ${code} \|" "$F" || fail "$F: ${code} is not tabulated"
  grep -q "Procedure — .*${code}\|### Procedure — ${code}" "$F" \
    || fail "$F: ${code} has no detection prose"
done

# --- WP-030: three contexts, three escapers, and the severity note ------------
for fn in esc_html_e esc_attr_e; do
  grep -q "$fn" "$F" || fail "$F: WP-030 does not name ${fn}"
done
grep -q "placeholder" "$F" || fail "$F: WP-030 does not name the attribute context"
# The table row escapes the paren for markdown (`echo __\(`) and the prose does not,
# so the backslash is optional. Single quotes keep the pattern readable: bash leaves it alone
# and what is written here is the ERE grep receives.
grep -qE 'echo +__\\?\(' "$F" || fail "$F: WP-030 still ignores the echo __() form"
# The severity claim is the part that keeps the audit honest.
grep -qi "WARNING, not CRITICAL" "$F" \
  || fail "$F: WP-030 does not say an i18n escaping defect is WARNING, not CRITICAL"
grep -qi "\.mo" "$F" || fail "$F: WP-030 does not say the vector needs a hostile .mo"
# A regex sweep is how the wrong escaper gets applied at scale.
grep -qi "regex cannot see" "$F" || fail "$F: WP-030 does not warn against an automated sweep"

# --- WP-049: the guard must be judged against the call sites ------------------
grep -q "function_exists" "$F" || fail "$F: WP-049 does not name the call-site test"
grep -qE "is_readable" "$F" || fail "$F: WP-049 does not show the guard it fires on"
grep -qE "^\| WP-049 \|.*CRITICAL" "$F" || fail "$F: WP-049 must be CRITICAL"

# --- WP-050: the key mapping must be written down, not left to memory ---------
grep -q "post_status" "$F" || fail "$F: WP-050 does not name the key WordPress reads"
grep -qi "does not warn" "$F" || fail "$F: WP-050 does not say WP_Query ignores the key silently"

# --- WP-051: both tests, in order, and the exclusion --------------------------
grep -q "is_wp_error" "$F" || fail "$F: WP-051 does not require the is_wp_error test"
# empty() on a WP_Error is false, so testing it first lets the error through.
grep -qi "is_wp_error() first\|is_wp_error()\` first" "$F" \
  || fail "$F: WP-051 does not say is_wp_error comes first"
grep -q "wp_list_pluck" "$F" \
  || fail "$F: WP-051 does not exclude wp_list_pluck, which is already safe"

# --- no client, host or slug names reach the plugin ---------------------------
if grep -nEi "local\.com|\.local\b" "$F" >/dev/null 2>&1; then
  fail "$F: a development host name reached the plugin docs"
fi

echo PASS
