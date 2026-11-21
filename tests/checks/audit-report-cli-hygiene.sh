#!/usr/bin/env bash
# bin/audit-report.mjs and bin/audit-runbook.mjs input hygiene:
#   - a data-supplied key (a category named `constructor`) never reads the prototype chain;
#   - --help exits 0, and --flag=value accepts a value that starts with `--`;
#   - archiving an earlier same-day run is all or nothing;
#   - a malformed manifest aborts the runbook, and a relative audit.out_dir is the site root's.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
repo=$(pwd)
rep="$repo/bin/audit-report.mjs"
rbk="$repo/bin/audit-runbook.mjs"
command -v node >/dev/null || { echo "SKIP: node not found"; exit 0; }

tmp=$(mktemp -d)
trap 'chmod -R u+rwx "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT

# --- 1. prototype keys ---------------------------------------------------------------------
cat > "$tmp/run.json" <<'JSON'
{"findings":[{"check":"X-1","severity":"WARNING","category":"constructor","title":"t","message":"m","ownership":"code","page":"/","evidence":"e","fix":"f"},
             {"check":"X-2","severity":"INFO","category":"hasOwnProperty","title":"t","message":"m","ownership":"code","page":"/","evidence":"e","fix":"f"}]}
JSON
mkdir -p "$tmp/s1"
node "$rep" --run "$tmp/run.json" --out "$tmp/o1" --site-root "$tmp/s1" --date 2026-01-02 >/dev/null 2>"$tmp/err1" || true
html=$(cat "$tmp/o1"/informe-2026-01-02.html 2>/dev/null) || fail "report not rendered: $(cat "$tmp/err1")"
case "$html" in *"native code"*) fail "a category named constructor rendered function source" ;; esac

# --- 2. --help and --flag=value ------------------------------------------------------------
out=$(node "$rep" --help) || fail "--help exited non-zero"
grep >/dev/null -c "usage: audit-report" <<<"$out" || fail "--help printed no usage"
mkdir -p "$tmp/s2"
(cd "$tmp/s2" && node "$rep" --run="$tmp/run.json" --out=--dash-out --format=md --date=2026-01-02 >/dev/null 2>&1) \
  || fail "--flag=value was refused"
[ -f "$tmp/s2/--dash-out/informe-2026-01-02.md" ] || fail "--out=--dash-out did not take the value"
if node "$rep" --run "$tmp/run.json" --out --format md >/dev/null 2>&1; then fail "a bare flag as value must still be refused"; fi
if node "$rep" --summary=1 >/dev/null 2>&1; then fail "a switch with =value must stay unknown"; fi

# --- 3. archiveSameDay is all or nothing ---------------------------------------------------
o3="$tmp/o3"
mkdir -p "$o3/informe-2026-01-02-0304.html/keep"   # a non-empty directory the html cannot be renamed onto
for ext in json md html; do echo "old $ext" > "$o3/informe-2026-01-02.$ext"; done
echo '{"findings":[]}' > "$o3/informe-2026-01-02.json"
touch -d '2026-01-02 03:04' "$o3/informe-2026-01-02.json"
if node "$rep" --run "$tmp/run.json" --out "$o3" --site-root "$tmp/s1" --date 2026-01-02 >/dev/null 2>"$tmp/err3"; then
  fail "a failed archive rename must abort the run"
fi
for ext in json md html; do [ -f "$o3/informe-2026-01-02.$ext" ] || fail "informe-2026-01-02.$ext was lost"; done
[ ! -e "$o3/informe-2026-01-02-0304.json" ] && [ ! -e "$o3/informe-2026-01-02-0304.md" ] \
  || fail "archive left a partial trio under the new name"

# --- 4. runbook manifest -------------------------------------------------------------------
site="$tmp/site"
mkdir -p "$site/audit-out"
cat > "$site/audit-out/replay.json" <<'JSON'
{ "replay_version": 1, "entries": [
  { "check": "PERF-030", "kind": "post-deploy", "command": "wp media regenerate --only-missing --yes",
    "applied_in": "local", "applied_on": { "local": true, "prod": false } } ] }
JSON
echo '{ "audit": { "out_dir": "audit-out" }' > "$site/.wp-create.json"   # missing closing brace
if (cd "$tmp" && node "$rbk" --root "$site" --date 2026-01-02 >/dev/null 2>"$tmp/err4"); then
  fail "a malformed manifest must abort the runbook"
fi
grep >/dev/null -c "not valid JSON" "$tmp/err4" || fail "no message naming the malformed manifest: $(cat "$tmp/err4")"
echo '{ "audit": { "out_dir": "audit-out" } }' > "$site/.wp-create.json"
(cd "$tmp" && node "$rbk" --root "$site" --date 2026-01-02 >/dev/null 2>"$tmp/err5") \
  || fail "a relative audit.out_dir must resolve against --root: $(cat "$tmp/err5")"
[ -f "$site/audit-out/runbook-2026-01-02.md" ] || fail "runbook not written under the site root's out_dir"
# The report resolves the same relative out_dir against --site-root, so both tools meet.
(cd "$tmp" && node "$rep" --run "$tmp/run.json" --site-root "$site" --format md --date 2026-01-03 >/dev/null 2>"$tmp/err6") \
  || fail "report with a relative audit.out_dir failed: $(cat "$tmp/err6")"
[ -f "$site/audit-out/informe-2026-01-03.md" ] || fail "report did not write under the site root's out_dir"

echo PASS
