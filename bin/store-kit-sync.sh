#!/usr/bin/env bash
# Copy a bundled store plugin (store-kit by default, or store-polylang) into a site's plugins
# directory when the site has none, or an older one. Never downgrades: a newer copy on the site
# came from a newer claude-wp-builder, and replacing it would take away behaviour the site
# already relies on.
#
# Usage: store-kit-sync.sh <plugins-dir> [store-kit|store-polylang]
# Exit:  0 installed, updated or already current (one line says which); 1 refused.
set -euo pipefail
name=${2:-store-kit}
case $name in
  store-kit|store-polylang) ;;
  *) echo "store-kit-sync: unknown plugin '$name' (store-kit or store-polylang)" >&2; exit 1 ;;
esac
src=$(cd "$(dirname "$0")/../plugins/$name" 2>/dev/null && pwd) \
  || { echo "store-kit-sync: no bundled plugins/$name next to this script" >&2; exit 1; }
root=${1:-}
[ -n "$root" ] && [ -d "$root" ] || { echo "store-kit-sync: usage: store-kit-sync.sh <plugins-dir> [store-kit|store-polylang] (got '${root}')" >&2; exit 1; }
dest="$root/$name"

version() { sed -n 's/^ \* Version: *\([0-9][0-9.]*\).*$/\1/p' "$1" 2>/dev/null | sed -n 1p || true; }
want=$(version "$src/$name.php")
[ -n "$want" ] || { echo "store-kit-sync: the bundled $name.php has no Version header" >&2; exit 1; }
have=$(version "$dest/$name.php")
if [ -n "$have" ] && [ "$(printf '%s\n%s\n' "$have" "$want" | sort -V | tail -1)" = "$have" ]; then
  if [ "$have" = "$want" ]; then echo "$name $have is current"; else echo "$name $have is newer than the bundled $want: left alone"; fi
  exit 0
fi
# Copy beside, then swap: a half-copied plugin directory is a fatal on the next page load.
# mktemp names the scratch directories unpredictably and creates them atomically; the trap
# removes whatever is left of them on any exit, interrupted or failed.
tmp=$(mktemp -d "$root/.$name.new.XXXXXX")
old=$(mktemp -d "$root/.$name.old.XXXXXX")
trap 'rm -rf "$tmp" "$old"' EXIT
# mktemp creates 0700; the web server reads the plugin as another user.
chmod 755 "$tmp"
# transfer-verified: the copy is compared with its source before it replaces the live plugin.
cp -R "$src/." "$tmp"
diff -r "$src" "$tmp" >/dev/null || { echo "store-kit-sync: the copy in $tmp does not match $src; the site's plugin was not touched" >&2; exit 1; }
# The old copy is renamed aside rather than deleted first, which keeps the gap short but does
# not remove it: between moving $dest aside and moving the new copy in, the plugin is absent
# for two renames, and a request in that window runs without the credential strip.
[ -e "$dest" ] && mv "$dest" "$old/$name"
if ! mv "$tmp" "$dest"; then [ -e "$old/$name" ] && mv "$old/$name" "$dest"; exit 1; fi
echo "$name ${have:-absent} -> $want"
