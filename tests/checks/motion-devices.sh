#!/usr/bin/env bash
# Drive motion.js in a real browser and assert what it does to the DOM.
#
# CLAUDE.md records this as a gap in as many words: "motion.js's GSAP reveal branch is
# never walked, because nothing in the suite runs a browser", and the reduced-motion
# behaviour of the pan device is described at length in a comment and verified by nobody.
# That comment is doing real work -- it decides which box scrolls by MEASUREMENT rather
# than by name, and it deliberately attaches nothing when neither box overflows, because a
# focusable named region that scrolls nothing is a dead tab stop. A contract grep cannot
# see a negative behaviour like that, and a refactor loses it silently.
#
# So this one runs the code. It is the second check in the suite that does (after
# wp-polylang-integration.sh) and the first that needs a browser.
#
# It SKIPS rather than failing when there is no browser, the same shape as the WordPress
# fixture and the Polylang live suite: a machine without Chrome should report what it
# could not measure, not a red suite.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

driver=tests/fixtures/motion/drive.mjs
fixture=tests/fixtures/motion/pan.html
motion=starter-theme/__tailwind__/assets/js/src/motion.js

for f in "$driver" "$fixture" "$motion"; do
  [ -f "$f" ] || fail "$f is missing"
  [ -r "$f" ] || fail "$f exists but cannot be read"
done

command -v node >/dev/null 2>&1 || fail "node is not on PATH; this check executes motion.js rather than grepping it"
node --check "$driver" >/dev/null 2>&1 || fail "$driver does not parse"

set +e
out=$(node "$driver" 2>&1)
status=$?
set -e

# Exit 2 is the driver's "no browser / no playwright-core" signal, and is the only status
# that is neither a pass nor a failure. Distinguishing it from a real failure matters: a
# suite that reports a missing browser as a broken device teaches everyone to ignore it.
if [ "$status" -eq 2 ]; then
  echo "$out" | sed 's/^/  /'
  # A skip is the right answer on a machine with no browser and the wrong answer on one
  # that is supposed to have one. The caller knows which it is, so the caller says so --
  # and it lives here rather than in the workflow because a second invocation to check the
  # first invocation's output costs a whole extra browser launch and gives flakiness two
  # chances instead of one.
  if [ -n "${MOTION_REQUIRE_BROWSER:-}" ]; then
    fail "no browser available, but MOTION_REQUIRE_BROWSER is set -- this environment is supposed to have one"
  fi
  echo "SKIP: no browser available (install playwright-core and a Chrome, or set CHROME_PATH)"
  exit 0
fi

if [ "$status" -ne 0 ]; then
  echo "$out" | sed 's/^/  /'
  fail "motion.js behaved differently from the contract its own comments describe"
fi

# Do not trust the banner over the evidence beside it -- the same rule the WordPress
# fixture check learned the hard way when a fixture printed OK with failures above it.
case "$out" in
  *"FAIL ["*) echo "$out" | sed 's/^/  /'; fail "the driver printed MOTION OK alongside a FAIL line" ;;
esac
case "$out" in
  *"MOTION OK"*) : ;;
  *) echo "$out" | sed 's/^/  /'; fail "the driver did not report MOTION OK" ;;
esac

n=$(printf '%s' "$out" | grep -c '^ok  ' || true)
[ "${n:-0}" -gt 0 ] || fail "the driver reported OK but asserted nothing"

echo "PASS: motion.js pan device drives correctly under reduced motion ($n assertions in a real browser)"
