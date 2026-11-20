#!/usr/bin/env bash
# An audit agent given "follow the links" and no method improvised a crawler with 25
# concurrent curl workers against a local WooCommerce build and saturated the machine:
# MariaDB at ~18 cores, load 18, every other local site slowed down. bin/link-sweep.mjs is
# the sweep with the limits built in. This check runs it against a local fixture server and
# asserts the limits, then pins the shared rule and the agents that must point at it.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/checks/lib/expand-command.sh; expand_command commands/wp-audit.md; wp_audit=$EXPANDED
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
let inFlight = 0, peak = 0, headRefused = 0, originHits = 0, directHits = 0;
const srv = http.createServer((req, res) => {
  inFlight++; peak = Math.max(peak, inFlight);
  const done = (code, headers = {}, body = '') => setTimeout(() => {
    inFlight--; res.writeHead(code, headers); res.end(req.method === 'HEAD' ? '' : body);
  }, 60);
  const p = req.url;
  if (/^localhost/.test(req.headers.host || '')) originHits++;
  if (p === '/__peak') { inFlight--; res.end(JSON.stringify({ peak, headRefused, originHits, directHits })); return; }
  if (p === '/ok/') return done(200);
  if (p === '/gone/') return done(404);
  if (p === '/moved/') return done(301, { location: '/ok/' });
  if (p === '/to-origin/') return done(302, { location: `http://localhost:${srv.address().port}/ok/` });
  if (p === '/to-meta/') return done(302, { location: 'http://169.254.169.254/latest/meta-data/' });
  if (p === '/to-meta6/') return done(302, { location: 'http://[::ffff:169.254.169.254]/latest/meta-data/' });
  if (p === '/to-meta6hex/') return done(302, { location: 'http://[::ffff:a9fe:a9fe]/' });
  if (p === '/to-awsv6/') return done(302, { location: 'http://[fd00:ec2::254]/' });
  if (p === '/direct-private') { directHits++; return done(200); }
  if (p === '/loop/') return done(302, { location: '/loop/' });
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

# --per-page: a link on two pages is charged once, and what is over every page's quota is
# unmeasured. Page A carries 3 links, page B carries 3 (one shared); cap 2 per page. Page B
# is written relative once, and still shares one quota with its absolute spelling. Links
# found on one page are charged first, so the shared link is the one left over.
{ printf '%s\t%s\n' /load/p3/ "$site/a/" /load/p1/ "$site/a/" /load/p2/ "$site/a/" \
    /load/p3/ "$site/b/" /load/p4/ /b/ /load/p5/ "$site/b/"; } >"$tmp/pp"
outp=$(node "$tool" --site "$site" --urls "$tmp/pp" --per-page 2 --budget 30)
node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));
const req=d.results.filter(r=>r.verdict==='ok').length, cap=d.results.filter(r=>/per-page/.test(r.reason||''));
if(req!==4||cap.length!==1||!cap[0].url.endsWith('/load/p3/')||!cap[0].reason.includes('/b/')){console.log(req,JSON.stringify(cap));process.exit(1)}" <<<"$outp" \
  || fail "--per-page 2 over two pages did not request the 4 single-page links and cap the shared one, naming its pages"
# Links with no page column share one quota instead of escaping the cap.
outn=$(printf '/load/n1/\n/load/n2/\n/load/n3/\n' | node "$tool" --site "$site" --per-page 2 --budget 30)
node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));
const req=d.results.filter(r=>r.verdict==='ok').length, cap=d.results.filter(r=>/per-page .*\(no page\)/.test(r.reason||'')).length;
if(req!==2||cap!==1){console.log(req,cap);process.exit(1)}" <<<"$outn" \
  || fail "--per-page did not cap links that carry no page column"

# A link refused by --per-page does not use up a --per-group slot: group g has 3 links, the
# first on a page whose quota is already spent, and all of the other two are still measured.
{ printf '%s\t%s\n' /load/z1/ "$site/full/"; printf '%s\t%s\ttax:g\n' /load/z2/ "$site/full/" \
    /load/z3/ "$site/c/" /load/z4/ "$site/d/"; } >"$tmp/pg"
