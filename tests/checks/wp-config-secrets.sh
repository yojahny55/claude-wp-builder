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
# The fixture's real "i18n strategy" is changed to "polylang" first: getKey's own
# fallback for i18n-strategy is "suffix", which is also the fixture's original
# value, so asserting against "suffix" would pass even if KEY_ALIASES pointed at
# the wrong manifest key entirely -- the fallback would paper over it.
node -e '
 const f="'"$tmp"'/p/.wp-create.json", fs=require("fs");
 const m=JSON.parse(fs.readFileSync(f,"utf8")); m["i18n strategy"]="polylang";
 fs.writeFileSync(f, JSON.stringify(m,null,2));
'
out=$($cfg get "$tmp/p" i18n-strategy 2>/dev/null) || fail "get i18n-strategy did not exit 0"
[ "$out" = "polylang" ] || fail "get i18n-strategy returned $out"
set +e
$cfg get "$tmp/p" nonsense >/dev/null 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "an unknown key exited $code, want 1"

# --- A secret's own manifest path is refused, not rerouted. A dotted path that
# happens to equal a SECRETS[*].manifestPath must not become a second, silent way
# to read the value -- it must exit 1, print nothing, and name the alias to use. --
set +e
out=$($cfg get "$tmp/p" database.password 2>"$tmp/secret-path-err"); code=$?
set -e
[ "$code" = "1" ] || fail "get database.password exited $code, want 1"
[ -z "$out" ] || fail "get database.password printed the secret to stdout: $out"
grep -q 'db_password' "$tmp/secret-path-err" || fail "the refusal does not name the secret alias to use instead"

# --- An object at a secret's path is refused, not printed. -------------------
node -e '
 const f="'"$tmp"'/p/.wp-create.json", fs=require("fs");
 const m=JSON.parse(fs.readFileSync(f,"utf8")); m.database.password={"nested":"oops"};
 fs.writeFileSync(f, JSON.stringify(m,null,2));
'
set +e
out=$($cfg get "$tmp/p" db_password 2>/dev/null); code=$?
set -e
[ "$code" = "1" ] || fail "an object at a secret's manifest path resolved instead of refusing (exit $code)"
[ -z "$out" ] || fail "an object at a secret's manifest path was printed: $out"

# --- An explicitly empty secret resolves as itself, not as absent. -----------
node -e '
 const f="'"$tmp"'/p/.wp-create.json", fs=require("fs");
 const m=JSON.parse(fs.readFileSync(f,"utf8")); m.database.password="";
 fs.writeFileSync(f, JSON.stringify(m,null,2));
'
out=$($cfg get "$tmp/p" db_password 2>/dev/null) || fail "an explicitly empty secret did not resolve"
[ "$out" = "" ] || fail "an explicitly empty secret returned $out"

echo PASS
