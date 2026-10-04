#!/usr/bin/env bash
# Resolve link targets through a real WordPress, then prove every claim over HTTP.
#
# skills/wp-cli-patterns/scripts/resolve-link-targets.php lets an audit skip the HTTP
# request for any internal link the database can answer, which is what keeps a link sweep
# from rendering hundreds of uncached archives. Its one unforgivable error is marking a
# broken link resolved: that link is then never requested, and the audit reports a pass
# for a 404. So this check does not trust the script's output. It serves the fixture and
# requests every link the script resolved, and each must answer 200 with no redirect.
# The links it sent to HTTP are then swept with bin/link-sweep.mjs, and the broken ones
# must come back broken, with the sampling group the script assigned.
#
# SKIPs unless WP_FIXTURE=1, like the other fixture-backed checks.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

if [ "${WP_FIXTURE:-0}" != "1" ]; then
  echo "SKIP: set WP_FIXTURE=1 to provision a disposable WordPress and run this"
  exit 0
fi

prov=tests/fixtures/wp/provision.sh
script=skills/wp-cli-patterns/scripts/resolve-link-targets.php
for f in "$prov" "$script" bin/link-sweep.mjs; do [ -r "$f" ] || fail "$f is missing or unreadable"; done
command -v curl >/dev/null 2>&1 || fail "curl is not on PATH"
command -v node >/dev/null 2>&1 || fail "node is not on PATH"

DIR=""
SERVER_PID=""
TMP=$(mktemp -d)
cleanup() {
  status=$?
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
  [ -n "$DIR" ] && bash "$prov" --teardown "$DIR" >/dev/null 2>&1 || true
  rm -rf "$TMP"
  exit $status
}
trap cleanup EXIT INT TERM

env_out=$(bash "$prov") || fail "could not provision a WordPress fixture"
DIR=$(printf '%s\n' "$env_out" | sed -n "s/^export WP_FIXTURE_DIR='\(.*\)'$/\1/p")
[ -n "$DIR" ] || fail "the provisioner printed no WP_FIXTURE_DIR"
WP="wp --path=$DIR --allow-root"

PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
SITE="http://127.0.0.1:$PORT"
$WP option update home "$SITE" --quiet
$WP option update siteurl "$SITE" --quiet
$WP rewrite structure '/%postname%/' --quiet
$WP rewrite flush --quiet

news=$($WP term create category news --porcelain)
$WP term create category empty-cat --porcelain >/dev/null
$WP post create --post_type=post --post_title=Alpha --post_name=alpha --post_status=publish \
  --post_category="$news" --porcelain >/dev/null
$WP post create --post_type=post --post_title=Beta --post_name=beta --post_status=draft --porcelain >/dev/null
$WP post create --post_type=post --post_title=Gamma --post_name=gamma --post_status=publish \
  --post_password=secret --porcelain >/dev/null
parent=$($WP post create --post_type=page --post_title=Parent --post_name=parent --post_status=publish --porcelain)
$WP post create --post_type=page --post_title=Child --post_name=child --post_status=publish \
  --post_parent="$parent" --porcelain >/dev/null

P="$SITE/parent/"
cat >"$TMP/links" <<EOF
/alpha/	$P
$SITE/alpha/	$SITE/
/beta/	$P
/gamma/	$P
/parent/child/	$P
/child/	$P
/category/news/	$P
/category/empty-cat/	$P
/category/nope/	$P
/nope/	$P
/alpha/?x=1	$P
/	$P
https://example.invalid/	$P
#top	$P
mailto:x@example.invalid	$P
EOF

http_list=$($WP eval-file "$script" "$TMP/links" "$TMP/resolved.json" 2>"$TMP/err") \
  || { cat "$TMP/err"; fail "the resolver exited non-zero"; }

resolved=$(node -e "for (const r of JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))) console.log(new URL(r.url).pathname)" "$TMP/resolved.json" | sort)
expect=$(printf '%s\n' / /alpha/ /category/empty-cat/ /category/news/ /parent/child/ | sort)
[ "$resolved" = "$expect" ] || { echo "resolved: $resolved"; fail "the resolver did not resolve exactly the published targets"; }
node -e "const d=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));const a=d.find(r=>r.url.endsWith('/alpha/'));
if(a.pages.length!==2)process.exit(1)" "$TMP/resolved.json" || fail "a target linked from two pages did not keep both pages"

for must in /beta/ /gamma/ /child/ /category/nope/ /nope/ '/alpha/?x=1' https://example.invalid/ '#top' mailto:; do
  grep -Fq -- "$must" <<<"$http_list" || fail "$must was not sent to HTTP"
done
grep -Fq "$(printf '/category/nope/\t%s\ttax:category' "$P")" <<<"$http_list" \
  || fail "an unresolved URL under a taxonomy base lost its tax:category group"

# Now the claim is tested against the site itself.
SERVER_LOG="$DIR/resolve-server.log"
$WP server --host=127.0.0.1 --port="$PORT" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
up=""
for _ in $(seq 1 40); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' "$SITE/" || true)" = 200 ] && { up=1; break; }
  sleep 1
done
[ -n "$up" ] || { tail -5 "$SERVER_LOG"; fail "the fixture site never answered on port $PORT"; }

for p in $resolved; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$SITE$p")
  [ "$code" = 200 ] || fail "resolved $p answers $code over HTTP — the resolver marked a broken link resolved"
done

sweep=$(node bin/link-sweep.mjs --site "$SITE" --budget 60 <<<"$http_list")
v() { node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));const r=d.results.find(x=>new URL(x.url,'http://h').pathname+new URL(x.url,'http://h').search===process.argv[1]);process.stdout.write(r?r.verdict:'MISSING')" "$1" <<<"$sweep"; }
[ "$(v /nope/)" = broken ] || fail "/nope/ was not broken in the sweep"
[ "$(v /category/nope/)" = broken ] || fail "/category/nope/ was not broken in the sweep"
[ "$(v /beta/)" = broken ] || fail "a draft's URL was not broken for an anonymous request"
[ "$(v /alpha/?x=1)" = ok ] || fail "/alpha/?x=1 did not come back ok"

echo PASS
