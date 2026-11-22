#!/usr/bin/env bash
# bin/wp-env-setup.sh runs as root through sudo, so its arguments are checked before any
# call and its quiet (--json) mode must not abort it. Runs the script against the stub
# harness (tests/lib/stub-path.sh) and asserts what it would have done. SCRIPT overrides the
# script under test, so the check can be pointed at an older copy to prove it fails there.
set -euo pipefail
. "$(dirname "$0")/../lib/assert.sh"
require_tool python3
cd "$(dirname "$0")/../.." || exit 1
. tests/lib/stub-path.sh
SCRIPT="${SCRIPT:-bin/wp-env-setup.sh}"
stub_path_init; REAL_MKDIR=$(PATH="$STUB_ORIG_PATH" command -v mkdir)   # mkdir and rm are stubbed on PATH
trap '"$STUB_REAL_RM" -rf "${W:-}"; stub_path_cleanup' EXIT
W=$(mktemp -d)
export WP_ENV_HOSTS_FILE="$W/hosts"; : > "$WP_ENV_HOSTS_FILE"

refused() { # name, then the command; expects non-zero and no sudo-class call
  local name="$1"; shift
  run_stubbed "$@"
  [ "$STUB_RC" != 0 ] || fail "$name: was not refused"
  [ -z "$(stub_destructive_calls)" ] || fail "$name: refused too late, calls recorded: $(stub_destructive_calls)"
}

# SH-01: --json must not abort the script at the first print helper.
run_stubbed bash "$SCRIPT" ssl-generate --domain="json-$$.local.com" --json
[ "$STUB_RC" = 0 ] || fail "ssl-generate --json exited $STUB_RC: $STUB_OUT"
grep -Fq "sudo [openssl]" "$STUB_LOG" || fail "ssl-generate --json did no work"
printf '%s' "$STUB_OUT" | python3 -c 'import sys,json; json.loads(sys.stdin.read())' 2>/dev/null \
  || fail "ssl-generate --json did not print valid JSON: $STUB_OUT"

# SH-10: permissions.
wp="$W/site"; "$REAL_MKDIR" -p "$wp/wp-content" "$W/plain"; : > "$wp/wp-config.php"
refused "permissions /" bash "$SCRIPT" permissions --path=/
refused "permissions \$HOME" bash "$SCRIPT" permissions --path="$HOME"
refused "permissions non-WP dir" bash "$SCRIPT" permissions --path="$W/plain"
refused "permissions bad web-user" bash "$SCRIPT" permissions --path="$wp" --web-user='x;id'
refused "permissions via dotdot" bash "$SCRIPT" permissions --path="$wp/.."
run_stubbed bash "$SCRIPT" permissions --path="$wp" --web-user=www-data
[ "$STUB_RC" = 0 ] || fail "permissions on a WP dir failed: $STUB_OUT"
grep -F '[find]' "$STUB_LOG" | grep >/dev/null -c '\[-name\] \[.git\]' || fail "permissions: .git is not pruned"
grep -F '[find]' "$STUB_LOG" | grep >/dev/null -c '\[node_modules\]' || fail "permissions: node_modules is not pruned"
! grep -Eq 'chown\] \[-R\]' "$STUB_LOG" || fail "permissions: recursive chown is back"
# A symlink inside the tree must not have its target re-owned: chown follows it unless the find
# is limited to real dirs/files and chown gets -h.
"$(PATH="$STUB_ORIG_PATH" command -v ln)" -s /etc/shadow "$wp/wp-content/evil-link"
run_stubbed bash "$SCRIPT" permissions --path="$wp" --web-user=www-data
chown_call=$(grep -F '[find]' "$STUB_LOG" | grep -F '[chown]' || true)
[ -n "$chown_call" ] || fail "permissions: no chown recorded"
grep -Fq '[-type] [d] [-o] [-type] [f]' <<<"$chown_call" || fail "permissions: chown is not limited to -type d / -type f (a symlink would be followed)"
grep -Fq '[chown] [-h]' <<<"$chown_call" || fail "permissions: chown lacks -h"
# Each change is applied relative to the directory find visits (-execdir), so an ancestor swapped
# for a symlink between the listing and the exec cannot send root's chmod/chown outside the tree.
grep -F '[find]' "$STUB_LOG" | grep >/dev/null -Fc '[-exec]' && fail "permissions: a path-resolving -exec is back"
for tool in chown 'chmod] [755' 'chmod] [644'; do
  grep -F '[find]' "$STUB_LOG" | grep -F "[-execdir] [$tool" | grep >/dev/null -Fc '[{}] [+]' || fail "permissions: $tool is not -execdir ... {} +"
