#!/usr/bin/env bash
# Source me. The assertion helpers a check would otherwise redefine.
#
#   . "$(dirname "$0")/../lib/assert.sh"
#   require_tool php                     # prints "SKIP: php not installed", exits 0
#   need_token FILE 'literal text' "why it must be there"
#   fail "message"                       # prints FAIL: message on stderr, exits 1
#   skip "reason"                        # prints "SKIP: reason", exits 0
#
# tests/run.sh counts a line starting with SKIP as a skip, not a pass.

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

skip() { printf 'SKIP: %s\n' "$*"; exit 0; }

# Skip unless every named tool is on PATH. A job that must run the check regardless sets
# CHECKS_REQUIRE_TOOLS=1, which turns the skip into a failure.
require_tool() {
  local t
  for t in "$@"; do
    command -v "$t" >/dev/null 2>&1 && continue
    [ "${CHECKS_REQUIRE_TOOLS:-0}" = 1 ] && fail "CHECKS_REQUIRE_TOOLS=1 and $t is not installed"
    skip "$t not installed"
  done
}

# need_token FILE TOKEN [MESSAGE]: fixed-string grep of TOKEN in FILE.
need_token() {
  [ -f "$1" ] || fail "$1 does not exist"
  [ "$(grep -Fc -- "$2" "$1")" -gt 0 ] || fail "${3:-$1 no longer contains: $2}"
}
