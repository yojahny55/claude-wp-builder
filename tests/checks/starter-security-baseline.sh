#!/usr/bin/env bash
# The tailwind starter shipped no security baseline at all, and its template-functions.php
# even printed a pingback <link>. A full audit of a delivered build found XML-RPC and
# pingbacks on, /wp/v2/users and ?author=N enumerating logins, the file editors open
# (DISALLOW_FILE_EDIT lives in wp-config.php, which is never deployed with the repo) and
# no security response headers. Each starter now carries inc/security.php, loaded from
# functions.php.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

for st in __tailwind__ __cinematic__; do
  d=starter-theme/$st
  f=$d/inc/security.php
  [ -f "$f" ] || fail "$f is missing"
  # The require itself, not any mention of the path (a comment would satisfy a bare grep).
  grep -Eq "^[[:space:]]*require_once[[:space:]]+[A-Z_]+[[:space:]]*\.[[:space:]]*'/inc/security\.php'[[:space:]]*;" "$d/functions.php" \
    || fail "$d/functions.php never require_once's inc/security.php"
  for needle in "'xmlrpc_enabled', '__return_false'" "'xmlrpc_methods'" "'rsd_link'" "X-Pingback" \
      "'rest_endpoints'" "/wp/v2/users" "is_author()" "\$_GET['author']" "set_404()" \
      "'map_meta_cap'" "'edit_themes'" "'edit_plugins'" "'edit_files'" "'do_not_allow'" \
      "'send_headers'" "X-Content-Type-Options: nosniff" "X-Frame-Options: SAMEORIGIN" \
      "Referrer-Policy: strict-origin-when-cross-origin" "Permissions-Policy:" "header_remove('X-Powered-By')"; do
    # Both coding styles: the tailwind starter spaces its parentheses, the cinematic one does not.
    alt=${needle//(\'/( \'}; alt=${alt//\')/\' )}
    grep -Fq -- "$needle" "$f" || grep -Fq -- "$alt" "$f" || fail "$f lacks: $needle"
  done
  grep -q "defined *( *'ABSPATH' *)" "$f" || fail "$f has no ABSPATH guard"
done

# The pingback <link> is gone, and no second copy of the baseline lingers in performance.php.
grep -q "pingback_url" starter-theme/__tailwind__/inc/template-functions.php \
  && fail "the tailwind starter still prints a pingback <link>"
grep -Eq "rest_endpoints|xmlrpc_enabled|'rsd_link'" starter-theme/__cinematic__/inc/performance.php \
  && fail "the cinematic starter's performance.php duplicates inc/security.php"

echo PASS