outpg=$(node "$tool" --site "$site" --urls "$tmp/pg" --per-page 1 --per-group 2 --budget 30)
node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));
const ok=d.results.filter(r=>r.verdict==='ok').map(r=>r.url.replace(/.*\/load\//,'')).sort().join();
if(ok!=='z1/,z3/,z4/'){console.log(ok);process.exit(1)}" <<<"$outpg" \
  || fail "a link refused by --per-page consumed a --per-group slot"

# A redirect is a request too: it is checked against the same rules as the link. A link on the
# site that redirects to the clone-origin host must not reach it without --follow-clone-origin;
# a redirect to a link-local/metadata address is never followed; a loop stops at 5 hops. The
# fixture is reachable as 127.0.0.1 (the site) and as localhost (standing in for the origin).
printf '/to-origin/\n/to-meta/\n/to-meta6/\n/to-meta6hex/\n/to-awsv6/\n/loop/\n/moved/\n' >"$tmp/redir"
outr=$(node "$tool" --site "$site" --urls "$tmp/redir" --clone-origin localhost --budget 30)
hits=$(curl -s "$site/__peak" | node -e "console.log(JSON.parse(require('fs').readFileSync(0,'utf8')).originHits)")
[ "$hits" = 0 ] || fail "a redirect reached the clone-origin host without --follow-clone-origin ($hits requests)"
qr() { node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));const r=d.results.find(x=>x.url.endsWith(process.argv[1]));process.stdout.write(r?String(r[process.argv[2]]):'MISSING')" "$1" "$2" <<<"$outr"; }
[ "$(qr /to-origin/ verdict)" = unmeasured ] || fail "redirect to the clone origin was not UNMEASURED"
qr /to-origin/ reason | grep -q 'follow-clone-origin' || fail "clone-origin redirect refusal does not name the flag"
[ "$(qr /to-meta/ verdict)" = unmeasured ] || fail "redirect to a link-local address was not UNMEASURED"
qr /to-meta/ reason | grep -q 'link-local' || fail "link-local redirect refusal reason missing"
# An IPv4-mapped IPv6 spelling of the metadata address (dotted and hex), and the AWS IPv6
# metadata address, are refused by literal: the request never leaves, so the reason is ours.
for r in /to-meta6/ /to-meta6hex/ /to-awsv6/; do
  [ "$(qr $r verdict)" = unmeasured ] || fail "redirect to $r was not UNMEASURED"
  qr $r reason | grep -q 'link-local/metadata' || fail "redirect $r was not refused as link-local/metadata: $(qr $r reason)"
done
[ "$(qr /loop/ verdict)" = unmeasured ] && qr /loop/ reason | grep -q 'more than 5 redirects' || fail "a redirect loop was not stopped at 5 hops"
[ "$(qr /moved/ verdict)" = redirect ] || fail "a same-site redirect is no longer followed"
outf=$(printf '/to-origin/\n' | node "$tool" --site "$site" --clone-origin localhost --follow-clone-origin --budget 30)
grep -q '"verdict": "redirect"' <<<"$outf" || fail "--follow-clone-origin did not allow the redirect to the origin"

# A direct link is a request too: the policy runs on the initial URL, not only on redirect hops.
# From a public site, a link straight to a metadata address or to a private/loopback server is
# refused before any request leaves (the fixture must see no hit); a same-host link is unaffected.
outd=$(printf 'http://127.0.0.1:%s/direct-private\thttps://public.example/\nhttp://169.254.169.254/latest/meta-data/\thttps://public.example/\nhttp://[::ffff:169.254.169.254]/\thttps://public.example/\n' "$port" \
  | node "$tool" --site https://public.example --budget 30)
dh=$(curl -s "$site/__peak" | node -e "console.log(JSON.parse(require('fs').readFileSync(0,'utf8')).directHits)")
[ "$dh" = 0 ] || fail "a direct link to a private/loopback host was fetched from a public site ($dh hits)"
node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));const bad=d.results.filter(r=>r.verdict!=='unmeasured'||!r.reason);if(d.results.length!==3||bad.length){console.log(JSON.stringify(d.results));process.exit(1)}" <<<"$outd" \
  || fail "direct links to private/metadata hosts were not all UNMEASURED with a reason"
grep -q 'private/loopback' <<<"$outd" && grep -q 'link-local/metadata' <<<"$outd" || fail "direct-link refusal reasons missing"
[ "$(q /ok/ verdict)" = ok ] || fail "a same-host link is affected by the direct-link check"

# A dead external host (.invalid never resolves) is a broken link, not an unmeasured one: the
# resolution failure on the original URL is reported by the request, not refused as a redirect.
outi=$(printf '%s\t%s\n' 'https://nonexistent-zzq.invalid/x' "$site/page-a/" | node "$tool" --site "$site" --budget 20)
node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8'));const r=d.results[0];
if(!r||r.verdict!=='broken'){console.log(JSON.stringify(r));process.exit(1)}" <<<"$outi" \
  || fail "a direct link to an unresolvable (.invalid) host was not reported broken"

