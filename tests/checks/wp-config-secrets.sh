#!/usr/bin/env bash
# /wp-init writes the project .gitignore as node_modules/, .DS_Store, *.log -- so before
# this split the manifest, database password included, was committable into a client's
# repository by default. The manifest rung still resolves, for projects that have not
# migrated, but it announces itself as legacy every time.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

cfg="node bin/wp-config.mjs"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cp -r tests/fixtures/manifests/valid "$tmp/p"

# --- The local file wins over the manifest. ---------------------------------
node -e '
 const f="'"$tmp"'/p/.wp-create.json", fs=require("fs");
 const m=JSON.parse(fs.readFileSync(f,"utf8")); m.database.password="from-manifest";
 fs.writeFileSync(f, JSON.stringify(m,null,2));
'
printf '{"database":{"password":"from-local"}}\n' > "$tmp/p/.wp-create.local.json"
out=$($cfg get "$tmp/p" db_password 2>/dev/null) || fail "get db_password did not exit 0"
[ "$out" = "from-local" ] || fail "the local file did not win over the manifest: got $out"

# --- The environment wins over the local file. ------------------------------
out=$(WP_CREATE_DB_PASSWORD=from-env $cfg get "$tmp/p" db_password 2>/dev/null)
[ "$out" = "from-env" ] || fail "the environment did not win over the local file: got $out"

# --- The manifest rung still resolves, and says it is legacy. ---------------
rm "$tmp/p/.wp-create.local.json"
out=$($cfg get "$tmp/p" db_password 2>"$tmp/err") || fail "the manifest rung did not resolve"
[ "$out" = "from-manifest" ] || fail "the manifest rung returned $out"
grep -qi 'legacy' "$tmp/err" || fail "resolving from the manifest did not warn that it is a legacy location"

# --- A space-spelled key is addressable, and an unknown key is exit 1. ------
out=$($cfg get "$tmp/p" i18n-strategy 2>/dev/null) || fail "get i18n-strategy did not exit 0"
[ "$out" = "suffix" ] || fail "get i18n-strategy returned $out"
set +e
$cfg get "$tmp/p" nonsense >/dev/null 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "an unknown key exited $code, want 1"

echo PASS
