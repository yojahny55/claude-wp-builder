#!/usr/bin/env bash
# Browsers are resolved, never installed. bin/audit-suite.sh ran `playwright install
# chromium`, which downloads a revision-pinned build; on a machine whose policy forbids
# that, the audit died on the install. Its config declared firefox and webkit projects that
# no pass ever ran. bin/lib/browsers.mjs now finds an existing executable, the suite passes
# it through a preload, and the other engines run when they exist and are skipped with a
# notice when they do not.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
command -v node >/dev/null || { echo "SKIP: node not installed"; exit 0; }

lib=bin/lib/browsers.mjs
runner=bin/audit-suite.sh

# No runner or doc tells anyone to install a browser.
for f in "$runner" bin/demo-verify.mjs bin/composition-preview.mjs bin/tailwindify-parity.mjs \
    commands/wp-audit.md commands/wp-demo-verify.md commands/wp-demo.md commands/wp-yolo.md; do
  [ -f "$f" ] || continue
  if grep -v '^\s*#' "$f" | grep -Eq 'playwright install( |$|")|npx playwright install'; then
    fail "$f still installs a browser (or tells the user to)"
  fi
done

# Behaviour: a fake cache with two revisions, and one with nothing in it.
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mk() { mkdir -p "$(dirname "$1")"; printf '#!/bin/sh\n' > "$1"; chmod +x "$1"; }
mk "$tmp/cache/firefox-1500/firefox/firefox"
mk "$tmp/cache/firefox-1543/firefox/firefox"
mk "$tmp/cache/chromium_headless_shell-1243/chrome-linux/headless_shell"
mk "$tmp/cache/webkit-2359/pw_run.sh"
# PLAYWRIGHT_CORE points at a directory with no manifest, so no real playwright-core on this
# machine decides the revision.
mkdir -p "$tmp/nocore"
run() { env -u WP_BROWSER_CHROMIUM -u WP_BROWSER_FIREFOX -u WP_BROWSER_WEBKIT \
  HOME="$tmp/home" PLAYWRIGHT_CORE="${core:-$tmp/nocore}" PLAYWRIGHT_BROWSERS_PATH="$1" node "$lib" "$2"; }
[ "$(run "$tmp/cache" firefox)" = "$tmp/cache/firefox-1543/firefox/firefox" ] \
  || fail "$lib does not pick the newest cached Firefox revision"
[ "$(run "$tmp/cache" webkit)" = "$tmp/cache/webkit-2359/pw_run.sh" ] || fail "$lib does not find a cached WebKit"
mkdir -p "$tmp/empty"
set +e; out=$(run "$tmp/empty" firefox); code=$?; set -e
[ "$code" -eq 2 ] && [ -z "$out" ] || fail "$lib with no Firefox exited $code ('$out') instead of 2 with no output"
# The revision the driving playwright-core pins wins over a newer cached one, and the choice
# is logged with both revisions; a pin that is not cached falls back to the newest and says so.
mkdir -p "$tmp/core"
printf '{"browsers":[{"name":"firefox","revision":"1500"},{"name":"webkit","revision":"2400"}]}' > "$tmp/core/browsers.json"
[ "$(core="$tmp/core" run "$tmp/cache" firefox 2>/dev/null)" = "$tmp/cache/firefox-1500/firefox/firefox" ] \
  || fail "$lib does not prefer the revision playwright-core's browsers.json pins"
log=$(core="$tmp/core" run "$tmp/cache" firefox 2>&1 >/dev/null)
grep -Fq 'firefox-1500/firefox/firefox (revision 1500, the pinned revision' <<<"$log" || fail "$lib does not log the pinned choice: $log"
log=$(core="$tmp/core" run "$tmp/cache" webkit 2>&1 >/dev/null)
grep -Fq 'revision 2359, MISMATCH, 2400 is not cached' <<<"$log" || fail "$lib does not log a pin/cache mismatch: $log"
[ "$(WP_BROWSER_FIREFOX="$tmp/cache/firefox-1500/firefox/firefox" node "$lib" firefox)" = "$tmp/cache/firefox-1500/firefox/firefox" ] \
  || fail "$lib ignores the WP_BROWSER_FIREFOX override"

# The runner resolves, preloads and runs the other engines.
grep -Fq 'node "$here/bin/lib/browsers.mjs" "$1"' "$runner" || fail "$runner does not resolve browsers through bin/lib/browsers.mjs"
grep -Fq 'chromium_exe="$(find_browser chromium)"' "$runner" || fail "$runner does not resolve an existing Chromium"
# Only browsers.mjs's exit 2 means "none found"; a crash of the lookup stops the run.
grep -Eq '^[[:space:]]*2\)[[:space:]]*;;' "$runner" && grep -Fq 'failed (exit $rc) looking up' "$runner" \
  || fail "$runner reads a crash of browsers.mjs as a missing browser"
grep -Fq -- '--require $here/bin/lib/pw-executables.cjs' "$runner" || fail "$runner does not hand the executables to the vendored suite"
grep -Fq -- '--project="$engine"' "$runner" || fail "$runner never runs the firefox/webkit projects"
grep -Fq 'pass skipped (nothing is downloaded)' "$runner" || fail "$runner does not skip a missing engine with a notice"
grep -Eq 'browsers.mjs" (chromium|firefox|webkit) 2>/dev/null' "$runner" && fail "$runner hides the browser choice log"
grep -Fq "opts.executablePath = exe[name]" bin/lib/pw-executables.cjs || fail "pw-executables.cjs does not default executablePath"
# The runner exports and the preload reads the same three names.
for e in CHROMIUM FIREFOX WEBKIT; do
  grep -Eq "^export .*\bWP_AUDIT_$e=" "$runner" || fail "$runner does not export WP_AUDIT_$e"
  grep -Fq "process.env.WP_AUDIT_$e" bin/lib/pw-executables.cjs || fail "pw-executables.cjs does not read WP_AUDIT_$e"
done

echo PASS
