#!/usr/bin/env bash
# bin/section-diff.mjs compares one built section with the demo section it came from. This runs
# it on fixture pages: an identical section passes at 0%, a recoloured one fails on pixels, a
# taller one fails on height, a narrower one on width, a section whose root class is gone or
# matches twice exits 4, a page that fails to load exits 2, and bad arguments exit 64. The browser part needs playwright-core, pixelmatch and pngjs (npm install) and a
# Chrome; without them it skips, unless CHECKS_REQUIRE_BROWSER=1.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

tool=bin/section-diff.mjs
[ -x "$tool" ] || fail "$tool is missing or not executable"
need_token BACKLOG.md 'tests/checks/section-diff.sh'
need_token docs/plugin-code.md '`section-diff.mjs`'
require_tool node python3 curl

tmp=$(mktemp -d)
pid=""
cleanup() { [ -n "$pid" ] && kill "$pid" 2>/dev/null || true; rm -rf "$tmp"; }
trap cleanup EXIT

set +e
node "$tool" --site http://127.0.0.1:1/ --section hero >/dev/null 2>&1; [ $? = 64 ] || fail "a missing --demo did not exit 64"
node "$tool" --demo x.html --site not-a-url --section hero >/dev/null 2>&1; [ $? = 64 ] || fail "a non-http --site did not exit 64"
set -e

mkdir -p "$tmp/site"
cat > "$tmp/demo.html" <<'HTML'
<!doctype html><html><head><meta charset="utf-8"><style>body{margin:0;font-family:sans-serif}.hero{background:#1d3557;color:#fff;padding:60px 24px}.hero__title{font-size:40px;margin:0}.after{height:300px;background:#eee}</style></head><body>
<!-- ============ SECTION: Hero ============ -->
<section class="hero"><h1 class="hero__title">Build fast</h1><p>Lorem ipsum dolor sit amet.</p></section>
<!-- ============ END SECTION: Hero ============ -->
<div class="after"></div></body></html>
HTML
sed 's/<!-- =.*-->//' "$tmp/demo.html" > "$tmp/site/same.html"
sed 's/#1d3557/#c1121f/' "$tmp/site/same.html" > "$tmp/site/red.html"
sed 's/padding:60px 24px/padding:120px 24px/' "$tmp/site/same.html" > "$tmp/site/tall.html"
sed 's/class="hero"/class="banner"/' "$tmp/site/same.html" > "$tmp/site/gone.html"
sed 's|<body>|<body><div style="width:60%">|; s|</body>|</div></body>|' "$tmp/site/same.html" > "$tmp/site/narrow.html"
sed 's|<div class="after"></div>|<section class="hero"><h1>Again</h1></section><div class="after"></div>|' "$tmp/site/same.html" > "$tmp/site/twice.html"

port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
(cd "$tmp/site" && exec python3 -m http.server "$port" --bind 127.0.0.1) >/dev/null 2>&1 &
pid=$!
for _ in $(seq 1 50); do curl -s -o /dev/null "http://127.0.0.1:$port/same.html" && break; sleep 0.1; done

run() { node "$tool" --demo "$tmp/demo.html" --site "http://127.0.0.1:$port/$1.html" --section hero --out "$tmp/out-$1" --json 2>/dev/null; }
set +e; out=$(run same); rc=$?; set -e
if [ "$rc" = 2 ]; then
  [ "${CHECKS_REQUIRE_BROWSER:-0}" = 1 ] && fail "CHECKS_REQUIRE_BROWSER=1 and section-diff measured nothing (playwright-core, pixelmatch, pngjs or Chrome missing)"
  skip "playwright-core, pixelmatch, pngjs or Chrome is not available"
fi
field() { printf '%s' "$1" | python3 -c "import json,sys; r=json.load(sys.stdin); print(' '.join('%s:%s:%s' % (v['viewport'], v['diffPercent'], v['heightDeltaPercent']) for v in r['viewports']))"; }
[ "$rc" = 0 ] || fail "an identical section did not pass ($rc): $out"
[ "$(field "$out")" = "390:0:0 1440:0:0" ] || fail "an identical section did not measure 0%: $(field "$out")"
for f in 390-demo.png 390-site.png 390-diff.png 1440-diff.png report.json; do
  [ -s "$tmp/out-same/$f" ] || fail "no $f was written"
done

set +e; out=$(run red); rc=$?; set -e
[ "$rc" = 1 ] || fail "a recoloured section exited $rc, not 1"
printf '%s' "$out" | python3 -c "import json,sys; r=json.load(sys.stdin); assert all(v['diffPercent']>50 and v['heightDeltaPercent']==0 for v in r['viewports'])" || fail "a recoloured section was not measured as a pixel difference: $(field "$out")"

set +e; out=$(run tall); rc=$?; set -e
[ "$rc" = 1 ] || fail "a taller section exited $rc, not 1"
printf '%s' "$out" | python3 -c "import json,sys; r=json.load(sys.stdin); assert all(v['heightDeltaPercent']>20 for v in r['viewports'])" || fail "a taller section was not measured as a height difference: $(field "$out")"

set +e; run gone >/dev/null; rc=$?; set -e
[ "$rc" = 4 ] || fail "a section missing on the built page exited $rc, not 4"

set +e; out=$(run narrow); rc=$?; set -e
[ "$rc" = 1 ] || fail "a narrower section exited $rc, not 1"
printf '%s' "$out" | python3 -c "import json,sys; r=json.load(sys.stdin); assert all(v['widthDeltaPercent']<-20 for v in r['viewports'])" || fail "a narrower section was not measured as a width difference: $out"

set +e; run twice >/dev/null; rc=$?; set -e
[ "$rc" = 4 ] || fail "a root class that matches two elements on the built page exited $rc, not 4"

set +e; run missing-page >/dev/null; rc=$?; set -e
[ "$rc" = 2 ] || fail "a 404 built page exited $rc, not 2 (nothing measured is not a regression)"

echo "PASS: section-diff passes an identical section, fails a recoloured, a taller and a narrower one, and refuses a missing or ambiguous one"