done
# find runs under a sanitized absolute PATH (a relative or empty PATH entry aborts -execdir).
fcalls=$(grep -F '[find]' "$STUB_LOG")
[ -n "$fcalls" ] || fail "permissions: no find recorded"
while IFS= read -r l; do
  grep -Eq '^sudo \[env\] \[PATH=(/[^]:]+)(:/[^]:]+)*\] \[find\]' <<<"$l" || fail "permissions: find is not run as sudo env PATH=<absolute> find: $l"
done <<<"$fcalls"
# The writable directories are changed by find -type d -execdir, not by a separate [[ -L ]] then chmod.
grep -F '[find]' "$STUB_LOG" | grep -F '[-name] [uploads]' | grep -F '[-type] [d]' | grep >/dev/null -Fc '[-execdir] [chmod] [775]' \
  || fail "permissions: uploads is not chmod-ed by find -type d -execdir"
! grep -F 'sudo [chmod]' "$STUB_LOG" | grep >/dev/null -Fc '775' || fail "permissions: a bare sudo chmod 775 is back"
# A writable-directory entry that is a symlink is not chmod-ed through.
"$REAL_MKDIR" -p "$W/elsewhere"; "$(PATH="$STUB_ORIG_PATH" command -v ln)" -s "$W/elsewhere" "$wp/wp-content/plugins"
run_stubbed bash "$SCRIPT" permissions --path="$wp" --web-user=www-data
[ "$STUB_RC" = 0 ] || fail "permissions with a symlinked plugins dir failed: $STUB_OUT"
! grep -F 'sudo [env]' "$STUB_LOG" | grep -F '[chmod] [775]' | grep >/dev/null -Fc '[-name] [plugins]' || fail "permissions: chmod 775 followed a symlinked wp-content/plugins"
grep -Fq 'symlink' <<<"$STUB_OUT" || fail "permissions: no warning for the symlinked directory"

# SH-12: vhost-install --dest, service-reload --service, native-setup --web-server.
echo 'x' > "$W/v.conf"
for d in /etc/passwd /etc/nginx/../passwd /etc/nginx/../../etc/passwd /etc/cron.d/x /tmp/x.conf; do
  refused "vhost-install --dest=$d" bash "$SCRIPT" vhost-install --src="$W/v.conf" --dest="$d"
done
run_stubbed bash "$SCRIPT" vhost-install --src="$W/v.conf" --dest=/etc/nginx/conf.d/ok.conf
[ "$STUB_RC" = 0 ] && stub_called sudo || fail "vhost-install to a valid dest was refused: $STUB_OUT"
for s in sshd 'nginx;id' cron; do
  refused "service-reload --service=$s" bash "$SCRIPT" service-reload --service="$s"
done
for s in nginx apache php-fpm php8.3-fpm; do
  run_stubbed bash "$SCRIPT" service-reload --service="$s"
  [ "$STUB_RC" = 0 ] || fail "service-reload --service=$s was refused: $STUB_OUT"
