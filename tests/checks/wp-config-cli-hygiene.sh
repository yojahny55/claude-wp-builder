#!/usr/bin/env bash
# wp-config.mjs / manifest.mjs edge cases: a root with a space, a symlinked root in git-init,
# credentials in --remote, a silent type change in `set`, `-->` and CRLF in CLAUDE.md, and the
# lock on every manifest read-modify-write.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cfg="node bin/wp-config.mjs"

# --- CORE-02: the detected wrapper keeps a root with a space as one argument. ---
w=$(node --input-type=module -e "import('./bin/lib/adopt.mjs').then(m=>{const r=m.detectWrapper(process.argv[1]);console.log(r.wrapper);console.log(JSON.stringify(m.splitWords(r.wrapper)))})" "$tmp/a b")
[ "$(printf '%s\n' "$w" | sed -n 2p)" = "[\"wp\",\"--path=$tmp/a b\"]" ] || fail "wrapper for a root with a space did not split into two words: $w"
plain=$(node --input-type=module -e "import('./bin/lib/adopt.mjs').then(m=>console.log(m.detectWrapper('/srv/x').wrapper))")
[ "$plain" = "wp --path=/srv/x" ] || fail "a plain root changed its stored wrapper: $plain"

# --- CORE-04 / CORE-05: git-init through a symlinked root, credentials never printed. ---
mkdir "$tmp/real"; ln -s "$tmp/real" "$tmp/link"
url="https://user:SECRETTOKEN@host.example/r.git"
out=$($cfg git-init "$tmp/link" --branch=main --remote="$url" 2>&1) || fail "git-init plan failed: $out"
case "$out" in *SECRETTOKEN*) fail "git-init printed the credential";; esac
echo x > "$tmp/real/index.php"
$cfg git-init "$tmp/link" --branch=main --remote="$url" --commit >"$tmp/c" 2>&1 || fail "commit through a symlinked root refused: $(cat "$tmp/c")"
$cfg git-init "$tmp/link" --branch=main --remote="$url" --push >"$tmp/pushout" 2>&1 && fail "push without --yes did not refuse"
grep >/dev/null -c SECRETTOKEN "$tmp/pushout" && fail "the push preview printed the credential"
git -C "$tmp/real" remote get-url origin | grep >/dev/null -c SECRETTOKEN || fail "origin lost its configured URL"

# --- CORE-07: a type change by `set` is announced. ---
cp -r tests/fixtures/manifests/valid "$tmp/p"
$cfg set "$tmp/p" environment.php_version 83 >"$tmp/o" 2>&1 || fail "set failed"
grep >/dev/null -c "now a number" "$tmp/o" || fail "set changed string to number silently: $(cat "$tmp/o")"

# --- CORE-08 / CORE-09: `-->` in a superseded line, CRLF in the generated block. ---
node --input-type=module -e "
import fs from 'node:fs';
import { renderContext, supersedeProseDecisions, contextDrift } from './bin/lib/manifest.mjs';
const man = JSON.parse(fs.readFileSync('tests/fixtures/manifests/valid/.wp-create.json','utf8'));
const out = supersedeProseDecisions('- **i18n strategy:** x --> y\nafter', man);
if ((out.match(/-->/g) || []).length !== 1) { console.log('FAIL: comment closed early: ' + out); process.exit(1); }
const crlf = renderContext(man).replace(/\n/g, '\r\n');
if (contextDrift(crlf, man) !== null) { console.log('FAIL: CRLF block reports drift'); process.exit(1); }
" || exit 1

# --- CORE-15: keep-inactive, remove-plugin, env-set and code-home hold the lock. ---
n=$(grep -c "locked(target, () => cmd" bin/wp-config.mjs)
[ "$n" -ge 5 ] || fail "only $n locked dispatches, want migrate/keep-inactive/remove-plugin/code-home/env-set"
mkdir "$tmp/p/.wp-create.json.lock"
touch -d '5 seconds ago' "$tmp/p/.wp-create.json.lock"
( sleep 1; rmdir "$tmp/p/.wp-create.json.lock" ) &
start=$(date +%s%N)
$cfg env-set "$tmp/p" --name=stg --role=staging --url=https://stg.example.test >/dev/null 2>&1 || fail "env-set failed"
wait
elapsed=$(( ($(date +%s%N) - start) / 1000000 ))
[ "$elapsed" -ge 800 ] || fail "env-set did not wait for a held lock (${elapsed} ms)"
[ ! -e "$tmp/p/.wp-create.json.lock" ] || fail "env-set left the lock behind"
$cfg keep-inactive "$tmp/p" bad_slug! >/dev/null 2>&1 && fail "bad slug accepted"
[ ! -e "$tmp/p/.wp-create.json.lock" ] || fail "a refused locked command orphaned the lock"
echo PASS
