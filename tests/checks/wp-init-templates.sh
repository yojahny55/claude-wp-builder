#!/usr/bin/env bash
set -euo pipefail
# /wp-init must never offer a starter template whose directory is missing.
#
# This existed as a documented "Known gap" for months: __starter__ was removed
# in 3600552 as superseded by Tailwind, but wp-init kept offering "Basic
# Starter" as option 1 AND as the Enter-key default -- so the single most
# likely path through the command copied a directory that is not there.
# A grep-for-the-wording check would not have caught it; this compares the
# command against the filesystem.
cmd=commands/wp-init.md
test -f "$cmd" || { echo "FAIL: $cmd missing"; exit 1; }

# Every `cp -r .../starter-theme/<x>/` target must exist. Scoped to actual cp
# lines: prose may legitimately NAME a removed starter while explaining why it
# is gone, and failing on that would punish the documentation.
targets=$(grep -E '^\s*cp -r ' "$cmd" | grep -oP 'starter-theme/\K__[a-z]+__(?=/)' | sort -u)
[[ -n "$targets" ]] || { echo "FAIL: wp-init copies no starter theme at all -- this check would be vacuous"; exit 1; }

for t in $targets; do
  [[ -d "starter-theme/$t" ]] || {
    echo "FAIL: /wp-init copies starter-theme/$t/, which does not exist"
    echo "      present: $(ls -d starter-theme/__*__ 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
    exit 1
  }
done

# Whatever the Enter-key default is, it must resolve to a real directory too.
default=$(grep -oP '^Default: `\K[a-z]+' "$cmd" | head -1)
[[ -n "$default" ]] || { echo "FAIL: no template default declared in $cmd"; exit 1; }
case "$default" in
  tailwind)  d=starter-theme/__tailwind__ ;;
  cinematic) d=starter-theme/__cinematic__ ;;
  *)         echo "FAIL: template default '$default' maps to no known starter directory"; exit 1 ;;
esac
[[ -d "$d" ]] || { echo "FAIL: the default template '$default' points at $d, which does not exist"; exit 1; }

echo PASS
