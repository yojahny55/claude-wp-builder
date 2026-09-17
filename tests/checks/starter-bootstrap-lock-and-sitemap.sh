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
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $1"; exit 1; }

for f in starter-theme/__tailwind__/functions.php starter-theme/__cinematic__/functions.php; do
  [ -f "$f" ] || fail "$f is missing"
  grep -Fq "bootstrap.lock" "$f" || fail "$f: ACF bootstrap lock not found"
  grep -Fq "chmod" "$f" || fail "$f: bootstrap lock is never chmod'd — the other user can never open it for writing"
  grep -Eq "0666" "$f" || fail "$f: bootstrap lock is not widened to 0666"
done

for ts in starter-theme/__tailwind__/inc/theme-setup.php starter-theme/__cinematic__/inc/performance.php; do
  [ -f "$ts" ] || fail "$ts is missing"
  grep -Fq "pre_handle_404" "$ts" || fail "$ts: no pre_handle_404 guard for the sitemap route"
  grep -Fq "get( 'sitemap'" "$ts" || grep -Fq "get('sitemap'" "$ts" \
    || fail "$ts: pre_handle_404 guard does not check the sitemap query var"
done

# The ACF export strips 'ID', which acf_write_json_field_group() reads: both loaders
# must put it back, or a fresh group warns and stays PHP-local.
for f in starter-theme/__tailwind__/functions.php starter-theme/__cinematic__/functions.php; do
  grep -Fq "\$export['ID']" "$f" || fail "$f: Local JSON export does not restore the stripped ID key"
done

# agents/wp-template.md requires the ABSPATH guard in every PHP file a theme ships;
# the starter those themes are copied from has to meet the same rule.
unguarded=$(find starter-theme -name '*.php' -exec grep -LE "defined\( *['\"]ABSPATH['\"] *\)" {} + || true)
[ -z "$unguarded" ] || fail "starter PHP files without the ABSPATH guard: $unguarded"

# The starter registers per-language menu locations only; a bare 'primary'
# location renders nothing, in the starter's own part or in the agent's example.
for f in starter-theme/__tailwind__/template-parts/header/navigation.php agents/wp-template.md; do
  ! grep -Eq "'theme_location' *=> *'primary'" "$f" || fail "$f asks for an unregistered 'primary' menu location"
done
! grep -Fq 'https://example.com' starter-theme/__tailwind__/template-parts/footer/site-info.php \
  || fail "the starter footer still prints a placeholder designer credit"

echo PASS
