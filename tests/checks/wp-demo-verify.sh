#!/usr/bin/env bash
# A scroll page has no single state: every scroll position is a different frame and the
# failures live between the two anyone happened to look at. This check pins the contract
# that makes the walk trustworthy, including the part a green run cannot cover, which is
# why "read the sheet" is asserted as hard as the machine findings.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

c=commands/wp-demo-verify.md
s=bin/demo-verify.mjs
r=commands/wp-responsive-check.md

[ -f "$c" ] || fail "$c is missing"
[ -f "$s" ] || fail "$s is missing"
[ -x "$s" ] || fail "$s is not executable"

awk 'NR<=8 && /^argument-hint:/ { f = 1 } END { exit !f }' "$c" || fail "$c has no argument-hint"
awk 'NR<=8 && /^allowed-tools:/ { f = 1 } END { exit !f }' "$c" || fail "$c has no allowed-tools"

# --- It must accept a live URL, or it can never verify the converted theme. --
grep -Eqi 'url' "$c" || fail "$c does not accept a URL as well as a file path"

# --- The walk. Uniform sampling moves every position when any section resizes,
#     so findings would appear and vanish with unrelated edits.
grep -Eqi 'per section|positions per' "$c" || fail "$c does not sample per section"
grep -Fq '390' "$c" || fail "$c does not walk a phone width"
grep -Fq '1440' "$c" || fail "$c does not walk a desktop width"
grep -Eqi 'reduced.motion' "$c" || fail "$c does not run a reduced-motion pass"

# --- Responsive coverage moved here, so the old viewports must still be walked.
for v in 375 576 768 1024; do
  grep -Fq "$v" "$c" || fail "$c dropped the $v viewport that /wp-responsive-check covered"
done

# --- The findings the machine can actually make. ----------------------------
grep -Eqi 'dead scroll' "$c" || fail "$c does not report dead scroll"
grep -Eqi 'overflow' "$c" || fail "$c does not report horizontal overflow"
grep -Eqi 'never reach|never peak' "$c" || fail "$c does not report cues that never reach full opacity"

# --- The half a machine cannot do. ------------------------------------------
grep -Fq 'sheet.png' "$c" || fail "$c does not produce a contact sheet"
grep -Eqi 'feel check' "$c" || fail "$c does not require the feel check"
grep -Eqi 'not a pass' "$c" || fail "$c does not state that a green run alone is not a pass"

# --- Fallbacks, in order, so a machine without Chrome still gets a review. ---
grep -Eqi 'exit code 2|exits 2' "$c" || fail "$c does not document the no-browser exit code"
grep -Eqi 'playwright|chrome' "$c" || fail "$c does not name the browser fallback ladder"

# --- The script's own contract. ---------------------------------------------
grep -Fq 'playwright-core' "$s" || fail "$s does not use playwright-core"
grep -Fq -- '--motion-p' "$s" || fail "$s does not read --motion-p when detecting dead scroll"
grep -Fq 'process.exit(2)' "$s" || fail "$s does not exit 2 when no browser is available"
node --check "$s" || fail "$s is not valid JavaScript"

# --- The five legacy viewports must be IMPLEMENTED, not just promised in prose.
#     A grep-gate that only greps the markdown proves the promise was written,
#     not that it was kept: this asserts the script itself writes the shots.
grep -Fq 'responsive-' "$s" || fail "$s does not write responsive-<width>.png files"
grep -Fq 'fullPage: true' "$s" || fail "$s does not take a full-page screenshot"
for v in 375 576 768 1024 1440; do
  grep -Fq "$v" "$s" || fail "$s does not implement the $v viewport (docs promise it, code must too)"
done

# --- The alias. The old command keeps working or every existing doc breaks. --
grep -Fq '/wp-demo-verify' "$r" || fail "$r does not dispatch to /wp-demo-verify"

