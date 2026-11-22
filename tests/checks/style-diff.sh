#!/usr/bin/env bash
# A tag swap or a reset class added to an element (`.btn-reset { color: inherit; font: inherit }`)
# beat the utility classes already on it and turned a white 26px icon into a black 18px one. No
# value was edited, nothing else moved, and a screenshot diff could not see it. The procedure
# ("measure computed styles before and after") existed only as prose, so it was done on one
# hand-picked element or not at all. bin/style-diff.mjs measures every element; two untouched
# baselines are needed because carousels and sliders differ between any two loads.
# This check runs the tool on a file:// fixture, asserts it catches the regression and ignores
# the noise, and pins the docs that must point at it.
set -euo pipefail
. "$(dirname "$0")/../lib/assert.sh"
cd "$(dirname "$0")/../.." || exit 1
tool=bin/style-diff.mjs
[ -f "$tool" ] || fail "$tool is missing"

for f in skills/wp-audit-run/references/fix.md skills/wp-finalize-run/references/parity-visual.md; do
  grep -Fq 'bin/style-diff.mjs' "$f" || fail "$f does not point at $tool"
  grep -Fq -- '--noise' "$f" || fail "$f does not tell the reader to take two baselines (--noise)"
done
grep -Fq 'style-diff.mjs' README.md || fail "README bin table has no style-diff.mjs row"
grep -Fq 'style-diff.mjs' CHANGELOG.md || fail "no changelog entry for the tool"

# --label is a file name: no traversal out of --out (usage error, before any browser)
for l in '../x' 'a/../../x' 'a b'; do
  rc=0; node "$tool" snapshot --out "${TMPDIR:-/tmp}/sd-label-$$" --label "$l" --urls http://x.invalid/ >/dev/null 2>&1 || rc=$?
  [ "$rc" = 2 ] || fail "--label '$l' exited $rc, not 2"
done
[ ! -e "${TMPDIR:-/tmp}/sd-label-$$" ] || { rm -rf "${TMPDIR:-/tmp}/sd-label-$$"; fail "a rejected --label still created --out"; }

# Behavior needs a browser; without one, say so rather than pass silently.
core=${PLAYWRIGHT_CORE:-}
if [ -z "$core" ] || [ ! -d "$core" ]; then
  echo "SKIP: no PLAYWRIGHT_CORE, the fixture half of style-diff did not run"; echo "PASS (docs half)"; exit 0