done
refused "native-setup unknown web server" bash "$SCRIPT" native-setup --domain="ws-$$.local.com" --document-root="$W" --web-server=lighttpd
[ ! -s "$WP_ENV_HOSTS_FILE" ] || fail "native-setup wrote hosts before validating --web-server"

# SH-03: Debian apache layout enables the site and modules, between install and reload. The
# probe override picks the layout; the destination stays a fixed /etc path either way.
run_stubbed env WP_ENV_HTTPD_LAYOUT_PROBE="$W/no-such-dir" bash "$SCRIPT" native-setup --domain="deb-$$.local.com" --document-root="$W" --web-server=apache --vhost-src="$W/v.conf" --no-ssl
[ "$STUB_RC" = 0 ] || fail "native-setup apache (debian layout) failed: $STUB_OUT"
grep -Fq "sudo [install] [-m] [644] [-o] [root] [-g] [root] [$W/v.conf] [/etc/apache2/sites-available/deb-$$.local.com.conf]" "$STUB_LOG" \
  || fail "debian layout did not install to /etc/apache2/sites-available/<domain>.conf"
l_inst=$(grep -n 'sudo \[install\]' "$STUB_LOG" | sed -n 1p | cut -d: -f1)
l_mod=$(grep -n 'sudo \[a2enmod\] \[ssl\] \[proxy_fcgi\] \[rewrite\]' "$STUB_LOG" | sed -n 1p | cut -d: -f1)
l_site=$(grep -n "sudo \[a2ensite\] \[deb-$$.local.com\]" "$STUB_LOG" | sed -n 1p | cut -d: -f1)
l_rel=$(grep -n 'sudo \[systemctl\]' "$STUB_LOG" | sed -n 1p | cut -d: -f1)
[ -n "$l_inst" ] && [ -n "$l_mod" ] && [ -n "$l_site" ] && [ -n "$l_rel" ] || fail "a2enmod/a2ensite/reload not all recorded"
[ "$l_inst" -lt "$l_mod" ] && [ "$l_mod" -lt "$l_rel" ] && [ "$l_site" -lt "$l_rel" ] || fail "a2enmod/a2ensite not between install and reload"
# the RHEL layout installs under /etc/httpd/conf.d and must not call them
"$REAL_MKDIR" -p "$W/confd"
run_stubbed env WP_ENV_HTTPD_LAYOUT_PROBE="$W/confd" bash "$SCRIPT" native-setup --domain="rhel-$$.local.com" --document-root="$W" --web-server=apache --vhost-src="$W/v.conf" --no-ssl
[ "$STUB_RC" = 0 ] || fail "native-setup apache (rhel layout) failed: $STUB_OUT"
grep -Fq "sudo [install] [-m] [644] [-o] [root] [-g] [root] [$W/v.conf] [/etc/httpd/conf.d/rhel-$$.local.com.conf]" "$STUB_LOG" \
  || fail "rhel layout did not install to /etc/httpd/conf.d/<domain>.conf"
! grep -q a2ensite "$STUB_LOG" || fail "a2ensite called on the RHEL layout"
! grep -q a2enmod "$STUB_LOG" || fail "a2enmod called on the RHEL layout"

# A refused destination or web server leaves nothing behind: no hosts line, no sudo at all.
: > "$WP_ENV_HOSTS_FILE"
refused "native-setup caddy --vhost-src" bash "$SCRIPT" native-setup --domain="cad-$$.local.com" --document-root="$W" --web-server=caddy --vhost-src="$W/v.conf"
[ ! -s "$WP_ENV_HOSTS_FILE" ] || fail "native-setup wrote hosts before refusing caddy --vhost-src"
# The validator itself is exercised through a destination the layout can never produce.
refused "native-setup domain with dotdot" bash "$SCRIPT" native-setup --domain="../x" --document-root="$W" --web-server=nginx --vhost-src="$W/v.conf"
[ ! -s "$WP_ENV_HOSTS_FILE" ] || fail "native-setup wrote hosts for a bad domain"

echo PASS
