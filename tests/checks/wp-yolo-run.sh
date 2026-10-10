#!/usr/bin/env bash
# commands/wp-yolo.md grew to 76 KB, so every /wp-yolo run read the build ledger, the
# parity gate and the Tailwind conversion before it had normalized anything. Its long
# steps moved to skills/wp-yolo-run/references/, read at the step that needs them. A
# reference nothing points to is a step the run silently never performs, so every file
# there must be named in the command under its own step heading and in the skill's table,
# and the command must stay a map rather than grow back.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail=0
err() { echo "FAIL: $*"; fail=1; }

cmd=commands/wp-yolo.md
skill=skills/wp-yolo-run/SKILL.md
refs=skills/wp-yolo-run/references

[ -r "$skill" ] || { echo "FAIL: $skill is missing"; exit 1; }

for f in "$refs"/*.md; do
  b=$(basename "$f")
  grep -Fq "\${CLAUDE_PLUGIN_ROOT}/skills/wp-yolo-run/references/$b\` now and follow it" "$cmd" \
    || err "$cmd never sends the run to $b"
  grep -Fq "(references/$b)" "$skill" || err "$skill does not list $b"
  # The reference names its step, and that step heading still exists in the command.
  step=$(sed -n '1s/^# \/wp-yolo — //p' "$f")
  [ -n "$step" ] || { err "$f has no '# /wp-yolo — Step N' title"; continue; }
  grep -Fq -- "## ${step}:" "$cmd" || err "$f belongs to $step, which $cmd no longer has"
  # The pointer sits under that step, not elsewhere in the command.
  awk -v s="## ${step}:" -v b="references/$b" '
    index($0, s) == 1 { on = 1; next } /^## Step / { on = 0 } on && index($0, b) { found = 1 }
    END { exit !found }' "$cmd" || err "$cmd points to $b outside $step"
done

# Every pointer in the command resolves to a file.
for p in $(grep -oE 'skills/wp-yolo-run/references/[a-z0-9-]+\.md' "$cmd" | sort -u); do
  [ -r "$p" ] || err "$cmd points to $p, which does not exist"
done

# The command stays a map. Steps 1, 4 and 5 stay whole, because they are the gates and the
# dispatch order the run needs in view from the start, so the ceiling is 35 KB rather than
# /wp-audit's 30. A step that needs more than that belongs in a reference.
size=$(wc -c < "$cmd")
[ "$size" -le 35840 ] || err "$cmd is $size bytes; move long step detail to $refs"

# The expansion the audit checks read must carry every reference body.
. tests/checks/lib/expand-command.sh
expand_command "$cmd"
for f in "$refs"/*.md; do
  # A closing code fence matches any other fence, so take the last line that is not one.
  last=$(grep -v -e '^$' -e '^```' "$f" | tail -1) || true
  [ -n "$last" ] || { err "$(basename "$f") has no body"; continue; }
  grep -Fqx -- "$last" "$EXPANDED" || err "expand-command.sh dropped the body of $(basename "$f")"
done

[ "$fail" = 0 ] && echo PASS || exit 1
