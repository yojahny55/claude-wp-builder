#!/usr/bin/env bash
# /wp-update: updating a store by hand lost time to the same traps. `tar --exclude` placed
# after the operands silently excludes nothing (wp-config.php landed in the backup);
# premium plugins licensed to the production domain fail with "Unauthorized" and the easy
# fix is to bypass the licence; and updates on a clone can re-enable mail or gateways.
# The command must keep each of those in its wording, and the old wrong forms must stay out.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
c=commands/wp-update.md
[ -f "$c" ] || fail "$c missing"

for s in 'db export' 'wp-config.php' 'must come **before** the operands' 'core update-db' \
  '--format=csv' 'Unauthorized' 'Never try to work around' 'version skew' 'wc update' \
  'elementor update db' 'elementor flush-css' 'debug.log' 'shopper-flow suite' 'retry that one section once' \
  'explicit confirmation' 'maintenance window' 'Rollback' 'parent of an active child theme' 'outside the docroot'; do
  grep -Fq -- "$s" "$c" || fail "$c lost: $s"
done

# Step order: backup before update, clone check before report.
b=$(grep -n '^## Step 2: Backup' "$c" | cut -d: -f1)
u=$(grep -n '^## Step 3: Update' "$c" | cut -d: -f1)
[ -n "$b" ] && [ -n "$u" ] && [ "$b" -lt "$u" ] || fail "backup step must precede update step"

# The exclude flag sits before the operands in the core tarball line.
line=$(grep -F 'core.tar.gz' "$c" | grep -F 'tar -czf' | head -1)
case "$line" in *--exclude=wp-config.php*-C*) ;; *) fail "tar --exclude must precede the operands";; esac

# Wrong forms stay out.
! grep -Eq 'tar [^|]*wp-admin[^|]* --exclude' "$c" || fail "tar --exclude after operands"
! grep -Eqi 'bypass the licen[cs]e|crack' <(grep -vF 'Never try to work around' "$c" | grep -vF 'no cracked zips') \
  || fail "command suggests bypassing licensing"
! grep -Eq 'CLAUDE_PLUGIN_ROOT\}?/?\.\./' "$c" || fail "relative plugin path"

# Wired into docs.
for d in README.md docs/commands.md docs/workflows.md; do
  grep -Fq '/wp-update' "$d" || fail "$d lacks /wp-update"
done
[ -f changes/wp-update-command.added.md ] || fail "changelog fragment missing"
echo PASS
