#!/usr/bin/env bash
# /wp-clone only replaced the plain `https://old-host`. Elementor stores URLs JSON-escaped
# (`https:\/\/old-host`) in postmeta, so 149 values on a real store clone kept pointing at
# production. Production cache drop-ins (object-cache.php / advanced-cache.php) also broke
# every WP-CLI call locally. Pins both fixes in the command as a run reads it.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
. tests/checks/lib/expand-command.sh; expand_command commands/wp-clone.md; f=$EXPANDED
need() { grep -Fq -- "$1" "$f" || fail "wp-clone does not document: $2"; }

need "search-replace 'https:\\/\\/staging.example.com'" 'escaped https pass (Path A)'
need "search-replace 'http:\\/\\/staging.example.com'" 'escaped http pass (Path A)'
need "search-replace 'https:\\/\\/old-domain.com'" 'escaped https pass (Path B)'
need '_elementor_element_cache' 'the Elementor postmeta that holds escaped URLs'
need 'elementor flush-css' 'regenerating Elementor CSS'
need "LIKE '%<remote-domain>%'" 'verification of postmeta for the host in either form'
grep -Fq 'double the backslashes' "$f" || fail "no shell-quoting caveat for backslashes"

need 'object-cache.php' 'parking the object-cache drop-in'
need 'advanced-cache.php' 'parking the page-cache drop-in'
need '.bak' 'parking as .bak'
need 'WP_CACHE' 'setting WP_CACHE false'
need 'never delete' 'parking rather than deleting'
need 'manifest' 'recording the parked drop-ins'
n=$(grep -c 'Park the cache drop-ins' "$f" || true); [ "$n" -ge 1 ] || fail "no drop-in step"

echo PASS
