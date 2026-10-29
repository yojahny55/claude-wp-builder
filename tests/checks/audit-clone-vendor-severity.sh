#!/usr/bin/env bash
# A clone audit rated its own copy as production: SEC-036 sat in the CRITICAL headline for three
# runs (guid rows included), a log table the sync tool skipped was CRITICAL, local Apache
# transport was reported as the site's, and pattern hits in vendor plugins (query_posts, ABSPATH,
# eval) were counted under invented codes. Pin the severity ceiling and the vendor/catalog rules.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
has() { grep -Fq -- "$2" "$1" || fail "$1 lacks: $2"; }
lacks() { ! grep -Fq -- "$2" "$1" || fail "$1 still has: $2"; }

sc=skills/wp-audit-run/references/site-context.md
ad=skills/wp-audit-run/references/adopted-site.md
sec=skills/wp-audit-standards/references/sec-procedures-deploy-and-downloads.md
has $sc "### Local clone — severity ceiling"
has $sc "pre-deploy gate"
has $sc "\`guid\` rows are not counted at all"
has $sc "capped at \`WARNING\`"
has $sc "exclude list"
has $sc "local server only, unverified on prod"
has $sc "Probe the scheme before any HTTP check"
has $sc "WP-040"
has $sc "are \`INFO\` on a clone"
lacks $sc "| Dev host stored in the database (SEC-036) |"
has $ad "vendor notes"
has $ad "one"
has $ad "A finding carries a catalog code"
lacks $ad "Findings in read-only code are always reported with"
lacks $sec "OR guid LIKE"
lacks $sec "is WARNING rather than CRITICAL"
has $sec "Local clone — severity ceiling"
has skills/wp-audit-run/references/dispatch.md "Clone severity ceiling:"
has skills/wp-audit-run/references/dispatch.md "Only catalog codes, one finding per root cause."
has agents/wp-audit-security.md "INFO\` pre-deploy gate"
has agents/wp-audit-practices.md "WARNING (\`INFO\` on a local clone)"
has agents/wp-audit-performance.md "N/A (excluded by the sync tool)"
has agents/wp-audit-performance.md "local server only, unverified on prod"
echo PASS
