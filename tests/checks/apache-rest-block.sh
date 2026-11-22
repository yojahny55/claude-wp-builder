#!/usr/bin/env bash
# The REST block in skills/wp-environments/references/apache-rest-block.md is a security rule
# whose first draft let a dozen encodings through. This check takes the rule exactly as the
# reference prints it, loads it into a throwaway Apache, and replays the reference's table:
# every blocked form must get 403, every open one must not. It also pins the PHP half (lint and
# the hook) and the warnings that keep the rule from being read as a boundary.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

ref=skills/wp-environments/references/apache-rest-block.md

# 1. Contract wording.
need_token skills/wp-environments/SKILL.md 'references/apache-rest-block.md' \
  "wp-environments SKILL.md no longer links the Apache REST block reference"
need_token "$ref" 'Apache is the outer layer, not the boundary'
need_token "$ref" 'rest_pre_dispatch'
need_token "$ref" 'Do not exempt by cookie'
need_token "$ref" 'rest_url_prefix'
need_token "$ref" 'never in `.htaccess`'
need_token "$ref" 'never calls `unescape()`'
need_token "$ref" 'wc/store'
need_token "$ref" 'Verify by result'

block() { sed -n "/<!-- apache-rest-block:$1 -->/,/<!-- \/apache-rest-block:$1 -->/p" "$ref" | sed '1,2d;$d' | sed '$d'; }
rule="$(block rule)"
php_half="$(block mu-plugin)"
[ "$(printf '%s\n' "$rule" | grep -c '^<If ')" = 1 ] || fail "the reference's rule block has no single <If> line"
[ "$(printf '%s\n' "$rule" | grep -c 'DOCUMENT_ROOT')" = 1 ] || fail "the rule no longer names the site by its document root"
[ "$(printf '%s\n' "$rule" | grep -c 'HTTP_HOST')" = 0 ] || fail "the rule names the site by the Host header, which the client chooses"
[ "$(printf '%s\n' "$php_half" | grep -c 'rest_pre_dispatch')" -gt 0 ] || fail "the reference's mu-plugin block lost the hook"

