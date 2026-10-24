#!/usr/bin/env bash
# The project path must reach `bash -c` as a positional argument, never interpolated into
# the -c string: a path with a single quote, $() or spaces would otherwise break the
# quoting or run as shell. Two halves: no site interpolates it any more, and every
# wp-config.mjs call, run for real with a hostile path, hands the script that exact path.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# 1. Static: no `bash -c "...wp-config.mjs ... '${PROJECT_PATH}'..."` left.
if grep -rnE "bash -c \"node [^\"]*wp-config\.mjs[^\"]*PROJECT_PATH" commands skills >"$tmp/hits"; then
  fail "wp-config.mjs call still interpolates the path into a bash -c string:
$(cat "$tmp/hits")"
fi

# 2. Behavioral: a stub wp-config.mjs records its argv, one per line.
mkdir -p "$tmp/plugin/bin"
cat >"$tmp/plugin/bin/wp-config.mjs" <<'JS'
import { writeFileSync } from 'node:fs';
writeFileSync(process.env.ARGV_OUT, process.argv.slice(2).join('\n') + '\n');
JS
hostile="$tmp/it's \$(touch $tmp/PWNED) a \`touch $tmp/PWNED2\`; dir"
# Single-quote it the way the gate block tells the reader to: each ' becomes '\''
quoted="'${hostile//\'/\'\\\'\'}'"

n=0
while IFS= read -r line; do
  line=${line%\\}
  cmd=${line//\$\{CLAUDE_PLUGIN_ROOT\}/$tmp/plugin}
  cmd=${cmd//\'\$\{PROJECT_PATH\}\'/$quoted}
  rm -f "$tmp/argv"
  ARGV_OUT="$tmp/argv" bash -c "$cmd" >/dev/null 2>&1 || true
  [ ! -e "$tmp/PWNED" ] && [ ! -e "$tmp/PWNED2" ] || fail "hostile path executed: $line"
  [ "$(sed -n 2p "$tmp/argv")" = "$hostile" ] \
    || fail "script did not receive the path intact: $line (got: $(sed -n 2p "$tmp/argv"))"
  n=$((n + 1))
done < <(grep -rhE "^bash -c 'node \"\\\$1/bin/wp-config\.mjs\" [a-z-]+ \"\\\$2\"[^']*' _ " commands skills | sort -u)
[ "$n" -ge 3 ] || fail "only $n wp-config.mjs call shapes exercised"

echo PASS
