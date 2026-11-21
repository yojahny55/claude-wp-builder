#!/usr/bin/env bash
# bin/h2-proxy.mjs caches anonymous HTML. The key must hold what makes a response vary (request
# cookies such as a language cookie, Accept-Language), and a response that sets a cookie or is
# no-store/private must not be cached. Runs the proxy against a local fixture on 127.0.0.1.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
command -v node >/dev/null || { echo "PASS (SKIP: no node)"; exit 0; }
command -v openssl >/dev/null || { echo "PASS (SKIP: no openssl)"; exit 0; }
command -v curl >/dev/null || { echo "PASS (SKIP: no curl)"; exit 0; }

tmp=$(mktemp -d)
pids=""
cleanup() { local p; for p in $pids; do kill "$p" 2>/dev/null || true; done; rm -rf "$tmp"; }
trap cleanup EXIT

cat >"$tmp/up.mjs" <<'JS'
import http from 'node:http';
let n = 0;
const srv = http.createServer((req, res) => {
  n++;
  const lang = /pll_language=(\w+)/.exec(req.headers.cookie || '')?.[1] || (req.headers['accept-language'] || 'none');
  const h = { 'content-type': 'text/html' };
  if (req.url === '/cookie') h['set-cookie'] = 'sid=' + n;
  if (req.url === '/nostore') h['cache-control'] = 'no-store';
  if (req.url === '/private') h['cache-control'] = 'private, max-age=0';
  res.writeHead(200, h);
  res.end(`<html>lang=${lang} hit=${n}</html>`);
});
srv.listen(0, '127.0.0.1', () => console.log(srv.address().port));
JS
node "$tmp/up.mjs" >"$tmp/up.port" & pids="$pids $!"
for _ in $(seq 50); do [ -s "$tmp/up.port" ] && break; sleep 0.1; done
up=$(cat "$tmp/up.port"); [ -n "$up" ] || fail "upstream did not start"

# A free port for the proxy, found by binding port 0 and releasing it.
pport=$(node -e "const s=require('net').createServer().listen(0,'127.0.0.1',()=>{console.log(s.address().port);s.close()})")
node bin/h2-proxy.mjs --target "http://127.0.0.1:$up" --port "$pport" >"$tmp/proxy.log" 2>&1 & pids="$pids $!"
for _ in $(seq 80); do grep >/dev/null -c 'h2 proxy' "$tmp/proxy.log" && break; sleep 0.1; done
grep >/dev/null -c 'h2 proxy' "$tmp/proxy.log" || fail "proxy did not start: $(cat "$tmp/proxy.log")"

get() { curl -sk --max-time 10 "$@"; }
u="https://127.0.0.1:$pport"

a=$(get -H 'Cookie: pll_language=es' "$u/page"); b=$(get -H 'Cookie: pll_language=en' "$u/page")
grep >/dev/null -c 'lang=es' <<<"$a" || fail "first language request wrong: $a"
grep >/dev/null -c 'lang=en' <<<"$b" || fail "a language cookie was served the other language's cached page: $b"
c=$(get -H 'Accept-Language: fr' "$u/al"); d=$(get -H 'Accept-Language: de' "$u/al")
grep >/dev/null -c 'lang=fr' <<<"$c" && grep >/dev/null -c 'lang=de' <<<"$d" || fail "Accept-Language variants crossed: $c / $d"
# Same variant twice is still a hit (the cache works).
e=$(get -H 'Cookie: pll_language=es' "$u/page")
[ "$e" = "$a" ] || fail "an identical request was not served from the cache: $a / $e"
for path in cookie nostore private; do
  x=$(get "$u/$path"); y=$(get "$u/$path")
  [ "$x" != "$y" ] || fail "/$path was cached despite Set-Cookie / no-store / private: $x"
done
echo PASS
