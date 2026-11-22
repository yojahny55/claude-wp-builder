#!/usr/bin/env bash
# templates/docker/docker-compose.yml.tpl mounts ./docker/nginx.conf as the webserver
# container's default.conf. For a long time nothing wrote that file: Docker then creates a
# directory at the mount source and the webserver container never starts. This check pins
# that /wp-create renders the template to that path, and serves the rendered template from a
# real nginx (the local nginx:alpine image, never pulled) to prove it parses, serves static
# files, and refuses what the native deny list refuses.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

tpl=templates/docker/nginx.conf.tpl
compose=templates/docker/docker-compose.yml.tpl
env_ref=skills/wp-create-run/references/env-templates.md

# 1. Contract: the compose file mounts it, /wp-create writes it, overwrite backs it up.
[ -f "$tpl" ] || fail "$tpl is missing"
need_token "$compose" './docker/nginx.conf:/etc/nginx/conf.d/default.conf'
need_token "$env_ref" 'templates/docker/nginx.conf.tpl'
need_token "$env_ref" 'docker/nginx.conf'
need_token "$env_ref" 'creates a root-owned *directory*'
need_token "$env_ref" 'If `docker/nginx.conf` is already a directory'
need_token "$env_ref" 'sudo rmdir docker/nginx.conf'
need_token skills/wp-create-run/references/overwrite.md 'Docker created is not a file to copy'
need_token skills/wp-create-run/references/overwrite.md '`docker/nginx.conf`'
need_token "$tpl" 'fastcgi_pass wordpress:9000;'
need_token "$tpl" 'woocommerce_uploads'
# The compose file's wordpress service must be the FPM image the template passes PHP to.
need_token "$compose" 'image: wordpress:php{{php_version}}-fpm'
# Every placeholder in the template is one env-templates.md documents.
for ph in $(grep -o '{{[a-z_]*}}' "$tpl" | sort -u); do
  grep -F -- "\`$ph\`" "$env_ref" >/dev/null || fail "$tpl uses $ph, which $env_ref does not document"
done

# 2. A real nginx.
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1 \
   || ! docker image inspect nginx:alpine >/dev/null 2>&1; then
  [ "${CHECKS_REQUIRE_TOOLS:-0}" = 1 ] && fail "CHECKS_REQUIRE_TOOLS=1 and no Docker with a local nginx:alpine image"
  skip "no Docker or no local nginx:alpine image: the config was NOT served"
fi
require_tool curl

tmp="$(mktemp -d)"
name="wpb-nginx-check-$$-$RANDOM"
cleanup() {
  docker rm -f "$name" >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap cleanup EXIT

sed 's/{{max_upload_size}}/64M/g' "$tpl" > "$tmp/default.conf"
grep -F '{{' "$tmp/default.conf" >/dev/null && fail "the rendered config still holds a placeholder"
www="$tmp/www"
mkdir -p "$www/.well-known" "$www/wp-content/uploads/woocommerce_uploads" "$www/assets"
echo home > "$www/index.html"
for f in index.php .env dump.sql backup.tar.gz site.zip wp-config.php.bak-1 .well-known/security.txt \
         wp-content/uploads/photo.zip wp-content/uploads/evil.php.jpg \
         wp-content/uploads/woocommerce_uploads/paid.pdf \
         wp-content/uploads/woocommerce_uploads/paid.png assets/site.css robots.txt; do
  echo x > "$www/$f"
done
# mktemp -d is 0700; the container's nginx user must read the tree.
chmod -R a+rX "$tmp"

# nginx resolves fastcgi_pass's host at start: point "wordpress" at the loopback.
docker run -d --pull=never --name "$name" --add-host wordpress:127.0.0.1 -p 127.0.0.1::80 \
  -v "$tmp/default.conf:/etc/nginx/conf.d/default.conf:ro" -v "$www:/var/www/html:ro" \
  nginx:alpine >/dev/null 2>"$tmp/run.err" || fail "nginx:alpine did not start: $(sed -n 1,3p "$tmp/run.err")"

port=""
for _ in $(seq 1 50); do
  port=$(docker port "$name" 80/tcp 2>/dev/null | sed -n 's/.*:\([0-9]*\)$/\1/p' | sed -n 1p) || true
  if [ -n "$port" ] && curl -s -o /dev/null "http://127.0.0.1:$port/"; then break; fi
  port=""
  if [ "$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null)" != true ]; then
    fail "nginx exited with the rendered config: $(docker logs "$name" 2>&1 | grep -E 'emerg|error' | sed -n 1,3p)"
  fi
  sleep 0.2
done
[ -n "$port" ] || fail "nginx did not answer: $(docker logs "$name" 2>&1 | grep -E 'emerg|error' | sed -n 1,3p)"
docker exec "$name" nginx -t >/dev/null 2>&1 || fail "nginx -t rejects the rendered config"

code() { curl -s -o /dev/null -w '%{http_code}' --path-as-is "http://127.0.0.1:$port$1"; }
denied() { local c; c=$(code "$1"); [ "$c" = 403 ] || fail "not denied (got $c): $1"; }
served() { local c; c=$(code "$1"); [ "$c" = 200 ] || fail "not served (got $c): $1"; }

for p in /.env /dump.sql /backup.tar.gz /site.zip /wp-config.php.bak-1 \
         /wp-content/uploads/evil.php.jpg /wp-content/uploads/woocommerce_uploads/paid.pdf \
         /wp-content/uploads/woocommerce_uploads/paid.png \
         /xmlrpc.php /xmlrpc.php/x; do
  denied "$p"
done
for p in /index.html /assets/site.css /robots.txt /.well-known/security.txt /wp-content/uploads/photo.zip; do
  served "$p"
done
# PHP goes to the FPM service, which is not running here: a gateway error, not a 403 or the source.
c=$(code /)
case "$c" in 502|504) ;; *) fail "/ (index.php) did not go to fastcgi (got $c)";; esac

echo PASS
