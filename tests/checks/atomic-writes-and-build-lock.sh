#!/usr/bin/env bash
# Two shared files had writers that could race:
#  - .wp-create.json was rewritten with a bare writeFileSync by migrate, adopt and refresh,
#    and wp-research edited it freehand, so parallel builders (/wp-yolo) could read a torn
#    file or silently drop each other's keys. Writes now go tmp + rename, and `set` is the
#    one locked, validated way to change a key.
#  - bin/tailwind-rebuild.sh removed its flock file after building. flock locks the inode,
#    so a third process opening the path at the wrong moment held a lock on an unlinked
#    inode while a fourth created a fresh file: two compiles ran at once. The file is now
#    never deleted, the wait and the implicit npm install are bounded.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# --- static pins (both directions) ---
! grep -q 'writeFileSync(file' bin/wp-config.mjs || fail "wp-config.mjs writes the manifest with a bare writeFileSync"
grep -Fq 'renameSync(tmp, file)' bin/wp-config.mjs || fail "wp-config.mjs has no tmp + rename write"
grep -Fq "cmd === 'set'" bin/wp-config.mjs || fail "wp-config.mjs has no set subcommand"
grep -Fq 'wp-config.mjs set' agents/wp-research.md || fail "wp-research does not write the manifest through wp-config.mjs set"
grep -Fq 'never with Edit or Write' agents/wp-research.md || fail "wp-research may still edit the manifest freehand"
! grep -Eq '^\s*rm -f "\$lock"' bin/tailwind-rebuild.sh || fail "tailwind-rebuild.sh deletes its lock file (flock + rm race)"
grep -Eq 'flock -w' bin/tailwind-rebuild.sh || fail "tailwind-rebuild.sh waits for the lock without a timeout"
grep -Fq 'timeout "' bin/tailwind-rebuild.sh || fail "tailwind-rebuild.sh runs npm install with no timeout"
grep -Fq '.tailwind-rebuild.lock' commands/wp-init.md || fail "wp-init does not gitignore the rebuild lock"

# --- behavior: set ---
proj="$tmp/p"; mkdir -p "$proj"
cp tests/fixtures/manifests/valid/.wp-create.json "$proj/"
node bin/wp-config.mjs validate "$proj" >/dev/null || fail "fixture manifest does not validate"
node bin/wp-config.mjs set "$proj" research '{"confidence":"unconfirmed","tier":"websearch","competitors":2}' >/dev/null || fail "set refused a research record"
[ "$(node bin/wp-config.mjs get "$proj" research.competitors)" = 2 ] || fail "set did not store a JSON object"
node bin/wp-config.mjs set "$proj" research none >/dev/null || fail "set refused the scalar none"
[ "$(node -p "require('$proj/.wp-create.json').research")" = none ] || fail "set did not store a plain string"
node bin/wp-config.mjs set "$proj" database.password x >/dev/null 2>&1 && fail "set accepted a secret path"
node bin/wp-config.mjs set "$proj" __proto__.x 1 >/dev/null 2>&1 && fail "set accepted a prototype key"
node bin/wp-config.mjs set "$proj" environments 5 >/dev/null 2>&1 && fail "set accepted an invalid environments value"
ls -A "$proj" | grep -E '\.tmp$|\.lock$' && fail "set left a temp or lock file behind"

# --- behavior: parallel sets lose no key and never leave invalid JSON ---
pids=()
for i in 1 2 3 4 5 6 7 8; do
  node bin/wp-config.mjs set "$proj" "extra_$i" "$i" >"$tmp/set_$i.log" 2>&1 &
  pids+=("$!")
done
for pid in "${pids[@]}"; do
  wait "$pid" || fail "a parallel set exited non-zero (lock timeout?): $(cat "$tmp"/set_*.log | head -3)"
done
for i in 1 2 3 4 5 6 7 8; do
  [ "$(node -p "require('$proj/.wp-create.json').extra_$i")" = "$i" ] || fail "parallel set lost extra_$i"
done
node bin/wp-config.mjs validate "$proj" >/dev/null || fail "manifest invalid after parallel sets"

# --- behavior: the build lock survives its holder and serializes builders ---
t="$tmp/t"; mkdir -p "$t/assets/css/src/tailwindcss" "$t/node_modules" "$tmp/fb"
echo '{}' > "$t/package.json"
cat > "$tmp/fb/npm" <<NPM
#!/usr/bin/env bash
mkdir "$tmp/inuse" 2>/dev/null || echo OVERLAP >> "$tmp/overlap"
echo RAN >> "$tmp/ran"
sleep 0.3
rmdir "$tmp/inuse" 2>/dev/null || true
NPM
printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/fb/pgrep"
chmod +x "$tmp/fb/npm" "$tmp/fb/pgrep"
if command -v flock >/dev/null 2>&1; then
  for i in 1 2 3 4; do PATH="$tmp/fb:$PATH" bash bin/tailwind-rebuild.sh "$t" >/dev/null 2>&1 & done
  wait
  [ -s "$tmp/ran" ] || fail "no build ran at all, so the overlap check below proves nothing"
  [ ! -e "$tmp/overlap" ] || fail "two builds ran at once"
  [ -e "$t/.tailwind-rebuild.lock" ] || fail "tailwind-rebuild.sh removed its lock file"
else
  echo "note: flock absent, skipped the lock behavior half" >&2
fi

echo PASS
