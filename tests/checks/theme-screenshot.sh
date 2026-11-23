#!/usr/bin/env bash
# bin/theme-screenshot.mjs writes a theme's screenshot.png from the built homepage, because
# both starters ship a 1x1 placeholder and a delivered theme otherwise previews as a blank
# tile. This pins where it runs (/wp-yolo Phase 3, the /wp-finalize Check 4 FAIL) and runs
# it against a local page: the placeholder is replaced by a 1200x900 capture, a real preview
# is kept unless --force, and a failing page, a missing browser or bad arguments never touch
# the file. The browser part skips on a machine with no playwright-core or Chrome.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh
. tests/checks/lib/expand-command.sh

tool=bin/theme-screenshot.mjs
[ -x "$tool" ] || fail "$tool is missing or not executable"
expand_command commands/wp-yolo.md; yolo=$EXPANDED
need_token "$yolo" 'bin/theme-screenshot.mjs" <home-url> <theme-dir>'
need_token skills/wp-finalize-run/references/theme-structure.md 'or `1x1`, with the fix:'
need_token skills/wp-finalize-run/references/theme-structure.md 'bin/theme-screenshot.mjs" <home-url> <theme-dir>'
need_token BACKLOG.md 'tests/checks/theme-screenshot.sh'
[ -f starter-theme/__tailwind__/screenshot.png ] || fail "the tailwind starter's screenshot.png is missing; the placeholder case starts from it"

require_tool node python3
tmp=$(mktemp -d)
pid=""
cleanup() { [ -n "$pid" ] && kill "$pid" 2>/dev/null || true; rm -rf "$tmp"; }
trap cleanup EXIT

size() { python3 -c "import struct,sys; b=open(sys.argv[1],'rb').read(24); print('%dx%d' % struct.unpack('>II', b[16:24]) if b[1:4]==b'PNG' else 'not-a-png')" "$1"; }

theme="$tmp/theme"; mkdir -p "$theme" "$tmp/site"
printf '/*\nTheme Name: Fixture\n*/\n' > "$theme/style.css"
printf '<!doctype html><html><body style="margin:0;background:#1d6f42"><h1 style="font:56px sans-serif;color:#fff;padding:48px">Fixture home</h1></body></html>' > "$tmp/site/index.html"

# Argument errors exit 64 and write nothing.
set +e
node "$tool" not-a-url "$theme" >/dev/null 2>&1; [ $? = 64 ] || fail "a non-http URL did not exit 64"
node "$tool" http://127.0.0.1:1/ "$tmp/site" >/dev/null 2>&1; [ $? = 64 ] || fail "a directory without style.css did not exit 64"
set -e

# No playwright-core: exit 2, file untouched.
command cp -f starter-theme/__tailwind__/screenshot.png "$theme/screenshot.png"
before=$(sha256sum "$theme/screenshot.png")
set +e; PLAYWRIGHT_CORE=/nonexistent node "$tool" http://127.0.0.1:1/ "$theme" >/dev/null 2>&1; rc=$?; set -e
[ "$rc" = 2 ] || fail "no playwright-core exited $rc, not 2"
[ "$(sha256sum "$theme/screenshot.png")" = "$before" ] || fail "a run with no browser changed screenshot.png"

port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
(cd "$tmp/site" && exec python3 -m http.server "$port" --bind 127.0.0.1) >/dev/null 2>&1 &
pid=$!
for _ in $(seq 1 50); do curl -s -o /dev/null "http://127.0.0.1:$port/" && break; sleep 0.1; done

set +e; out=$(node "$tool" "http://127.0.0.1:$port/" "$theme" 2>&1); rc=$?; set -e
if [ "$rc" = 2 ]; then
  [ "${CHECKS_REQUIRE_BROWSER:-0}" = 1 ] && fail "CHECKS_REQUIRE_BROWSER=1 and the capture cannot run: $out"
  skip "no playwright-core or Chrome on this machine: $out"
fi
[ "$rc" = 0 ] || fail "capture failed ($rc): $out"
[ "$(size "$theme/screenshot.png")" = 1200x900 ] || fail "the placeholder was not replaced by a 1200x900 capture: $(size "$theme/screenshot.png")"
printf '%s' "$out" | grep -c '^written ' >/dev/null || fail "the tool did not say it wrote the file: $out"

# A real preview is kept; --force replaces it; a failing page changes nothing.
python3 - "$theme/screenshot.png" <<'PY'
import struct, sys, zlib
w, h = 800, 600
raw = b''.join(b'\x00' + b'\x80\x20\x20' * w for _ in range(h))
def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
open(sys.argv[1], 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))
PY
out=$(node "$tool" "http://127.0.0.1:$port/" "$theme" 2>&1) || fail "keeping a real preview failed: $out"
[ "$(size "$theme/screenshot.png")" = 800x600 ] || fail "a real 800x600 preview was replaced without --force"
before=$(sha256sum "$theme/screenshot.png")
set +e; node "$tool" "http://127.0.0.1:$port/missing" "$theme" --force >/dev/null 2>&1; rc=$?; set -e
[ "$rc" = 1 ] || fail "a 404 page exited $rc, not 1"
[ "$(sha256sum "$theme/screenshot.png")" = "$before" ] || fail "a failed capture changed screenshot.png"
[ -z "$(find "$theme" -name '*.tmp-*')" ] || fail "a failed capture left a temporary file in the theme"
node "$tool" "http://127.0.0.1:$port/" "$theme" --force >/dev/null 2>&1 || fail "--force capture failed"
[ "$(size "$theme/screenshot.png")" = 1200x900 ] || fail "--force did not replace the preview"

echo "PASS: theme-screenshot replaces the placeholder with a 1200x900 capture and never touches a real preview without --force"
