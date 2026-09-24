#!/usr/bin/env bash
# Copy the bundled store-kit into a site's plugins directory when the site has none, or an
# older one. Never downgrades: a newer copy on the site came from a newer claude-wp-builder,
# and replacing it would take away behaviour the site already relies on.
#
# Usage: store-kit-sync.sh <plugins-dir>
# Exit:  0 installed, updated or already current (one line says which); 1 refused.
set -euo pipefail
src=$(cd "$(dirname "$0")/../plugins/store-kit" 2>/dev/null && pwd) \
  || { echo "store-kit-sync: no bundled plugins/store-kit next to this script" >&2; exit 1; }
root=${1:-}
[ -n "$root" ] && [ -d "$root" ] || { echo "store-kit-sync: usage: store-kit-sync.sh <plugins-dir> (got '${root}')" >&2; exit 1; }
dest="$root/store-kit"
version() { sed -n 's/^ \* Version: *\([0-9][0-9.]*\).*$/\1/p' "$1" 2>/dev/null | head -1 || true; }
want=$(version "$src/store-kit.php")
[ -n "$want" ] || { echo "store-kit-sync: the bundled store-kit.php has no Version header" >&2; exit 1; }
have=$(version "$dest/store-kit.php")
if [ -n "$have" ] && [ "$(printf '%s\n%s\n' "$have" "$want" | sort -V | tail -1)" = "$have" ]; then
  if [ "$have" = "$want" ]; then echo "store-kit $have is current"; else echo "store-kit $have is newer than the bundled $want: left alone"; fi
  exit 0
fi
# Copy beside, then swap: a half-copied plugin directory is a fatal on the next page load.
tmp="$root/.store-kit.new.$$"
rm -rf "$tmp"
cp -R "$src" "$tmp"
rm -rf "$dest"
mv "$tmp" "$dest"
echo "store-kit ${have:-absent} -> $want"
