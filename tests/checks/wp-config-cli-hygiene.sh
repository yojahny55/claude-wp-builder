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
# A path with an apostrophe is stored as '...'\''...' and must come back intact.
apos=$(node --input-type=module -e "import('./bin/lib/adopt.mjs').then(m=>{const p=process.argv[1];const w=m.splitWords(m.detectWrapper(p).wrapper);console.log(w.length===2&&w[1]==='--path='+p?'ok':JSON.stringify(w))})" "$tmp/it's a b")
[ "$apos" = ok ] || fail "a root with an apostrophe did not round-trip through the wrapper: $apos"
plain=$(node --input-type=module -e "import('./bin/lib/adopt.mjs').then(m=>console.log(m.detectWrapper('/srv/x').wrapper))")
[ "$plain" = "wp --path=/srv/x" ] || fail "a plain root changed its stored wrapper: $plain"

# --- CORE-04 / CORE-05: git-init through a symlinked root, credentials never printed. ---
mkdir "$tmp/real"; ln -s "$tmp/real" "$tmp/link"
url="https://user:SECRETTOKEN@host.example/r.git"
out=$($cfg git-init "$tmp/link" --branch=main --remote="$url" 2>&1) || fail "git-init plan failed: $out"
case "$out" in *SECRETTOKEN*) fail "git-init printed the credential";; esac
mkdir "$tmp/at"; out=$($cfg git-init "$tmp/at" --branch=main --remote="https://user:p@SECRETTOKEN@host.example/r.git" --dry-run 2>&1) || fail "git-init plan with @ in the password failed: $out"
case "$out" in *SECRETTOKEN*) fail "git-init printed the part of a password after a raw @";; esac
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

# --- CORE-15: keep-inactive, remove-plugin, env-set, migrate and code-home's write hold the lock. ---
n=$(grep -c "locked(target, () => cmd" bin/wp-config.mjs)
[ "$n" -ge 4 ] || fail "only $n locked dispatches, want migrate/keep-inactive/remove-plugin/env-set"
# code-home locks only its write: its WP-CLI probe (up to two minutes) must run unlocked, or
# a writer waiting on it would break the lock as stale after 30 s.
cp -r tests/fixtures/manifests/valid "$tmp/ch"
cat >"$tmp/fakewp" <<EOS
#!/usr/bin/env bash
if [ -e "$tmp/ch/.wp-create.json.lock" ]; then echo locked >"$tmp/probe-saw"; else echo free >"$tmp/probe-saw"; fi
exit 1
EOS
chmod +x "$tmp/fakewp"
node --input-type=module -e "
import fs from 'node:fs';
const f = process.argv[1]; const m = JSON.parse(fs.readFileSync(f, 'utf8'));
m.wp_cli.wrapper = process.argv[2]; fs.writeFileSync(f, JSON.stringify(m, null, 2));
" "$tmp/ch/.wp-create.json" "$tmp/fakewp"
$cfg code-home "$tmp/ch" --kind=mu-plugin >/dev/null 2>&1 && fail "code-home with a failing probe did not refuse"
[ "$(cat "$tmp/probe-saw" 2>/dev/null)" = free ] || fail "code-home ran its probe while holding the manifest lock"
[ ! -e "$tmp/ch/.wp-create.json.lock" ] || fail "code-home left the lock behind"
grep >/dev/null -c 'const next = withLock(file' bin/wp-config.mjs || fail "code-home no longer locks its read-modify-write"
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
# A locked command on a path that does not exist exits 3 with the usual message, no stack trace.
set +e; $cfg keep-inactive "$tmp/missing/x" foo >"$tmp/miss" 2>&1; rc=$?; set -e
[ "$rc" = 3 ] || fail "a locked command on a missing project exited $rc, want 3: $(cat "$tmp/miss")"
grep >/dev/null -c 'run /wp-create first' "$tmp/miss" || fail "missing-project message lost: $(cat "$tmp/miss")"
echo PASS
