#!/usr/bin/env bash
# A real build shipped with no favicon at all — the demo declared one on every
# page, a Tailwind conversion dropped the <link> tag, and nothing caught it
# because /wp-finalize's theme-structure check never looked for it. Separately,
# wp-login.php is the one page that never enqueues the theme's stylesheet, so it
# stays WordPress's stock grey screen — the first thing the client sees every
# day — unless something re-skins it, and nothing checked that either.
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }

f=commands/wp-finalize.md
[ -f "$f" ] || fail "$f is missing"

grep -Eiq 'favicon|site.icon' "$f" || fail "$f: no favicon/site-icon check in the finalize checklist"
grep -Fq "has_site_icon()" "$f" || fail "$f: favicon check does not account for a Site Icon set in wp-admin"

grep -Eiq 'login screen|wp-login\.php' "$f" || fail "$f: no login-screen branding check in the finalize checklist"
grep -Eiq 'login_enqueue_scripts|login_headerurl|login_headertext' "$f" \
  || fail "$f: login-screen check names no login hook to look for"
grep -Eq 'inc/seed/[^ ]*login' "$f" \
  || fail "$f: login-screen check drops the seed-file alternative (inc/seed/*login*.php)"

echo PASS
