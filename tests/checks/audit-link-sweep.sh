#!/usr/bin/env bash
# An audit agent given "follow the links" and no method improvised a crawler with 25
# concurrent curl workers against a local WooCommerce build and saturated the machine:
# MariaDB at ~18 cores, load 18, every other local site slowed down. bin/link-sweep.mjs is
# the sweep with the limits built in. This check runs it against a local fixture server and
# asserts the limits, then pins the shared rule and the agents that must point at it.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

tool=bin/link-sweep.mjs
[ -f "$tool" ] || fail "$tool missing"
command -v node >/dev/null || { echo "PASS (SKIP: no node — $tool not exercised)"; exit 0; }

tmp=$(mktemp -d)
srv=""
trap '[ -n "$srv" ] && kill "$srv" 2>/dev/null; rm -rf "$tmp"' EXIT

# Fixture: counts requests in flight server-side, so the cap is measured where the load lands.
cat >"$tmp/server.mjs" <<'EOF'
import http from 'node:http';
let inFlight = 0, peak = 0, headRefused = 0;
const srv = http.createServer((req, res) => {
  inFlight++; peak = Math.max(peak, inFlight);
  const done = (code, headers = {}, body = '') => setTimeout(() => {
    inFlight--; res.writeHead(code, headers); res.end(req.method === 'HEAD' ? '' : body);
  }, 60);
  const p = req.url;
  if (p === '/__peak') { inFlight--; res.end(JSON.stringify({ peak, headRefused })); return; }
  if (p === '/ok/') return done(200);
  if (p === '/gone/') return done(404);
  if (p === '/moved/') return done(301, { location: '/ok/' });
  if (p === '/nohead/') {
    if (req.method === 'HEAD') { headRefused++; return done(405); }
    return done(req.headers.range === 'bytes=0-0' ? 206 : 500);
  }
  if (p === '/challenge-header/') return done(403, { 'cf-mitigated': 'challenge' });
  if (p === '/challenge-body/') return done(403, {}, '<script src="/cdn-cgi/challenge-platform/x.js"></script>');
  if (p === '/forbidden/') return done(403, {}, 'no');
  if (p.startsWith('/term/')) return done(200);
  if (p.startsWith('/load/')) return done(200);
  return done(404);
});
srv.listen(0, '127.0.0.1', () => console.log(srv.address().port));
EOF
node "$tmp/server.mjs" >"$tmp/port" &
srv=$!
for _ in $(seq 50); do [ -s "$tmp/port" ] && break; sleep 0.1; done
port=$(cat "$tmp/port"); [ -n "$port" ] || fail "fixture server did not start"
site="http://127.0.0.1:$port"

{
  printf '%s\t%s\n' /ok/ "$site/page-a/" /ok/ "$site/page-b/" /gone/ "$site/page-a/" \
    /moved/ "$site/page-a/" /nohead/ "$site/page-a/" "#" "$site/page-a/" \
    mailto:x@example.com "$site/page-a/" "https://prod.example.com/ok/" "$site/page-a/"
  echo "/challenge-header/"; echo "/challenge-body/"; echo "/forbidden/"
  for i in $(seq 30); do echo "/term/t$i/"; done
  for i in $(seq 12); do echo "/load/l$i/"; done
} >"$tmp/urls"

out=$(node "$tool" --site "$site" --urls "$tmp/urls" --clone-origin prod.example.com \
  --concurrency 25 --per-group 10 --budget 60)
peak=$(curl -s "$site/__peak")

q() { node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));const r=d.results.find(x=>x.url.endsWith(process.argv[1]));process.stdout.write(r?String(r[process.argv[2]]):'MISSING')" "$1" "$2" <<<"$out"; }

node -e "const p=JSON.parse(process.argv[1]).peak; if(p>4){console.log('peak '+p);process.exit(1)}" "$peak" \
  || fail "more than 4 requests in flight at the server despite --concurrency 25"
[ "$(node -e "console.log(JSON.parse(require('fs').readFileSync(0,'utf8')).summary.concurrency)" <<<"$out")" = 4 ] \
  || fail "--concurrency above 4 was not clamped"