tmp="$(mktemp -d)"
cleanup() {
  [ -f "$tmp/httpd.pid" ] && kill "$(cat "$tmp/httpd.pid")" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

# 2. The PHP half parses.
if command -v php >/dev/null 2>&1; then
  printf '%s\n' "$php_half" > "$tmp/rest-restricted.php"
  php -l "$tmp/rest-restricted.php" >/dev/null || fail "the reference's mu-plugin does not parse"
fi

# 3. Replay against a real Apache.
require_tool curl
httpd_bin="" ; mods=""
for b in httpd apache2 /usr/sbin/apache2 /usr/sbin/httpd; do
  command -v "$b" >/dev/null 2>&1 && { httpd_bin="$(command -v "$b")"; break; }
done
for m in /usr/lib/httpd/modules /usr/lib/apache2/modules /usr/lib64/httpd/modules; do
  [ -f "$m/mod_authz_core.so" ] && { mods="$m"; break; }
done
if [ -z "$httpd_bin" ] || [ -z "$mods" ]; then
  [ "${CHECKS_REQUIRE_TOOLS:-0}" = 1 ] && fail "CHECKS_REQUIRE_TOOLS=1 and no Apache 2.4 is installed"
  skip "no Apache 2.4 installed: the rule was NOT replayed"
fi

mkdir -p "$tmp/root" "$tmp/other"
echo ok > "$tmp/root/index.html"
echo ok > "$tmp/other/index.html"
# mktemp -d is 0700. Run as root, Apache drops to its run user and would answer 403 from the
# file system, which reads as the rule firing; let that user in and name it.
chmod 755 "$tmp" "$tmp/root" "$tmp/other"
run_as=""
if [ "$(id -u)" = 0 ]; then
  run_as="User nobody
Group $(id -gn nobody)"
fi
# The reference's placeholder document root becomes the throwaway site's.
rule="${rule//\/var\/www\/example/$tmp/root}"
lm() { [ -f "$mods/mod_$1.so" ] && echo "LoadModule $1_module $mods/mod_$1.so"; return 0; }

port=""
for _ in 1 2 3 4 5; do
  p=$(( 20000 + RANDOM % 20000 ))
  cat > "$tmp/httpd.conf" <<CONF
ServerRoot $tmp
Listen 127.0.0.1:$p
PidFile $tmp/httpd.pid
ErrorLog $tmp/error.log
$(lm mpm_event)
$(lm unixd)
$(lm authz_core)
$(lm dir)
DirectoryIndex index.html
ServerName localhost
$run_as
$rule
# The site is the first vhost, so it is also the default one: an unknown Host, the IP and a
# request with no Host all land on it.
<VirtualHost 127.0.0.1:$p>
  ServerName example.com
  ServerAlias www.example.com alias.example
  DocumentRoot $tmp/root
  <Directory $tmp/root>
    Require all granted
  </Directory>
</VirtualHost>
<VirtualHost 127.0.0.1:$p>
  ServerName other.example
  DocumentRoot $tmp/other
  <Directory $tmp/other>
    Require all granted
  </Directory>
</VirtualHost>
CONF
  "$httpd_bin" -t -f "$tmp/httpd.conf" >"$tmp/configtest.log" 2>&1 \
    || fail "Apache rejects the reference's rule: $(sed -n 1,3p "$tmp/configtest.log")"
  if "$httpd_bin" -f "$tmp/httpd.conf" -k start >/dev/null 2>&1; then
    for _ in $(seq 1 50); do
      curl -s -o /dev/null "http://127.0.0.1:$p/" && { port=$p; break; }
      sleep 0.1
    done
  fi
  [ -n "$port" ] && break
  [ -f "$tmp/httpd.pid" ] && kill "$(cat "$tmp/httpd.pid")" 2>/dev/null || true
done
[ -n "$port" ] || fail "the throwaway Apache did not start: $(sed -n 1,3p "$tmp/error.log" 2>/dev/null)"

code() { # code HOST PATH [extra curl args]
  local host=$1 path=$2; shift 2
  curl -s -o /dev/null -w '%{http_code}' -g --path-as-is -H "Host: $host" "$@" "http://127.0.0.1:$port$path"
}
blocked() { local c; c=$(code "$@"); [ "$c" = 403 ] || fail "not blocked (got $c): Host $1 $2"; }
open_()   { local c; c=$(code "$@"); [ "$c" != 403 ] || fail "blocked but must pass: Host $1 $2"; }

H=example.com
for p in /wp-json/ /wp-json /wp-json/wp/v2/users /WP-JSON/wp/v2/users //wp-json/ \
         /%77p-json/wp/v2/users /wp-json/contact-form-7/../wp/v2/users \
         /index.php/wp-json/wp/v2/users /wp-blog-header.php/wp-json/ \
         '/?rest_route=/wp/v2/users' '/?%72est_route=/wp/v2/users' '/?rest.route=/wp/v2/users' \
         '/?rest+route=/a' '/?rest%20route=/a' '/?rest[route=/a' '/?rest%5broute=/a' \
         '/?rest%2eroute=/a' '/?rest%5Froute=/a' '/?+rest_route=/a' '/?%20rest_route=/a' \
         '/?rest_route%00x=/a' '/?rest_route[]=/a' '/?rest_route' '/?REST_ROUTE=/a' \
         '/?a=b&rest_route=/wp/v2/users' '/?rest_route=%2Fcontact-form-7%2Fv1&rest_route=/wp/v2/users' \
         '/?rest_route=/a&%zz=1' '/wp-json/contact-form-7/v1/x?rest_route=/wp/v2/users'; do
  blocked "$H" "$p"
done
blocked 'example.com.' /wp-json/
blocked 'WWW.EXAMPLE.COM:443' /wp-json/
blocked alias.example /wp-json/wp/v2/users
blocked 127.0.0.1 /wp-json/wp/v2/users
blocked unknown.example '/?rest_route=/wp/v2/users'
[ "$(curl -s -o /dev/null -w '%{http_code}' --http1.0 -H 'Host:' "http://127.0.0.1:$port/wp-json/")" = 403 ] \
  || fail "not blocked: a request with no Host header"

for p in /wp-json/contact-form-7/v1/contact-forms/1/feedback /wp-admin/admin-ajax.php / \
         '/?s=rest_route' '/?payment_method=x' '/?x=1%26rest_route=/a' '/wp-jsonx' '/blog/wp-json-tips/'; do
  open_ "$H" "$p"
done
open_ other.example /wp-json/wp/v2/users

echo PASS
