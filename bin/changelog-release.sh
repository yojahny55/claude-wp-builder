#!/usr/bin/env bash
# Compile changes/*.md fragments into a new release block in CHANGELOG.md.
#
# Usage: bin/changelog-release.sh <X.Y.Z> [YYYY-MM-DD]
#
# The new `## [X.Y.Z] - date` heading is inserted BELOW `## [Unreleased]`, which is left in
# place and empty. Entries already sitting under [Unreleased] (from before fragments existed)
# are carried into the release block, ahead of the fragments of the same section. Fragments
# are deleted once compiled. Nothing is written if the inputs are invalid.
set -euo pipefail
cd "$(dirname "$0")/.."

ver="${1:?usage: changelog-release.sh <X.Y.Z> [YYYY-MM-DD]}"
date="${2:-$(date +%F)}"
[[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must be X.Y.Z, got: $ver" >&2; exit 1; }
[[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "date must be YYYY-MM-DD, got: $date" >&2; exit 1; }

cl=CHANGELOG.md
grep -qx '## \[Unreleased\]' "$cl" || { echo "$cl has no '## [Unreleased]' heading" >&2; exit 1; }
grep -qF "## [$ver]" "$cl" && { echo "$cl already has a $ver block" >&2; exit 1; }

order="added changed deprecated removed fixed security"
shopt -s nullglob
frags=()
for f in changes/*.md; do
  [ "$(basename "$f")" = README.md ] && continue
  frags+=("$f")
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Entries already under [Unreleased], split per "### Section" into $tmp/old.<section>.
awk -v dir="$tmp" '
  /^## \[Unreleased\]/ { on = 1; next }
  /^## \[/ { on = 0 }
  on && /^### / { s = tolower(substr($0, 5)); out = dir "/old." s; next }
  on && out { print > out; next }
  on && NF { print > (dir "/stray") }
' "$cl"

for f in ${frags[@]+"${frags[@]}"}; do
  base=$(basename "$f" .md)
  sec=${base##*.}
  [[ " $order " == *" $sec "* && "$base" == *.* ]] \
    || { echo "$f: name must be <slug>.<section>.md with section in: $order" >&2; exit 1; }
  head -n1 "$f" | grep -q '^- ' || { echo "$f: must start with '- '" >&2; exit 1; }
done
[ ! -s "$tmp/stray" ] || { echo "[Unreleased] has text outside any ### section; move it under one first:" >&2; cat "$tmp/stray" >&2; exit 1; }
for o in "$tmp"/old.*; do
  [ -e "$o" ] || continue
  s=${o##*/old.}
  [[ " $order " == *" $s "* ]] || { echo "[Unreleased] has a '### $s' section this script does not know" >&2; exit 1; }
done

block="$tmp/block"
{
  echo "## [$ver] - $date"
  for sec in $order; do
    body=""
    [ -f "$tmp/old.$sec" ] && body=$(awk 'NF { p = 1 } p' "$tmp/old.$sec" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')
    for f in ${frags[@]+"${frags[@]}"}; do
      [ "$(basename "$f" .md | sed 's/.*\.//')" = "$sec" ] || continue
      [ -n "$body" ] && body+=$'\n\n'
      body+=$(cat "$f")
    done
    [ -n "$body" ] || continue
    printf '\n### %s\n\n%s\n' "$(tr '[:lower:]' '[:upper:]' <<<"${sec:0:1}")${sec:1}" "$body"
  done
  echo
} > "$block"

awk -v blk="$block" '
  /^## \[Unreleased\]/ { print; print ""; while ((getline l < blk) > 0) print l; skip = 1; next }
  skip && /^## \[/ { skip = 0 }
  !skip { print }
' "$cl" > "$tmp/new"

mv "$tmp/new" "$cl"
if [ "${#frags[@]}" -gt 0 ]; then
  git rm -q -f -- "${frags[@]}" 2>/dev/null || rm -f -- "${frags[@]}"
fi
echo "changelog-release: $ver written, ${#frags[@]} fragment(s) compiled"
