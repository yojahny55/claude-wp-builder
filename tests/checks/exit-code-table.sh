#!/usr/bin/env bash
# Every exit code a bin/*.mjs tool can return is declared in bin/lib/exit-codes.mjs and
# listed in docs/exit-codes.md. Nothing is renumbered: the table documents what the tools
# return today, and a new tool follows COMMON.
#
# What the scan reads (literal numbers only, on lines that are not comments):
#   process.exit(<expr>)            every integer in <expr>, so `fail ? 1 : 3` yields 1 and 3
#   process.exitCode = <expr>       the same, up to the semicolon
#   exitCode = <expr>               the same (a `let exitCode` accumulator, as demo-verify has)
#   die(N, ...)                     a leading integer argument
#   function f(msg, code = N)       the default of a `code` parameter (usage helpers)
#   usage(..., N);                  a trailing integer argument on the call line
#   code = N;                       a plain assignment to a `code` local (process.exit(code) later)
# It scans bin/*.mjs and bin/lib/browsers.mjs (a library that is also a CLI). It also checks the
# reverse: every code TOOLS declares is still returned by some literal exit site, unless listed
# in NOT_LITERAL with its reason.
# What it does NOT read: a code that arrives through a variable or a computed value
# (`process.exit(code)` is covered only through the helper's default and its literal callers),
# a call split over several lines, and uncaught exceptions (Node exits 1 on its own).
# Tools absent from TOOLS may use only COMMON codes.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh
require_tool node

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/scan.mjs" <<'JS'
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

const root = process.env.ROOT;
const mutate = process.env.DROP_TOOL; // negative self-test: forget one TOOLS entry
const { COMMON, TOOLS } = await import(pathToFileURL(join(root, 'bin/lib/exit-codes.mjs')).href);
const tools = { ...TOOLS };
if (mutate) delete tools[mutate];

const nums = (s) => (s.match(/\b\d+\b/g) || []).map(Number);
const codesOf = (src) => {
  const found = new Set();
  const lines = src.split('\n').filter((l) => !/^\s*(\/\/|\*|\/\*)/.test(l));
  for (const line of lines) {
    for (const m of line.matchAll(/process\.exit\(((?:[^()]|\([^()]*\))*)\)/g)) nums(m[1]).forEach((n) => found.add(n));
    for (const m of line.matchAll(/(?:process\.)?exitCode\s*=\s*([^;]+);/g)) nums(m[1]).forEach((n) => found.add(n));
    for (const m of line.matchAll(/\bdie\(\s*(\d+)\s*,/g)) found.add(Number(m[1]));
    for (const m of line.matchAll(/(?<![\w.])code\s*=\s*(\d+)\s*;/g)) found.add(Number(m[1]));
    for (const m of line.matchAll(/function\s+\w+\s*\([^)]*\bcode\s*=\s*(\d+)/g)) found.add(Number(m[1]));
    for (const m of line.matchAll(/\busage\w*\(.*,\s*(\d+)\s*\)\s*;?\s*$/g)) found.add(Number(m[1]));
  }
  return found;
};

const problems = [];
// bin/*.mjs, plus the one bin/lib module that is also a CLI whose exit code commands read.
const LIB_CLIS = ['lib/browsers.mjs'];
const files = [...readdirSync(join(root, 'bin')).filter((f) => f.endsWith('.mjs')).sort(), ...LIB_CLIS];
// Declared codes the scan cannot see as literals, so the reverse check (every declared code
// is still returned somewhere) skips them. Keep this list short and say why for each.
const NOT_LITERAL = {};
const doc = readFileSync(join(root, 'docs/exit-codes.md'), 'utf8');

for (const f of files) {
  const used = codesOf(readFileSync(join(root, 'bin', f), 'utf8'));
  const declared = tools[f] || COMMON;
  for (const c of used) {
    if (!(c in declared)) problems.push(`${f} exits ${c}, which is not declared ${tools[f] ? 'in TOOLS' : 'in COMMON (the tool is absent from TOOLS)'}`);
  }
  // The reverse: a declared code the tool no longer returns makes the table lie.
  if (tools[f]) {
    for (const c of Object.keys(tools[f]).map(Number)) {
      if (c === 0 || used.has(c) || (NOT_LITERAL[f] || []).includes(c)) continue;
      problems.push(`${f}: TOOLS declares ${c}, but no exit site returns it (stale entry, or add it to NOT_LITERAL with the reason)`);
    }
  }
}
for (const t of Object.keys(TOOLS)) {
  if (!files.includes(t)) problems.push(`TOOLS names ${t}, which is not a scanned tool`);
}
for (const t of Object.keys(tools)) {
  const at = doc.indexOf('### `' + t + '`');
  if (at < 0) { problems.push(`docs/exit-codes.md has no section for ${t}`); continue; }
  const rest = doc.slice(at + 1);
  const next = rest.search(/\n#{1,3} /);
  const section = next < 0 ? rest : rest.slice(0, next);
  const listed = [...section.matchAll(/^\|\s*(\d+)\s*\|/gm)].map((m) => Number(m[1]));
  for (const c of Object.keys(tools[t])) if (!listed.includes(Number(c))) problems.push(`docs/exit-codes.md section ${t} does not list code ${c}`);
  for (const c of listed) if (!(c in tools[t])) problems.push(`docs/exit-codes.md section ${t} lists code ${c}, which TOOLS does not declare`);
}
if (problems.length) { console.error(problems.join('\n')); process.exit(1); }
console.log('ok ' + files.length);
JS

ROOT="$PWD" node "$tmp/scan.mjs" >/dev/null || fail "the exit-code table and bin/*.mjs disagree (output above)"

# Self-test 1: an undeclared literal exit in a copy of a tool must fail.
mkdir -p "$tmp/copy/bin/lib" "$tmp/copy/docs"
\cp -f bin/*.mjs "$tmp/copy/bin/"
\cp -f bin/lib/browsers.mjs "$tmp/copy/bin/lib/"
\cp -f bin/lib/exit-codes.mjs "$tmp/copy/bin/lib/"
\cp -f docs/exit-codes.md "$tmp/copy/docs/"
printf '\nif (process.argv.includes("--zz")) process.exit(7);\n' >> "$tmp/copy/bin/css-contour-lint.mjs"
if ROOT="$tmp/copy" node "$tmp/scan.mjs" >/dev/null 2>&1; then
  fail "self-test: an undeclared process.exit(7) was not caught"
fi

# Self-test 2: forgetting a TOOLS entry must fail (the tool then may only use COMMON codes,
# and its doc section is no longer backed by the table).
if ROOT="$PWD" DROP_TOOL=wp-config.mjs node "$tmp/scan.mjs" >/dev/null 2>&1; then
  fail "self-test: removing the wp-config.mjs entry from TOOLS was not caught"
fi
# Self-test 3: a declared code the tool no longer returns must fail (the table would lie).
sed -i 's/process.exitCode = 4;/process.exitCode = 1;/' "$tmp/copy/bin/link-sweep.mjs"
sed -i '/process.argv.includes("--zz")/d' "$tmp/copy/bin/css-contour-lint.mjs"
out3=$(ROOT="$tmp/copy" node "$tmp/scan.mjs" 2>&1) && fail "self-test: link-sweep no longer returning its declared 4 was not caught"
[ "$(grep -Fc 'link-sweep.mjs: TOOLS declares 4, but no exit site returns it' <<<"$out3")" -gt 0 ] \
  || fail "self-test 3 failed for another reason than the stale declared 4: $out3"
echo PASS
