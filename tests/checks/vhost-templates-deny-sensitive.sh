#!/usr/bin/env bash
# Native vhost templates: they are copied to real servers with the project root as docroot, and
# used to deny only /.ht. That left project state files (.wp-create*.json and their .bak),
# .git/, .env, dumps and backups downloadable, and ran PHP inside uploads/. Each template must
# deny them, and the {{placeholders}} /wp-create fills in must survive the edit.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
d=templates/native

for f in nginx.conf.tpl nginx-no-ssl.conf.tpl; do
  p="$d/$f"
  grep -Fq 'location ~ /\.(?!well-known) { deny all; }' "$p" || fail "$f: dotfiles not denied"
  grep -Fq 'location ~* \.(sql|bak|log)$ { deny all; }' "$p" || fail "$f: sql/bak/log not denied"
  grep -Fq 'location ~* \.bak- { deny all; }' "$p" || fail "$f: .bak-* not denied"
  grep -Fq 'location ~* /uploads/.*\.php$ { deny all; }' "$p" || fail "$f: PHP in uploads not denied"
  grep -Fq 'try_files $uri =404;' "$p" || fail "$f: no try_files guard before fastcgi"
  ! grep -Fq 'location ~ /\.ht {' "$p" || fail "$f: still has the narrow /.ht rule"
  # regex locations match in order: the denies must precede the PHP block
  deny=$(grep -n 'uploads/\.\*\\\.php' "$p" | head -1 | cut -d: -f1)
  php=$(grep -n 'location ~ \\\.php\$' "$p" | head -1 | cut -d: -f1)
  [ -n "$deny" ] && [ -n "$php" ] && [ "$deny" -lt "$php" ] || fail "$f: uploads deny must come before the PHP location"
  for ph in '{{domain}}' '{{document_root}}' '{{php_fpm_sock}}' '{{max_upload_size}}'; do
    grep -Fq "$ph" "$p" || fail "$f lost placeholder $ph"
  done
done
for ph in '{{ssl_cert}}' '{{ssl_key}}'; do grep -Fq "$ph" "$d/nginx.conf.tpl" || fail "nginx.conf.tpl lost $ph"; done
for ph in '{{ssl_cert}}' '{{ssl_key}}'; do grep -Fq "$ph" "$d/apache.conf.tpl" || fail "apache.conf.tpl lost $ph"; done

for f in apache.conf.tpl apache-no-ssl.conf.tpl; do
  p="$d/$f"
  grep -Fq '<DirectoryMatch "/\.(?!well-known)">' "$p" || fail "$f: dot-directories not denied"
  grep -Fq '\.(sql|bak|log)$' "$p" || fail "$f: sql/bak/log not denied"
  grep -Fq '\.bak-' "$p" || fail "$f: .bak-* not denied"
  grep -Fq '<DirectoryMatch "/uploads/">' "$p" || fail "$f: PHP in uploads not denied"
  for ph in '{{domain}}' '{{document_root}}' '{{php_fpm_sock}}'; do
    grep -Fq "$ph" "$p" || fail "$f lost placeholder $ph"
  done
done

c=$d/Caddyfile.tpl
grep -Fq 'path */.*' "$c" || fail "Caddyfile: dotfiles path pattern missing"
grep -Fq 'not path /.well-known/*' "$c" || fail "Caddyfile: dotfiles not denied (or .well-known not excepted)"
grep -Fq 'path *.bak' "$c" && grep -Fq 'path *.log' "$c" && grep -Fq 'path *.sql' "$c" || fail "Caddyfile: sql/bak/log not denied"
grep -Fq '*.bak-*' "$c" || fail "Caddyfile: .bak-* not denied"
grep -Fq '/wp-content/uploads/*.php' "$c" || fail "Caddyfile: PHP in uploads not denied"
for ph in '{{domain}}' '{{document_root}}' '{{php_fpm_sock}}'; do grep -Fq "$ph" "$c" || fail "Caddyfile lost $ph"; done

echo PASS
