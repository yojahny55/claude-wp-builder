#!/usr/bin/env bash
# Every bin/*.mjs tool makes stdout and stderr blocking (bin/lib/stdio-blocking.mjs), so a
# process.exit() right after a large write cannot drop what a pipe has not taken yet.
#
# Without it, `tool | reader` gets the first 64 KiB and the tool still exits with its code:
# css-contour-lint.mjs with a thousand findings delivered 272 of 1001 lines, the summary
# line among the lost ones. Three parts: the import is in every tool, the module itself
# carries more than 64 KiB through a slow pipe, and a real tool does too.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh
require_tool node

lib=bin/lib/stdio-blocking.mjs
[ -f "$lib" ] || fail "$lib is missing"

# --- 1. every tool imports it -------------------------------------------------------------
for f in bin/*.mjs; do
  grep >/dev/null -cE "^import '\./lib/stdio-blocking\.mjs';$" "$f" \
    || fail "$f must import './lib/stdio-blocking.mjs' (process.exit() after a large write to a pipe drops output)"
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# A reader that starts late, so the writer cannot drain the pipe as it goes.
slow_count() { sleep 0.5; wc -c; }

# --- 2. the module, on both streams --------------------------------------------------------
abs_lib="$(pwd)/$lib"
cat > "$tmp/with.mjs" <<EOF
import '$abs_lib';
const s = process.argv[2] === 'err' ? process.stderr : process.stdout;
s.write('x'.repeat(1 << 20));
process.exit(0);
EOF
sed 1d "$tmp/with.mjs" > "$tmp/without.mjs"

out=$(node "$tmp/with.mjs" out | slow_count | tr -d ' ')
[ "$out" = 1048576 ] || fail "stdout through a slow pipe must carry 1048576 bytes with $lib, got $out"
err=$( { node "$tmp/with.mjs" err 2>&1 >/dev/null; } | slow_count | tr -d ' ')
[ "$err" = 1048576 ] || fail "stderr through a slow pipe must carry 1048576 bytes with $lib, got $err"

# The control: without the module the same script must lose output, or this check measures
# nothing (a Node that made pipes blocking by itself would make the module redundant, not wrong).
ctl=$(node "$tmp/without.mjs" out | slow_count | tr -d ' ')
[ "$ctl" -lt 1048576 ] \
  || printf 'NOTE: without %s this Node delivered the whole write; the control did not bite\n' "$lib"

# --- 3. a real tool: css-contour-lint exits 1 right after printing its findings ------------
mkdir "$tmp/site"
for i in $(seq 1 1000); do printf '<input type="search" name="q">\n' > "$tmp/site/p$i.html"; done
set +e
lines=$(node bin/css-contour-lint.mjs "$tmp/site" | { sleep 0.5; wc -l; })
set -e
lines=$(printf '%s' "$lines" | tr -d ' ')
[ "$lines" = 1001 ] \
  || fail "css-contour-lint.mjs through a slow pipe must print 1000 findings and the summary (1001 lines), got $lines"

echo PASS
