#!/usr/bin/env bash
# Clone-health preflight: does the audited host actually serve the site's internal URLs?
#
# Why this exists: an audit ran against a local clone of a site whose production web server
# was nginx. The clone had no `.htaccess` (nginx never needed one), so on the local Apache
# every internal URL answered 404 while the home page answered 200. Every page measurement of
# the run was silently wrong until a person asked about it. `wp rewrite flush --hard` wrote
# nothing, because WP-CLI does not detect Apache's mod_rewrite. The same clone's vhost also
# answered plain HTTP only, so a check built on https was invalid.
#
# Usage:
#   clone-preflight.sh --url <audited-base-url> [--wp "<wp command>"] [--root <site-root>]
#                      [--write-htaccess]
#
#   --url              the host the audit will measure (scheme optional; both are probed)
#   --wp               WP-CLI invocation, e.g. "wp --path=/srv/http/site" (default: wp)
#   --root             site root holding .htaccess (default: the root of `--wp`'s ABSPATH)
#   --write-htaccess   only after the user said yes: back up any existing .htaccess, write the
#                      stock WordPress rewrite block, mark it local-only, and check again
#
# Prints key=value lines on stdout (scheme, base, permalinks, probe_<n>, htaccess, server,
# diagnosis, local_only). Writes nothing without --write-htaccess.
# Exit: 0 every probed internal URL answered 200, 4 at least one did not (or the host did not
# answer), 1 bad usage or cannot resolve the site.
set -uo pipefail

url="" wp="wp" root="" write=0
while [ $# -gt 0 ]; do
  case "$1" in
    --url) url="${2:-}"; shift 2 ;;
    --wp) wp="${2:-}"; shift 2 ;;
    --root) root="${2:-}"; shift 2 ;;
    --write-htaccess) write=1; shift ;;
    *) echo "usage: clone-preflight.sh --url <url> [--wp \"<wp>\"] [--root <dir>] [--write-htaccess]" >&2; exit 1 ;;
  esac
done
[ -n "$url" ] || { echo "clone-preflight: --url is required" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "clone-preflight: curl is required" >&2; exit 1; }

hostpath="${url#*://}"; hostpath="${hostpath%/}"
host="${hostpath%%/*}"
subdir=""; case "$hostpath" in */*) subdir="/${hostpath#*/}" ;; esac
firstscheme="http"; case "$url" in https://*) firstscheme="https" ;; esac
other="https"; [ "$firstscheme" = "https" ] && other="http"

code() { curl -sk -o /dev/null -D "$2" -w '%{http_code}' --connect-timeout 5 -m 15 "$1" 2>/dev/null || true; }
hdrs=$(mktemp); trap 'rm -f "$hdrs"' EXIT

# 1. Which scheme does the host answer? Prefer a direct 200, then any answer (a redirect).
scheme="none"; homecode="000"
for s in "$firstscheme" "$other"; do
  c=$(code "$s://$host$subdir/" "$hdrs"); c=${c:-000}
  if [ "$c" = "200" ]; then scheme="$s"; homecode="$c"; break; fi
  if [ "$scheme" = "none" ] && [ "$c" != "000" ]; then scheme="$s"; homecode="$c"; fi
done
echo "scheme=$scheme"
echo "home=$homecode"
if [ "$scheme" = "none" ]; then
  echo "diagnosis=host-unreachable"
  exit 4
fi
base="$scheme://$host$subdir"
echo "base=$base"
code "$base/" "$hdrs" >/dev/null
server=$(tr -d '\r' < "$hdrs" | awk -F': ' 'tolower($1)=="server"{print $2; exit}')
echo "server=${server:-unknown}"

# 2. Permalinks and three internal URLs, taken from WP-CLI and requested on the audited host.
# shellcheck disable=SC2086
structure=$($wp option get permalink_structure 2>/dev/null | tail -1)
if [ -z "$structure" ]; then echo "permalinks=plain"; else echo "permalinks=pretty"; fi
if [ -z "$root" ]; then
  # shellcheck disable=SC2086
  root=$($wp eval 'echo ABSPATH;' 2>/dev/null | tail -1)
fi

