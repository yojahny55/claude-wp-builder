#!/usr/bin/env bash
# /wp-status is read-only and answers "what runs next" from files alone. One fixture per
# rule a-l pins the next command; the rest pin that it never crashes, never writes, and
# rejects bad usage.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh
require_tool node

tool=bin/wp-status.mjs
fx=$PWD/tests/fixtures/manifests/valid/.wp-create.json
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

need_token commands/wp-status.md 'allowed-tools: Bash, Read' "wp-status must stay Bash, Read only"
need_token commands/wp-status.md 'Read-only' "wp-status must say it is read-only"
need_token commands/wp-status.md 'Never run it on your own' "wp-status must not run the next command itself"

# mk <name> [flags...]: build a project in $tmp/<name>. Flags: manifest adopted bad claude html failed
# build-open build-done verify ledger-empty ledger-open ledger-clean
mk() {
  local d=$tmp/$1; shift; mkdir -p "$d"
  local f
  for f in "$@"; do
    case $f in
      manifest) \cp -f "$fx" "$d/.wp-create.json" ;;
      adopted) node -e '
        const fs=require("fs");const m=JSON.parse(fs.readFileSync(process.argv[1]));m.origin="adopted";m.project.prefix="fx";m.code_scope={editable:["wp-content/themes/fixture-site"],read_only:[]};
        fs.writeFileSync(process.argv[2],JSON.stringify(m))' "$fx" "$d/.wp-create.json" ;;
      bad) printf '{ not json' >"$d/.wp-create.json" ;;
      invalid) printf '{"manifest_version":3}' >"$d/.wp-create.json" ;;
      claude) mkdir -p "$d/.claude"; echo x >"$d/.claude/CLAUDE.md" ;;
      html) mkdir -p "$d/demo"; echo '<html></html>' >"$d/demo/index.html" ;;
      failed) mkdir -p "$d/demo"; printf 'demo failed\nreason\n' >"$d/demo/FAILED.md" ;;
      build-open) echo '{"version":2,"completed":null,"units":[{"id":"header"}]}' >"$d/demo/.yolo-progress.json" ;;
      build-done) echo '{"version":2,"completed":"2026-01-01T00:00:00Z","units":[{"id":"header"}]}' >"$d/demo/.yolo-progress.json" ;;
      verify) echo ok >"$d/demo/VERIFY.md" ;;
      ledger-empty) : ;;
      ledger-open) echo '{"ledger_version":1,"findings":[{"check":"SEC-001","resource":"a","status":"new"},{"check":"SEC-002","resource":"b","status":"resolved"}]}' >"$d/.wp-audit-findings.json" ;;
      ledger-clean) echo '{"ledger_version":1,"findings":[{"check":"SEC-001","resource":"a","status":"resolved"},{"check":"SEC-002","resource":"b","status":"accepted"}]}' >"$d/.wp-audit-findings.json" ;;
    esac
  done
}

# next <name>: prints next.command ("null" when nothing pending); asserts exit 0.
next() {
  local out
  out=$(node "$tool" "$tmp/$1" --json) || fail "$1: exit $?, want 0"
  node -e 'const r=JSON.parse(process.argv[1]);console.log(r.next.command===null?"null":r.next.command)' "$out"
}
expect() { # expect <name> <substring>
  local got; got=$(next "$1")
  case $got in *"$2"*) ;; *) fail "$1: next was '$got', want it to contain '$2'" ;; esac
}

mk a
mk b bad;                                   expect b 'wp-config.mjs validate'
mk b2 invalid;                              expect b2 'wp-config.mjs validate'
mk c adopted;                               expect c '/wp-audit'
mk c2 adopted ledger-clean;                 [ "$(next c2)" = null ] || fail "c2: adopted with a clean ledger must have nothing pending"
mk d manifest;                              expect d '/wp-init'
mk e manifest claude html failed;           expect e '/wp-demo'
mk f manifest claude;                       expect f '/wp-demo'
mk g manifest claude html;                  expect g '/wp-yolo demo/'
mk h manifest claude html build-open;       expect h '--resume'
mk i manifest claude html build-done;       expect i '/wp-finalize'
mk j manifest claude html build-done verify; expect j '/wp-audit'
mk k manifest claude html build-done verify ledger-open; expect k '/wp-audit'
mk l manifest claude html build-done verify ledger-clean; [ "$(next l)" = null ] || fail "l: nothing must be pending"
expect a '/wp-create'

# rule e shows the first lines of FAILED.md
node "$tool" "$tmp/e" | grep >/dev/null -c 'demo failed' || fail "FAILED.md lines are not shown"
# rule k reports counts
node "$tool" "$tmp/k" | grep >/dev/null -c '1 new' || fail "audit counts missing"

# unreadable ledgers are a state, never a crash
mk u manifest claude html build-done verify; echo '{ nope' >"$tmp/u/.wp-audit-findings.json"
echo '{ nope' >"$tmp/u/demo/.yolo-progress.json"
node "$tool" "$tmp/u" --json >/dev/null || fail "unreadable ledgers crashed the tool"

# usage
set +e
node "$tool" --nope >/dev/null 2>&1; [ $? = 64 ] || { set -e; fail "unknown flag must exit 64"; }
node "$tool" "$tmp/does-not-exist" >/dev/null 2>&1; [ $? = 64 ] || { set -e; fail "a non-directory must exit 64"; }
node "$tool" --help >/dev/null 2>&1; [ $? = 0 ] || { set -e; fail "--help must exit 0"; }
set -e

# read-only: the tree (names and hashes) is identical before and after
snap() { (cd "$tmp/k" && find . -type f -print0 | sort -z | xargs -0 sha256sum; find . -type d | sort); }
before=$(snap)
node "$tool" "$tmp/k" >/dev/null; node "$tool" "$tmp/k" --json >/dev/null
[ "$before" = "$(snap)" ] || fail "wp-status modified the project tree"

echo PASS
