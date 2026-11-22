#!/usr/bin/env bash
# A command substitution that runs its own `bash -c "…"` inside an outer `bash -c "…"`
# is silently broken. Inside $( … ) bash re-parses the text as a fresh command, so the
# \" the author wrote to survive the outer quoting arrives as a LITERAL quote character:
# the inner shell gets a malformed first argument, prints
#   -c: line 1: unexpected EOF while looking for matching `"'
# on stderr, and substitutes the empty string. `tail -50 "$(…)/wp-content/debug.log"`
# then reads /wp-content/debug.log and, with 2>/dev/null || echo, exits 0 — a diagnostic
# command that reports on the wrong path without ever saying so.
#
# The inner `bash -c` buys nothing: $WP is a command plus its global arguments, and
# $($WP db prefix) word-splits it correctly on its own. Drop the wrapper and quote the
# expansion at the point of use, which is where a path with a space would otherwise bite.
set -euo pipefail
. "$(dirname "$0")/../lib/assert.sh"
cd "$(dirname "$0")/../.." || exit 1

# Only the escaped-quote form is the bug. `COUNTERPART=$(bash -c "$WP post create …")`
# on its own line is fine — it is not inside an outer double-quoted string, so its quotes
# quote. The gate matches \" specifically, which only appears when the author was already
# escaping for an enclosing "…" and therefore hit the re-parse.
hits=$(grep -rn '\$(bash -c \\"' commands/ agents/ skills/ 2>/dev/null || true)
[ -z "$hits" ] \
  || { echo "FAIL: a command substitution nests its own 'bash -c' — the escaped quotes inside it are literal, so the inner shell fails and the substitution is empty:"; echo "$hits"; exit 1; }

echo "PASS"