fi
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
page() { # $1 = element markup
  cat > "$tmp/p.html" <<HTML
<!doctype html><title>t</title><style>.i{color:#fff;font-size:26px;background:#000}.r{color:inherit;font:inherit}.c{width:100px;background:red}</style>
<body>$1<div class="c" id="rnd"></div><script>document.getElementById('rnd').style.height=(20+Math.floor(Math.random()*40))+'px'</script>
HTML
}
snap() { node "$tool" snapshot --out "$tmp" --label "$1" --urls "file://$tmp/p.html" >/dev/null 2>&1 || fail "snapshot $1 failed"; }
page '<span class="i">x</span>'; snap b1; snap b2
page '<button class="i r">x</button>'; snap after
rc=0; out=$(node "$tool" diff "$tmp/b1.json" "$tmp/after.json" --noise "$tmp/b1.json" "$tmp/b2.json") || rc=$?
[ "$rc" = 1 ] || fail "a tag swap that changed colour and size exited $rc, not 1"
printf '%s' "$out" | grep >/dev/null -Fc 'color: rgb(255, 255, 255) -> rgb(0, 0, 0)' || fail "the colour change was not reported"
printf '%s' "$out" | grep >/dev/null -Fc 'fontSize: 26px -> 16px' || fail "the font-size change was not reported"
printf '%s' "$out" | grep >/dev/null -Fc 'noisy, excluded' || fail "the random-height element was not set apart as noise"
printf '%s' "$out" | grep >/dev/null -Fc 'nth-child(2)' && printf '%s' "$out" | sed -n '/STYLE diffs/,/SIZE diffs/p' | grep >/dev/null -Fc 'nth-child(2)' \
  && fail "the noisy element was reported as a style diff"
# Same page against itself: clean, exit 0.
node "$tool" diff "$tmp/b1.json" "$tmp/b1.json" >/dev/null || fail "identical snapshots did not exit 0"
# An unmeasured viewport is never a pass: no diff, but not CLEAN either.
node -e 'const fs=require("fs");const j=JSON.parse(fs.readFileSync(process.argv[1]));for(const u of Object.values(j.pages))for(const v of Object.values(u))v.unmeasured="load failed: timeout";fs.writeFileSync(process.argv[2],JSON.stringify(j))' "$tmp/b1.json" "$tmp/broken.json"
rc=0; node "$tool" diff "$tmp/b1.json" "$tmp/broken.json" >"$tmp/inc.txt" || rc=$?
[ "$rc" = 3 ] || fail "an unmeasured run exited $rc, not 3"
grep -Fq 'INCOMPLETE' "$tmp/inc.txt" || fail "an unmeasured run was not reported as INCOMPLETE"
# An error page or a redirect is never a clean page: two identical 404s, or a login redirect, are unmeasured.
node -e 'const fs=require("fs");const j=JSON.parse(fs.readFileSync(process.argv[1]));for(const u of Object.values(j.pages))for(const v of Object.values(u)){v.status=404}fs.writeFileSync(process.argv[2],JSON.stringify(j))' "$tmp/b1.json" "$tmp/e404.json"
rc=0; node "$tool" diff "$tmp/e404.json" "$tmp/e404.json" >"$tmp/e.txt" || rc=$?
[ "$rc" = 3 ] || fail "two identical 404 snapshots exited $rc, not 3"
grep >/dev/null -Fc 'INCOMPLETE' "$tmp/e.txt" || fail "identical 404 pages were not INCOMPLETE"
node -e 'const fs=require("fs");const j=JSON.parse(fs.readFileSync(process.argv[1]));for(const u of Object.values(j.pages))for(const v of Object.values(u)){v.finalUrl="http://h/login"}fs.writeFileSync(process.argv[2],JSON.stringify(j))' "$tmp/b1.json" "$tmp/redir.json"
rc=0; node "$tool" diff "$tmp/b1.json" "$tmp/redir.json" >"$tmp/r.txt" || rc=$?
[ "$rc" = 3 ] || fail "a different final URL exited $rc, not 3"
# A fragment changed by a scroll-spy script is not a redirect.
node -e 'const fs=require("fs");for(const [src,dst,h] of [[process.argv[1],process.argv[2],"#a"],[process.argv[1],process.argv[3],"#b"]]){const j=JSON.parse(fs.readFileSync(src));for(const [u,vs] of Object.entries(j.pages))for(const v of Object.values(vs)){v.finalUrl=u+h}fs.writeFileSync(dst,JSON.stringify(j))}' "$tmp/b1.json" "$tmp/ha.json" "$tmp/hb.json"
rc=0; node "$tool" diff "$tmp/ha.json" "$tmp/hb.json" >"$tmp/h.txt" || rc=$?
[ "$rc" != 3 ] || fail "a fragment-only change of the final URL was UNMEASURED"
# The real capture records status and final URL (local server: a 404 and a redirect).
srv="$tmp/srv.mjs"
cat > "$srv" <<'JS'
import http from 'node:http';
const s = http.createServer((q, r) => {
  if (q.url === '/ok') { r.setHeader('content-type', 'text/html'); r.end('<title>t</title><p>x</p>'); }
  else if (q.url === '/go') { r.statusCode = 302; r.setHeader('location', '/ok'); r.end(); }
  else { r.statusCode = 404; r.setHeader('content-type', 'text/html'); r.end('<title>nf</title><p>nf</p>'); }
});
s.listen(0, '127.0.0.1', () => console.log(s.address().port));
JS
node "$srv" > "$tmp/port" & srvpid=$!
trap 'kill $srvpid 2>/dev/null; rm -rf "$tmp"' EXIT
for _ in $(seq 50); do [ -s "$tmp/port" ] && break; sleep 0.1; done
base="http://127.0.0.1:$(cat "$tmp/port")"
node "$tool" snapshot --out "$tmp" --label s404 --urls "$base/nope" >/dev/null 2>&1 || fail "snapshot of a 404 failed"
node "$tool" snapshot --out "$tmp" --label s404b --urls "$base/nope" >/dev/null 2>&1 || fail "snapshot of a 404 failed"
node "$tool" snapshot --out "$tmp" --label sgo --urls "$base/go" >/dev/null 2>&1 || fail "snapshot of a redirect failed"
node "$tool" snapshot --out "$tmp" --label sok --urls "$base/ok" >/dev/null 2>&1 || fail "snapshot of a 200 failed"
rc=0; node "$tool" diff "$tmp/s404.json" "$tmp/s404b.json" >/dev/null || rc=$?
[ "$rc" = 3 ] || fail "two captured 404 pages exited $rc, not 3"
node "$tool" diff "$tmp/sok.json" "$tmp/sok.json" >/dev/null || fail "a 200 page against itself did not exit 0"
node -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1]));const v=Object.values(j.pages).flatMap(u=>Object.values(u));if(!v.length||!v.every(e=>e.status===200&&/\/ok$/.test(e.finalUrl||"")))process.exit(1)' "$tmp/sgo.json" \
  || fail "the capture of a redirect did not record status 200 and the final URL /ok"
echo "PASS: style-diff reports a tag-swap regression, sets noise apart and exits 1/0"