[ "$(q /ok/ verdict)" = ok ] || fail "/ok/ not ok"
[ "$(q /ok/ pages)" = "$site/page-a/,$site/page-b/" ] || fail "duplicate link did not collapse into one row with both pages"
[ "$(q /gone/ verdict)" = broken ] && [ "$(q /gone/ status)" = 404 ] || fail "/gone/ not reported broken 404"
[ "$(q /moved/ verdict)" = redirect ] || fail "/moved/ not reported as redirect"
[ "$(q /nohead/ verdict)" = ok ] && [ "$(q /nohead/ status)" = 206 ] || fail "HEAD 405 did not fall back to a ranged GET"
[ "$(q /challenge-header/ verdict)" = unmeasured ] || fail "cf-mitigated challenge not UNMEASURED"
[ "$(q /challenge-body/ verdict)" = unmeasured ] || fail "challenge-platform body not UNMEASURED"
q /challenge-body/ reason | grep -q 'CDN bot challenge' || fail "challenge reason missing"
[ "$(q /forbidden/ verdict)" = broken ] || fail "a plain 403 was treated as a challenge"
[ "$(q prod.example.com/ok/ verdict)" = unmeasured ] || fail "clone-origin link was requested without --follow-clone-origin"
[ "$(q '#' verdict)" = fragment ] || fail "fragment-only href not reported as fragment"
[ "$(q mailto:x@example.com verdict)" = skipped ] || fail "mailto: not skipped"
sampled=$(node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));console.log(d.results.filter(r=>r.url.includes('/term/')&&/sampled/.test(r.reason||'')).length)" <<<"$out")
[ "$sampled" = 20 ] || fail "per-group sampling kept $((30 - sampled)) of 30 /term/ links, expected 10"

# The third column is the sampling group: two taxonomies under one path segment are sampled
# separately, not as one pool.
{ for i in $(seq 5); do printf '/load/g%s/\t\ttax:a\n' "$i"; done
  for i in $(seq 5); do printf '/load/h%s/\t\ttax:b\n' "$i"; done; } >"$tmp/grp"
outg=$(node "$tool" --site "$site" --urls "$tmp/grp" --per-group 3 --budget 30)
node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));
const ok=d.results.filter(r=>r.verdict==='ok').length;
if(ok!==6){console.log(ok);process.exit(1)}" <<<"$outg" \
  || fail "--per-group 3 over two groups did not request 3 of each"

# Budget: a zero budget measures nothing and says why, instead of hanging.
out0=$(printf '/ok/\n' | node "$tool" --site "$site" --budget 0)
grep -q 'budget exhausted' <<<"$out0" || fail "--budget 0 did not report budget exhaustion"

# A malformed page column must not abort the sweep: the link resolves against the site.
outb=$(printf '/ok/\thttp://[bad\n' | node "$tool" --site "$site" --budget 30) \
  || fail "a malformed page column aborted the sweep"
grep -q '"verdict": "ok"' <<<"$outb" || fail "a link with a malformed page column was not measured"

# The shared rule, and the agents that sweep links must point at it.
std=skills/wp-audit-standards/SKILL.md
grep -Fq '### Link and page sweeps against a site' "$std" || fail "$std lost the sweep rule"
grep -Fq 'At most 4 requests in flight' "$std" || fail "$std lost the concurrency cap"
grep -Fq 'bin/link-sweep.mjs' "$std" || fail "$std does not name the helper"
grep -Fq 'WP-CLI or the database first' "$std" || fail "$std lost the DB-first rule"
grep -Fq '20 per taxonomy' "$std" || fail "$std lost the term-archive sample"
for a in agents/wp-audit-seo.md agents/wp-audit-ux.md; do
  grep -Fq 'Link and page sweeps against a site' "$a" || fail "$a does not point at the sweep rule"
  grep -Fq 'bin/link-sweep.mjs' "$a" || fail "$a does not name the helper"
done
grep -Fq 'resolve-link-targets.php' "$std" || fail "$std does not name the resolver"
grep -Fq 'never marks a broken one resolved' "$std" || fail "$std lost the resolver's safety rule"
[ -f skills/wp-cli-patterns/scripts/resolve-link-targets.php ] || fail "resolver script missing"
# On a subdirectory install a root-relative href outside the install goes to HTTP, never
# resolved against the install (a /alpha/ on host/wp is host/alpha/, not host/wp/alpha/).
grep -Fq "0 !== strpos( \$href, \$home_path . '/' )" skills/wp-cli-patterns/scripts/resolve-link-targets.php \
  || fail "resolver lost the subdirectory-install guard"
# Every auditor is told, not only the two that were caught doing it.
dispatch=$(awk '/^## Step 6:/{on=1} /^## Step 6.5:/{on=0} on' commands/wp-audit.md)
grep -Fq 'Link and page sweeps against a site' <<<"$dispatch" || fail "/wp-audit's agent prompt lacks the sweep rule"
grep -Fq 'crawler of your own' <<<"$dispatch" || fail "/wp-audit's agent prompt does not forbid improvised crawlers"
grep -Fq 'audit-resolve-links-integration.sh' .github/workflows/ci.yml \
  || fail "the resolver's WordPress check is not wired into CI"
grep -Eq 'max-workers|max_workers=25' agents/wp-audit-ux.md && fail "wp-audit-ux still shows an uncapped sweep"

echo PASS
