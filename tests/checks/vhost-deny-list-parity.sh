#!/usr/bin/env bash
# The three native vhost templates (nginx, apache, Caddyfile) used to deny different things:
# only Caddy refused /xmlrpc.php, only Caddy and Apache covered phar/pht(ml) in uploads, and
# archives (.sql.gz, .zip, .tar.gz) that the gitignore treats as dumps were served by all three.
# templates/native/_deny.list is the single reference; every engine must cover every entry, and
# no local template may send HSTS (a pinned self-signed host cannot be clicked through).
# nginx and Apache: the deny regexes are read out of the template and run against sample URLs.
# Caddy: its path tokens are compared whole (a substring match let `*.sql` hide behind `*.sql.gz`).
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
d=templates/native
list=$d/_deny.list
[ -f "$list" ] || fail "$list missing"

# One deny regex per line, prefixed F (matches the file name) or L (matches the URL path).
regexes() {
  case $1 in
    nginx*) sed -n 's/^ *location ~\*\{0,1\} *"\{0,1\}\(.*[^"]\)"\{0,1\} { deny all; }$/L\1/p' "$2";;
    apache*)
      sed -n 's/^ *<LocationMatch "\(.*\)">$/L\1/p' "$2"
      sed -n 's/^ *<FilesMatch "\(.*\)">$/F\1/p' "$2";;
    Caddy*) sed -n 's/^ *@[a-z]* path_regexp \(.*\)$/L\1/p' "$2";;
  esac
}
# Block-aware tokens of a Caddyfile: "<block> pos|neg <word>" for each word of a (not) path line.
caddy_tokens() {
  awk '/^ *@[A-Za-z]+ \{ *$/ { b = $1 } 
       /^ *path / { for (i = 2; i <= NF; i++) print b, "pos", $i }
       /^ *not path / { for (i = 3; i <= NF; i++) print b, "neg", $i }' "$1"
}
denied() { # regex-lines url
  local url=$2 base=${2##*/} line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case ${line:0:1} in
      L) printf '%s\n' "$url" | grep >/dev/null -Pc -- "${line:1}" && return 0;;
      F) printf '%s\n' "$base" | grep >/dev/null -Pc -- "${line:1}" && return 0;;
    esac
  done <<< "$1"
  return 1
}

checked=0 entries=0
while read -r kind value; do case "$kind" in ''|'#'*) continue;; esac; entries=$((entries + 1)); done < "$list"
templates="nginx.conf.tpl nginx-no-ssl.conf.tpl apache.conf.tpl apache-no-ssl.conf.tpl Caddyfile.tpl"
tcount=0
for f in $templates; do
  tcount=$((tcount + 1))
  p=$d/$f
  ! grep >/dev/null -ic 'Strict-Transport-Security' "$p" || fail "$f: HSTS on a self-signed local host locks the browser out once the certificate expires"
  rx=$(regexes "$f" "$p")
  [ -n "$rx" ] || fail "$f: no deny regex found"
  if [ "$f" = Caddyfile.tpl ]; then tok=$(caddy_tokens "$p"); [ -n "$tok" ] || fail "$f: no path tokens found"; fi
  while read -r kind value; do
    case "$kind" in ''|'#'*) continue;; esac
    checked=$((checked + 1))
    case "$kind" in
      ext|ext-outside)
        up=/wp-content/uploads/2026/x.$value
        if [ "$f" = Caddyfile.tpl ]; then
          blk=$(printf '%s\n' "$tok" | awk -v w="*.$value" '$2 == "pos" && $3 == w { print $1 }' | sed -n 1p)
          [ -n "$blk" ] || fail "$f: *.$value not denied"
          has_neg=$(printf '%s\n' "$tok" | awk -v b="$blk" '$1 == b && $2 == "neg" && $3 == "/wp-content/uploads/*" { print "y" }' | sed -n 1p)
          if [ "$kind" = ext-outside ]; then [ -n "$has_neg" ] || fail "$f: *.$value must be exempt under /wp-content/uploads/"
          else [ -z "$has_neg" ] || fail "$f: *.$value must be denied under uploads too"; fi
        else
          denied "$rx" "/backup.$value" || fail "$f: /backup.$value not denied"
          denied "$rx" "/sub/dir/site.$value" || fail "$f: /sub/dir/site.$value not denied"
          if [ "$kind" = ext-outside ]; then
            ! denied "$rx" "$up" || fail "$f: $up (media library) must be served"
          else
            denied "$rx" "$up" || fail "$f: $up not denied"
          fi
        fi;;
      path)
        if [ "$f" = Caddyfile.tpl ]; then
          for w in "$value" "$value/*"; do
            printf '%s\n' "$tok" | awk -v w="$w" '$2 == "pos" && $3 == w { f = 1 } END { exit !f }' || fail "$f: path $w not denied"
          done
        else
          denied "$rx" "$value" || fail "$f: $value not denied"
          denied "$rx" "$value/x" || fail "$f: $value/x (PATH_INFO) not denied"
        fi;;
      uploads)
        denied "$rx" "/wp-content/uploads/2026/e.$value" || fail "$f: .$value under uploads not denied";;
      *) fail "unknown kind '$kind' in $list";;
    esac
  done < "$list"
done
[ "$checked" -eq $((entries * tcount)) ] || fail "checked $checked, expected $((entries * tcount)): the list parser broke"
[ "$entries" -gt 0 ] || fail "empty deny list"

# nginx: regex locations match in order, so the xmlrpc deny must precede the PHP block.
for f in nginx.conf.tpl nginx-no-ssl.conf.tpl; do
  x=$(grep -n 'xmlrpc' "$d/$f" | grep -F 'location' | sed -n 1p | cut -d: -f1 || true)
  php=$(grep -Fn 'location ~ \.php$' "$d/$f" | sed -n 1p | cut -d: -f1 || true)
  [ -n "$x" ] && [ -n "$php" ] && [ "$x" -lt "$php" ] || fail "$f: xmlrpc deny must come before the PHP location"
done
echo PASS
