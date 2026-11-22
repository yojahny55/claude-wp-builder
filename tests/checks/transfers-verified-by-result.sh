#!/usr/bin/env bash
# A bulk copy, sync, archive or extraction that exits 0 is a tool saying it finished, not
# evidence that the files moved. It was measured three times in one project: a mirror writing
# 7 of 38 objects and exiting 0, the same mirror "succeeding" against a stopped backend, and an
# interactive `cp -i` alias skipping copies in silence.
#
# So every bulk transfer in a script this plugin ships must confirm its result (a count, a
# hash, a diff, the file that has to be there) and say so with a `transfer-verified:` comment
# in the few lines above the command. Above only: a window that also looked below would let one
# marker cover the next, unmarked transfer. This check finds the transfers and fails on any without
# that marker, so a new script cannot add one silently. The rule itself is written down in
# skills/wp-contributing/SKILL.md.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

need_token skills/wp-contributing/SKILL.md 'transfer-verified:' \
  "wp-contributing no longer writes down the verify-by-result rule for bulk transfers"
need_token skills/wp-contributing/SKILL.md 'not evidence'

# A transfer: tar creating or extracting (dashed, undashed, long form, options in front), rsync,
# rclone, an mcli/mc/aws mirror or sync, or a recursive cp (short or long, alias-bypassed).
# Comments and echo/printf lines (messages naming a tool) are skipped. Test fixtures are not
# shipped and are not scanned.
pattern='(^|[;&|(]|[[:space:]])\\?(tar ([^|;&]* )?-[a-zA-Z]*[cx]|tar [cx][a-zA-Z]* |tar ([^|;&]* )?--(create|extract|get)|rsync |rclone |"?\$MCLI"? mirror|mcli mirror|mc mirror|aws s3 (sync|cp)|cp (-[a-zA-Z]*[rRa][a-zA-Z]*|--recursive|--archive) )'
window=6
found=0 missing=""
for f in bin/*.sh skills/*/scripts/*.sh; do
  [ -f "$f" ] || continue
  while IFS=: read -r n _; do
    found=$((found + 1))
    from=$(( n > window ? n - window : 1 )); to=$n
    if ! sed -n "${from},${to}p" "$f" | grep >/dev/null -c 'transfer-verified:'; then
      missing="$missing
  $f:$n: $(sed -n "${n}p" "$f" | sed 's/^[[:space:]]*//')"
    fi
  done < <(grep -nE "$pattern" "$f" | grep -vE '^[0-9]+:[[:space:]]*(#|echo |printf )' || true)
done

[ "$found" -gt 0 ] || fail "no bulk transfer found in any shipped script: the pattern no longer matches anything"
[ -z "$missing" ] || fail "bulk transfers with no transfer-verified: comment in the $window lines above (verify the result by count, hash or diff, then say how):$missing"

# Self-test: the pattern must catch each spelling of a transfer, and leave a plain copy alone.
for line in 'rsync -a src/ dst/' 'cp -R a b' '\cp -r a b' 'cp --recursive a b' 'tar -C d -xzf x.tgz' \
            'tar czf x.tgz d' 'tar --extract -f x.tar' '  tar -xzpf "$a" -C "$b" || exit 1' 'rclone sync a b'; do
  printf '%s\n' "$line" | grep -E "$pattern" >/dev/null || fail "the pattern misses a transfer: $line"
done
for line in 'cp a b' 'cp -p a b' 'echo tarball' 'gzip -t x.tgz' 'tar -tvzf x.tgz'; do
  if printf '%s\n' "$line" | grep -E "$pattern" >/dev/null; then fail "the pattern takes a non-transfer for one: $line"; fi
done

echo "PASS: $found bulk transfers in shipped scripts, each verified by result"