# --- The craft gate. A build that cannot render cannot be verified, so the
#     script must answer "can you render?" without walking anything.
grep -Fq -- '--probe' "$s" || fail "$s has no --probe mode"
grep -Fq -- '--probe' "$c" || fail "$c does not document --probe"
grep -Fq 'PLAYWRIGHT_CORE' "$s" || fail "$s does not honour PLAYWRIGHT_CORE (needed to test the no-browser path)"
grep -Fq 'process.cwd()' "$s" || fail "$s cannot resolve playwright-core from the project it is run in"
# Runnable: forcing playwright-core to a bogus path must exit 2, not crash.
set +e
PLAYWRIGHT_CORE=/nonexistent/playwright-core node "$s" --probe >/dev/null 2>&1
code=$?
set -e
[ "$code" -eq 2 ] || fail "$s --probe with a bogus PLAYWRIGHT_CORE exited $code, expected 2"

# --- Every page, not only the index. Interior pages were where the last
#     failed build was emptiest.
grep -Eqi 'directory|every \*?\.html|each page' "$c" || fail "$c does not walk a directory of pages"
grep -Fq 'readdirSync' "$s" || fail "$s cannot enumerate a directory target"
grep -Fq 'pages' "$s" || fail "$s findings.json does not carry per-page results"

# --- The demo server's path containment, run rather than grepped. The page
#     under test is untrusted markup and this server has the whole filesystem
#     within reach of one join(); a symlink inside the root and a Windows
#     drive-absolute path both escaped it. The pins in wp-craft-detect.sh say
#     the lines are present, which is not the same claim as "an escape 404s
#     and a real file still 200s" — a containment fix that breaks serving is
#     worse than the hole. serve() is lifted verbatim out of the script, so
#     this exercises the shipped text and not a re-implementation.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/root/assets"
echo '<!doctype html><p>ok</p>' > "$work/root/index.html"
echo 'body{}' > "$work/root/assets/a.css"
echo 'SECRET' > "$work/secret.txt"
ln -s "$work/secret.txt" "$work/root/escape.txt"
node - "$s" "$work/root" <<'JS' > "$work/out" 2>&1 || fail "the serve() containment battery crashed: $(cat "$work/out")"
import { readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const [script, root] = process.argv.slice(2);
const src = readFileSync(script, 'utf8');
const start = src.indexOf('const serve = (root)');
const end = src.indexOf('\n});\n', start) + 5;
if (start < 0 || end < start + 200) throw new Error('could not lift serve() out of ' + script);
const mod = join(tmpdir(), 'serve-harness-' + process.pid + '.mjs');
writeFileSync(mod,
  "import { statSync, createReadStream, realpathSync } from 'node:fs';\n" +
  "import { resolve, join, extname, normalize, sep } from 'node:path';\n" +
  "import { createServer } from 'node:http';\n" +
  'const MIME = {};\n' + src.slice(start, end) + '\nexport { serve };\n');
const { serve } = await import('file://' + mod);
const { server, port } = await serve(root);
const get = async (p) => (await fetch('http://127.0.0.1:' + port + p)).status;
const cases = [
  ['/../etc/passwd', 404], ['/%2e%2e/%2e%2e/etc/passwd', 404], ['/..%2f..%2fetc/passwd', 404],
  ['/assets/../../etc/passwd', 404], ['/....//....//etc/passwd', 404], ['/index.html%00.png', 404],
  ['/C:/Windows/win.ini', 404], ['/..%5c..%5cWindows/win.ini', 404],
  ['/escape.txt', 404], ['/', 403], ['/index.html', 200], ['/assets/a.css', 200],
  ['/nope.html', 404], ['/%', 400],
];
let bad = 0;
for (const [p, want] of cases) {
  const got = await get(p);
  if (got !== want) { console.log('MISMATCH ' + p + ' expected ' + want + ' got ' + got); bad++; }
}
server.close();
console.log(bad === 0 ? 'CONTAINMENT OK' : 'CONTAINMENT FAILED');
JS
grep -Fq 'CONTAINMENT OK' "$work/out" \
  || fail "$s serves outside its root, or no longer serves inside it: $(cat "$work/out")"

echo PASS
