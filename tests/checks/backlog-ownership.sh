#!/usr/bin/env bash
# backlog-freshness.sh checks that a reconciliation HAPPENED. It cannot check that the
# reconciliation was any good, and the gap it leaves is a specific one: an entry that
# describes a wanted behavior and never says which file would have to change. A reader
# cannot tell whether that means "the owner exists and is incomplete" or "nothing in this
# repo does this yet", and those lead to different work.
#
# So every OPEN, PARTIAL or BLOCKED entry must do one of two things: link the
# implementation it belongs to, or say in words that no owner exists yet. Both are cheap to
# write while reconciling and impossible to reconstruct later.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1
B="BACKLOG.md"
fails=0
fail() { printf 'FAIL: %s\n' "$1"; fails=$((fails + 1)); }

[ -f "$B" ] || { printf 'FAIL: %s is missing\n' "$B"; exit 1; }

# An entry runs from its `- [ ] **Title** `STATUS`` line to the next entry or heading.
# The phrases below are the ways an entry can say "no owner exists"; they are matched
# literally so that adding a new spelling is a deliberate edit to this list.
python3 - "$B" <<'PY'
import re, sys

path = sys.argv[1]
lines = open(path, encoding='utf-8').read().split('\n')

NO_OWNER = (
    'does not exist',
    'does not yet exist',
    'no owner',
    'nothing owns',
    'nothing in the repo',
    'no command owns',
    'not started',
    'would be a new',
    'New `/wp-',
    'a new command',
    'Explore ',
)

entry_re = re.compile(r'^\s*- \[[ x]\] \*\*(.+?)\*\* `(OPEN|PARTIAL|BLOCKED)`')
start_re = re.compile(r'^\s*- \[[ x]\]|^#{1,6} ')

bad = []
i = 0
while i < len(lines):
    m = entry_re.match(lines[i])
    if not m:
        i += 1
        continue
    title, status = m.group(1), m.group(2)
    j = i + 1
    while j < len(lines) and not start_re.match(lines[j]):
        j += 1
    body = '\n'.join(lines[i:j])
    # A markdown link to a repo path is the "owner exists" signal.
    has_link = re.search(r'\]\((?!https?:|#)[^)]+\)', body) is not None
    says_none = any(p.lower() in body.lower() for p in NO_OWNER)
    if not has_link and not says_none:
        bad.append((i + 1, status, title))
    i = j

for line, status, title in bad:
    print(f'  {path}:{line} [{status}] {title}')
sys.exit(1 if bad else 0)
PY
if [ $? -ne 0 ]; then
  fail "the entries above link no implementation and do not say that no owner exists yet -- a reader cannot tell an incomplete owner from an absent one"
fi

if [ "$fails" -gt 0 ]; then
  printf 'FAILED %d\n' "$fails"
  exit 1
fi
printf 'PASS: every open, partial and blocked backlog entry names an owner or says there is none\n'