urlline() { grep -E '^https?://' | tail -1; }
# shellcheck disable=SC2086
post=$($wp post list --post_type=post --post_status=publish --posts_per_page=1 --field=url 2>/dev/null | urlline)
# shellcheck disable=SC2086
page=$($wp post list --post_type=page --post_status=publish --posts_per_page=1 --field=url 2>/dev/null | urlline)
# shellcheck disable=SC2086
tid=$($wp term list category --hide_empty --number=1 --field=term_id 2>/dev/null | grep -E '^[0-9]+$' | head -1)
[ -n "$tid" ] || tid=$($wp term list category --number=1 --field=term_id 2>/dev/null | grep -E '^[0-9]+$' | head -1)
cat=""
# shellcheck disable=SC2086
[ -n "$tid" ] && cat=$($wp eval "echo get_term_link((int) $tid);" 2>/dev/null | urlline)

# Re-root a WP-CLI URL onto the audited host: keep path and query, swap scheme and host.
reroot() {
  local p="${1#*://}"; p="${p#*/}"
  [ -n "$subdir" ] && p="${p#"${subdir#/}"/}"
  echo "$base/$p"
}

probe() {
  local fails=0 n=0 kind u c
  for kind in post page category; do
    case "$kind" in post) u="$post" ;; page) u="$page" ;; category) u="$cat" ;; esac
    if [ -z "$u" ]; then echo "probe_$kind=none"; continue; fi
    u=$(reroot "$u"); c=$(code "$u" "$hdrs"); c=${c:-000}
    echo "probe_$kind=$c $u"
    n=$((n + 1))
    [ "$c" = "200" ] || fails=$((fails + 1))
  done
  [ "$n" -gt 0 ] || fails=1
  return "$fails"
}

htstate() {
  local f="$root/.htaccess"
  if [ ! -e "$f" ]; then echo missing
  elif [ ! -s "$f" ] || ! grep -q '[^[:space:]]' "$f"; then echo empty
  elif ! grep -Eq 'BEGIN WordPress|RewriteRule[[:space:]]+\.[[:space:]]+/?[^[:space:]]*index\.php' "$f"; then echo no-wp-block
  else echo ok; fi
}

wp_block() {
  local rb="${subdir:-/}"
  cat <<BLOCK
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase $rb
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . ${rb%/}/index.php [L]
</IfModule>
# END WordPress
BLOCK
}

if [ "$write" = 1 ]; then
  [ -d "$root" ] || { echo "clone-preflight: site root not found: $root" >&2; exit 1; }
  st=$(htstate)
  f="$root/.htaccess"
  case "$st" in
    ok) echo "wrote=nothing (a WordPress block is already there)" ;;
    *)
      if [ -e "$f" ]; then
        bak="$f.bak-$(date +%Y%m%d%H%M%S)"
        cp -p "$f" "$bak" && echo "backup=$bak"
        [ -s "$f" ] && { printf '\n' >> "$f"; }
      fi
      wp_block >> "$f" || { echo "clone-preflight: cannot write $f" >&2; exit 1; }
      echo "wrote=$f"
      ;;
  esac
  # Local only: an nginx production never reads this file, so it must not reach a deploy.
  if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git -C "$root" ls-files --error-unmatch .htaccess >/dev/null 2>&1; then
      echo "local_only=tracked (git already tracks .htaccess; do not commit this change)"
    elif git -C "$root" check-ignore -q .htaccess; then
      echo "local_only=ignored"
    else
      ex=$(git -C "$root" rev-parse --git-path info/exclude)
      case "$ex" in /*) ;; *) ex="$root/$ex" ;; esac
      mkdir -p "$(dirname "$ex")" && printf '/.htaccess\n' >> "$ex" \
        && echo "local_only=excluded in $ex (not .gitignore, not committed)"
    fi
  else
    echo "local_only=not-a-git-tree"
  fi
fi

if probe; then
  echo "diagnosis=ok"
  exit 0
fi

ht=$(htstate)
echo "htaccess=$ht"
if [ "$structure" = "" ]; then
  echo "diagnosis=plain-permalinks (internal URLs use ?p=, rewrite rules are not the cause)"
elif [ "$ht" != ok ]; then
  case "$server" in
    *[Nn]ginx*) echo "diagnosis=nginx-rules (nginx ignores .htaccess; its server block needs try_files)" ;;
    *) echo "diagnosis=htaccess-$ht (home answers, internal URLs do not; 'wp rewrite flush --hard' may write nothing under WP-CLI, which cannot detect mod_rewrite)" ;;
  esac
else
  echo "diagnosis=rewrite-not-applied (.htaccess has the block; check mod_rewrite and AllowOverride All in the vhost)"
fi
exit 4