# The classifier and the resolved-address check, without a network: the lookup is injected.
node --input-type=module - <<'JS' || fail "address classification (bin/lib/net-class.mjs) is wrong"
import { classifyHost as c, checkResolved, Refused, siteIsLocal } from './bin/lib/net-class.mjs';
const want = { '[::ffff:a9fe:a9fe]': 'metadata', '::ffff:169.254.169.254': 'metadata', '[::ffff:7f00:1]': 'private',
  'fd00:ec2::254': 'metadata', '[::1]': 'private', '::': 'private', 'fe80::1': 'linklocal', 'fc00::1': 'private',
  'fd12::1': 'private', '0.0.0.0': 'private', '169.254.1.1': 'linklocal', '10.0.0.1': 'private', '172.16.0.1': 'private',
  '172.32.0.1': 'public', '192.168.1.1': 'private', 'localhost': 'private', 'metadata.google.internal': 'metadata',
  '8.8.8.8': 'public', '[::ffff:808:808]': 'public', 'example.com': 'public', '2001:db8::1': 'public' };
for (const [h, k] of Object.entries(want)) if (c(h) !== k) { console.error(h, c(h), 'expected', k); process.exit(1); }
const look = (map) => async (h) => { if (!map[h]) { const e = new Error('x'); e.code = 'ENOTFOUND'; throw e; } return map[h].map((address) => ({ address })); };
const refusal = async (host, siteLocal, map) => { try { await checkResolved(host, { siteLocal, lookup: look(map) }); return null; } catch (e) { if (!(e instanceof Refused)) throw e; return e.message; } };
const m = { 'rebind.example': ['93.184.216.34', '169.254.169.254'], 'lan.example': ['10.0.0.5'], 'ok.example': ['93.184.216.34'], 'v6.example': ['::ffff:7f00:1'] };
if (!/link-local\/metadata/.test(await refusal('rebind.example', true, m))) { console.error('any-address metadata not refused'); process.exit(1); }
if (!/private\/loopback/.test(await refusal('lan.example', false, m))) { console.error('private from a non-local site not refused'); process.exit(1); }
if (await refusal('lan.example', true, m) !== null) { console.error('private refused from a local site'); process.exit(1); }
if (!/private\/loopback/.test(await refusal('v6.example', false, m))) { console.error('mapped loopback answer not refused'); process.exit(1); }
if (await refusal('ok.example', false, m) !== null) { console.error('public name refused'); process.exit(1); }
if (!/could not resolve redirect host/.test(await refusal('nx.example', false, m))) { console.error('lookup failure is not a reasoned refusal'); process.exit(1); }
{ let r = 'x'; try { await checkResolved('nx.example', { siteLocal: false, lookup: look(m), allowUnresolved: true }); r = null; } catch (e) { r = e.message; }
  if (r !== null) { console.error('an unresolved original link was refused'); process.exit(1); } }
{ const ac = new AbortController(); const slow = () => new Promise(() => {}); setTimeout(() => ac.abort(new Error('timeout')), 50);
  let msg = ''; try { await checkResolved('slow.example', { siteLocal: false, lookup: slow, signal: ac.signal }); } catch (e) { msg = e.message; }
  if (!/could not resolve/.test(msg)) { console.error('a hung lookup was not bounded by the signal'); process.exit(1); } }
// The site's own locality is judged by resolution too: a dev name /etc/hosts points at
// loopback is local, so another local host it links to is followed, not refused.
{ const sm = { 'www.dev.example': ['127.0.0.1', '::1'], 'mixed.example': ['127.0.0.1', '93.184.216.34'], 'ok.example': ['93.184.216.34'] };
  const cases = [['www.dev.example', true], ['mixed.example', false], ['ok.example', false], ['nx.example', false], ['localhost', true], ['127.0.0.1', true], ['8.8.8.8', false]];
  for (const [h, want] of cases) { const got = await siteIsLocal(h, { lookup: look(sm) }); if (got !== want) { console.error('siteIsLocal', h, got, 'expected', want); process.exit(1); } } }
JS

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
dispatch=$(awk '/^## Step 6:/{on=1} /^## Step 6.5:/{on=0} on' "$wp_audit")
grep -Fq 'Link and page sweeps against a site' <<<"$dispatch" || fail "/wp-audit's agent prompt lacks the sweep rule"
grep -Fq 'crawler of your own' <<<"$dispatch" || fail "/wp-audit's agent prompt does not forbid improvised crawlers"
grep -Fq 'audit-resolve-links-integration.sh' .github/workflows/ci.yml \
  || fail "the resolver's WordPress check is not wired into CI"
grep -Eq 'max-workers|max_workers=25' agents/wp-audit-ux.md && fail "wp-audit-ux still shows an uncapped sweep"

echo PASS
