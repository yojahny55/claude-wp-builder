#!/usr/bin/env bash
# Three leaks in the same family. /wp-update piped option values through
# `grep -E '(sk|rk|pk)_live_'`, which prints the whole matching line: a live payment key
# in the transcript, in a plugin that says everywhere else that secrets never go to the
# chat. /wp-clone listed `*_live_*` options with their values. bin/domains-import.sh cloned
# a third-party repository's `main` unpinned, and the CSV it builds is read by agents.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

# A grep for live keys must count (-c) or be quiet (-q), never print the match.
for f in commands/*.md skills/*/SKILL.md agents/*.md; do
  while IFS= read -r line; do
    case "$line" in
      *grep*_live_*) echo "$line" | grep -Eq 'grep -[a-zA-Z]*[cq]' \
        || fail "$f prints a live-key match: $line" ;;
    esac
  done < <(grep -F '_live_' "$f" | grep -F 'grep' || true)
done
grep -Fq "grep -cE '(sk|rk|pk)_live_'" commands/wp-update.md || fail "wp-update.md lost the counting live-key check"
grep -Fq -- '--fields=option_name' commands/wp-clone.md || fail "wp-clone.md lists *_live_* options with their values"

# The domains import is pinned and says to read the diff.
s=bin/domains-import.sh
grep -Fq 'DOMAINS_REF' "$s" || fail "$s has no DOMAINS_REF pin"
! grep -Eq 'git clone[^#]*--depth 1 https' "$s" || fail "$s clones the default branch again"
grep -Eq 'DOMAINS_REF:-[0-9a-f]{40}' "$s" || fail "$s default ref is not a full commit SHA"
grep -Fq 'READ THE DIFF' "$s" || fail "$s no longer tells the maintainer to read the CSV diff"

echo PASS
