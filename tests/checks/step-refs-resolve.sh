#!/usr/bin/env bash
# Every "Step N.M" a command cites must exist as a heading ("## Step N.M" or "### N.M") in
# the command it points at. A numbered list item is not a heading: a model told to "see
# Step 5.3" looks for one and finds nothing. Cite list items as "Step 5, item 3".
#
# A citation names its command when `/wp-x` comes right before it (`/wp-x` Step 2.6,
# `/wp-x`'s Step 2.6, `commands/wp-x.md` Steps 4 and 4.4) or right after it (Step 2.6 of `/wp-x`); the check then resolves it
# against that command, expanded with its own -run references. Any other citation is the
# citing command's own. The plural form ("Steps 2, 2.5, 2.6") is checked item by item.
set -euo pipefail
cd "$(dirname "$0")/../.."
# shellcheck source=lib/expand-command.sh
. tests/checks/lib/expand-command.sh

expand_to() { # name -> sets EXPANDED
  local c=commands/$1.md
  if grep >/dev/null -c "skills/$1-run/references/" "$c"; then expand_command "$c"; else EXPANDED=$c; fi
}

fail=0
for cmd in commands/*.md; do
  self=$(basename "$cmd" .md)
  expand_to "$self"; src=$EXPANDED
  cites=$(awk -v self="$self" '
    { text = text " " $0 }
    END {
      while (match(text, /Steps? [0-9]+(\.[0-9]+)?(, (and )?[0-9]+(\.[0-9]+)?| and [0-9]+(\.[0-9]+)?)*/)) {
        span = substr(text, RSTART, RLENGTH)
        before = substr(text, (RSTART > 60 ? RSTART - 60 : 1), (RSTART > 60 ? 60 : RSTART - 1))
        after = substr(text, RSTART + RLENGTH, 60)
        text = substr(text, RSTART + RLENGTH)
        target = self
        if (match(before, /(^|[^A-Za-z0-9\/-])\/wp-[a-z0-9-]+`?(.s)? *$/)) {
          t = substr(before, RSTART, RLENGTH); sub(/^[^\/]*\//, "", t); sub(/[`. ].*$/, "", t); target = t
          sub(/\x27s$/, "", target)
        } else if (match(before, /commands\/wp-[a-z0-9-]+\.md`? *$/)) {
          t = substr(before, RSTART, RLENGTH); sub(/^commands\//, "", t); sub(/\.md.*$/, "", t); target = t
        } else if (match(after, /^ of `?\/wp-[a-z0-9-]+/)) {
          t = substr(after, RSTART, RLENGTH); sub(/^[^\/]*\//, "", t); target = t
        }
        n = split(span, parts, /[^0-9.]+/)
        for (i = 1; i <= n; i++) if (parts[i] ~ /^[0-9]+\.[0-9]+$/) print target, parts[i]
      }
    }' "$src" | sort -u)
  while read -r target n; do
    [ -n "${target:-}" ] || continue
    if [ ! -f "commands/$target.md" ]; then
      echo "FAIL: $cmd cites Step $n of /$target, which is not a command" >&2; fail=1; continue
    fi
    expand_to "$target"
    if ! grep >/dev/null -cE "^#+ (.*Step )?${n//./\\.}([^0-9]|\$)" "$EXPANDED"; then
      echo "FAIL: $cmd cites /$target Step $n but that command has no heading for it" >&2; fail=1
    fi
  done <<<"$cites"
done
[ "$fail" -eq 0 ] || exit 1
echo PASS
