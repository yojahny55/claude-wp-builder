#!/usr/bin/env bash
# The dev-host sweep reads four tables, and no update count is reported without a network.
#
# Two defects from one audit, both of which produced a report that read as clean:
#   1. SEC-036 swept `wp_options` only. It found 7 occurrences and the database was
#      declared clean. The same needle across postmeta, posts and termmeta found 25 —
#      including a `custom` menu item whose target lives verbatim in _menu_item_url and
#      would have become a link off the live site after the push.
#   2. `wp core check-update` and `wp plugin list --update=available` read transients, not
#      api.wordpress.org. With no route the stale transient answers and the audit reported
#      one pending plugin update. With a route the real count was twelve and core was a
#      minor version behind.
set -euo pipefail
cd "$(dirname "$0")/../.."

fail() { echo "FAIL: $1"; exit 1; }

SEC=agents/wp-audit-security.md
PRA=agents/wp-audit-practices.md
SCRIPT=skills/wp-cli-patterns/scripts/check-dev-host.php

for f in "$SEC" "$PRA" "$SCRIPT"; do
  [ -f "$f" ] || fail "$f is missing"
done

# --- 1. SEC-036 covers all four tables, in the agent and in the script ---------
for table in options postmeta posts termmeta; do
  grep -q "wpdb->${table}\|\$wpdb->${table}" "$SEC" \
    || fail "$SEC: SEC-036 does not sweep \$wpdb->${table}"
  grep -q "wpdb->${table}" "$SCRIPT" \
    || fail "$SCRIPT: does not sweep \$wpdb->${table}"
done

# home/siteurl are what makes the local install work; sweeping them turns a correct
# site into two CRITICAL findings on every run.
grep -q "'home','siteurl'" "$SEC" || fail "$SEC: SEC-036 must exclude home and siteurl"
grep -q "'home','siteurl'" "$SCRIPT" || fail "$SCRIPT: must exclude home and siteurl"

# A guid is never resolved as a URL, so it cannot be fixed the same way as a printed value.
grep -qi "guid" "$SEC" || fail "$SEC: SEC-036 does not say what to do with a guid match"
grep -qi "do not rewrite" "$SCRIPT" || fail "$SCRIPT: must say a guid is not to be rewritten"

# Read-only means read-only: a deploy gate that writes is not a gate.
if grep -nE '\$wpdb->(query|update|delete|insert|replace)\(' "$SCRIPT" >/dev/null 2>&1; then
  fail "$SCRIPT: the dev-host sweep must be read-only"
fi
grep -q "exit( \$total > 0 ? 1 : 0 );" "$SCRIPT" \
  || fail "$SCRIPT: must exit 1 when it finds rows, so a shell script can gate on it"

# The table must point at the sweep, not at a single-table command — an agent runs the row.
grep -qE '^\| SEC-036 \|.*postmeta' "$SEC" \
  || fail "$SEC: the SEC-036 table row still describes an options-only check"

# --- 2. SEC-038 gates every update count --------------------------------------
grep -qE '^\| SEC-038 \|' "$SEC" || fail "$SEC: SEC-038 is not tabulated"
grep -q "api.wordpress.org" "$SEC" || fail "$SEC: SEC-038 does not name the endpoint it reaches"
grep -q "api.wordpress.org" "$PRA" || fail "$PRA: WP-043/WP-044 carry no network gate"

# Deleting the transients is the whole point: without it the count is a measurement of
# the cache, and the cache is what was wrong.
for f in "$SEC" "$PRA"; do
  grep -q "transient delete update_core" "$f" \
    || fail "$f: the update counts are read without rebuilding update_core"
  grep -q "transient delete update_plugins" "$f" \
    || fail "$f: the update counts are read without rebuilding update_plugins"
done

# With no route the outcome is UNMEASURED. Reporting 0 is the defect this check pins.
grep -q "UNMEASURED" "$SEC" || fail "$SEC: SEC-038 does not define the no-network outcome"
grep -q "UNMEASURED" "$PRA" || fail "$PRA: WP-043/WP-044 do not define the no-network outcome"

echo PASS
