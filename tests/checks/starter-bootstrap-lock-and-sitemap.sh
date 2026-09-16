#!/usr/bin/env bash
# Two runtime bugs found on a real build, both silent (no error, no log line):
#
#   1. The ACF Local JSON bootstrap lock is created with fopen(..., 'c') under the
#      process's default umask, so it comes out 0644 owned by whichever user runs
#      first — the web user on a page load, the CLI user on a wp-cli run. The other
#      user can then never open it for an exclusive lock, and flock() failing
#      silently skips every later bootstrap for that user, forever. chmod 0666 right
#      after creation fixes it for both users at once.
#   2. A site with no native `post` content 404s its own /wp-sitemap.xml: WP::handle_404()
#      only clears the 404 when $wp_query->posts is non-empty, and a sitemap route runs
#      no post query of its own. `pre_handle_404` is core's escape hatch for this.
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }

for f in starter-theme/__tailwind__/functions.php starter-theme/__cinematic__/functions.php; do
  [ -f "$f" ] || fail "$f is missing"
  grep -Fq "bootstrap.lock" "$f" || fail "$f: ACF bootstrap lock not found"
  grep -Fq "chmod" "$f" || fail "$f: bootstrap lock is never chmod'd — the other user can never open it for writing"
  grep -Eq "0666" "$f" || fail "$f: bootstrap lock is not widened to 0666"
done

ts=starter-theme/__tailwind__/inc/theme-setup.php
[ -f "$ts" ] || fail "$ts is missing"
grep -Fq "pre_handle_404" "$ts" || fail "$ts: no pre_handle_404 guard for the sitemap route"
grep -Fq "get( 'sitemap'" "$ts" || grep -Fq "get('sitemap'" "$ts" \
  || fail "$ts: pre_handle_404 guard does not check the sitemap query var"

echo PASS
