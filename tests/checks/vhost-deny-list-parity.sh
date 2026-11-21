#!/usr/bin/env bash
# The three native vhost templates (nginx, apache, Caddyfile) used to deny different things:
# only Caddy refused /xmlrpc.php, only Caddy and Apache covered phar/pht(ml) in uploads, and
# archives (.sql.gz, .zip, .tar.gz) that the gitignore treats as dumps were served by all three.
# templates/native/_deny.list is the single reference; every engine must cover every entry, and
# no local template may send HSTS (a pinned self-signed host cannot be clicked through).
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
d=templates/native
list=$d/_deny.list
[ -f "$list" ] || fail "$list missing"

# The extension and uploads regexes are read out of each template, then run against sample names.
ext_re() {
  case $1 in
    nginx*) grep -o '~\* \\\.(sql|[^ ]*\$' "$2" | sed -n 1p | sed 's/^~\* //';;
    apache*) grep -o '\\\.(sql|[^"]*\$|' "$2" | sed -n 1p | sed 's/|$//';;
  esac
}
up_re() {
  case $1 in
    nginx*) grep -o '"/uploads/[^"]*"' "$2" | sed -n 1p | tr -d '"';;
    apache*) grep -o '(?i)^/wp-content/uploads/[^"]*' "$2" | sed -n 1p | sed 's/^(?i)//';;
    Caddy*) grep -o 'path_regexp (?i)^/wp-content/uploads/.*' "$2" | sed -n 1p | sed 's/^path_regexp (?i)//';;
  esac
}

checked=0
for f in nginx.conf.tpl nginx-no-ssl.conf.tpl apache.conf.tpl apache-no-ssl.conf.tpl Caddyfile.tpl; do
  p=$d/$f
  ! grep >/dev/null -ic 'Strict-Transport-Security' "$p" || fail "$f: HSTS on a self-signed local host locks the browser out once the certificate expires"
  ere=""; ure=$(up_re "$f" "$p")
  [ -n "$ure" ] || fail "$f: uploads deny rule not found"
  if [ "$f" != Caddyfile.tpl ]; then
    ere=$(ext_re "$f" "$p")
    [ -n "$ere" ] || fail "$f: extension deny rule not found"
  fi
  while read -r kind value; do
    case "$kind" in ''|'#'*) continue;; esac
    checked=$((checked + 1))
    case "$kind" in
      ext)
        if [ "$f" = Caddyfile.tpl ]; then
          grep -Fq "path *.$value" "$p" || fail "$f: *.$value not denied"
        else
          printf '%s\n' "backup/site.$value" | grep >/dev/null -Ec "$ere" || fail "$f: *.$value not denied"
        fi;;
      path)
        if [ "$f" = Caddyfile.tpl ]; then
          grep -Fq "path $value" "$p" || fail "$f: $value not denied"
        else
          grep >/dev/null -Ec "(location = $value \{ deny all; \}|\^$(printf '%s' "$value" | sed 's/\./\\\\./')\\$)" "$p" || fail "$f: $value not denied"
        fi;;
      uploads)
        printf '%s\n' "/wp-content/uploads/2026/e.$value" | grep >/dev/null -Eic "$ure" || fail "$f: .$value under uploads not denied";;
      *) fail "unknown kind '$kind' in $list";;
    esac
  done < "$list"
done
[ "$checked" -ge 60 ] || fail "only $checked entries checked: the list parser broke"
echo PASS
