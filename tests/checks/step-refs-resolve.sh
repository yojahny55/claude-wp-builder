#!/usr/bin/env bash
# Every "Step N.M" a command cites must exist as a heading in that same (expanded) command.
# A numbered list item is not a heading: a model told to "see Step 5.3" looks for one and
# finds nothing. Cite list items as "Step 5, item 3".
# A citation that names another command (`/wp-yolo` Step 2.6, on the same or the previous
# line) resolves in that command, not this one, and is skipped.
set -euo pipefail
cd "$(dirname "$0")/../.."
# shellcheck source=lib/expand-command.sh
. tests/checks/lib/expand-command.sh
fail=0
for cmd in commands/*.md; do
  self=$(basename "$cmd" .md)
  if grep >/dev/null -c "skills/${self}-run/references/" "$cmd"; then expand_command "$cmd"; else EXPANDED=$cmd; fi
  refs=$(awk -v self="/$self" '
    { line = $0; ctx = prev " " line; prev = line
      tmp = ctx; other = 0
      while (match(tmp, /\/wp-[a-z0-9-]+/)) {
        name = substr(tmp, RSTART, RLENGTH); tmp = substr(tmp, RSTART + RLENGTH)
        if (name != self) other = 1
      }
      if (other) next
      tmp = line
      while (match(tmp, /Step [0-9]+\.[0-9]+/)) { print substr(tmp, RSTART + 5, RLENGTH - 5); tmp = substr(tmp, RSTART + RLENGTH) }
    }' "$EXPANDED" | sort -u)
  for n in $refs; do
    if ! grep >/dev/null -cE "^#+ (.*Step )?${n//./\\.}([^0-9]|\$)" "$EXPANDED"; then
      echo "FAIL: $cmd cites Step $n but has no heading for it" >&2
      fail=1
    fi
  done
done
[ "$fail" -eq 0 ] || exit 1
echo PASS
