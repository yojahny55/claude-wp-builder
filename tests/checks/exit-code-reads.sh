#!/usr/bin/env bash
# Prose that runs a tool must read the exit code the tool documents, not "non-zero means X".
# style-diff exits 3 when a page or viewport went unmeasured (INCOMPLETE) and the audit fix step
# read that as "a style value moved"; assets-fresh exits 2 on bad usage or an unreadable manifest
# and /wp-update reported that as stale critical cuts. Pin each tool's documented code and the
# reader that branches on it.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
has() { grep -Fq -- "$2" "$1" || fail "$1 lacks: $2"; }

# The tools still document the codes the prose branches on.
has bin/style-diff.mjs '3 = INCOMPLETE'
has bin/style-diff.mjs '1 = style'
has bin/assets-fresh.mjs 'Exit 1: stale'
has bin/assets-fresh.mjs 'Exit 2: bad usage or an unreadable manifest'

fix=skills/wp-audit-run/references/fix.md
has "$fix" 'Read the exit code, not just non-zero'
has "$fix" '`3` is INCOMPLETE'
has "$fix" 'never read as a diff or as'
has "$fix" '`2` is a usage error or no browser'
if grep -Fq 'a non-zero exit means a style value' "$fix"; then
  fail "$fix still reads any non-zero style-diff exit as a moved value"
fi

upd=commands/wp-update.md
has "$upd" 'Exit `1`'
has "$upd" 'Exit `2` (bad usage or an unreadable manifest) is a tool'
has "$upd" 'never as stale cuts'
if grep -Fq 'A non-zero exit' "$upd"; then
  fail "$upd still reads any non-zero assets-fresh exit as stale cuts"
fi

echo PASS
