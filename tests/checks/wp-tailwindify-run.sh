#!/usr/bin/env bash
# commands/wp-tailwindify.md was 15.4 KB, so every /wp-tailwindify run read the agent dispatch
# context and the verification detail up front. Those two steps moved to
# skills/wp-tailwindify-run/references/, read at the step that needs them. A reference nothing
# points to is a step the run silently never performs, so every file there must be named in
# the command under its own heading and in the skill's table, and the command must stay a map
# rather than grow back.
#
# Ceiling: the command is 5.8 KB with Steps 3 and 4 moved out, so 7 KB leaves room for a few
# added lines but fails if a step's detail is pasted back in.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail=0
err() { echo "FAIL: $*"; fail=1; }

cmd=commands/wp-tailwindify.md
skill=skills/wp-tailwindify-run/SKILL.md
refs=skills/wp-tailwindify-run/references

[ -r "$skill" ] || { echo "FAIL: $skill is missing"; exit 1; }

for f in "$refs"/*.md; do
  b=$(basename "$f")
  grep -Fq "\${CLAUDE_PLUGIN_ROOT}/skills/wp-tailwindify-run/references/$b\` now and" "$cmd" \
    || err "$cmd never sends the run to $b"
  grep -Fq "(references/$b)" "$skill" || err "$skill does not list $b"
  # The reference names its step, and that step heading still exists in the command.
  step=$(sed -n '1s/^# \/wp-tailwindify — //p' "$f")
  [ -n "$step" ] || { err "$f has no '# /wp-tailwindify — Step N' title"; continue; }
  grep -Eq -- "^## ${step}( |:)" "$cmd" || err "$f belongs to $step, which $cmd no longer has"
  # The pointer sits under that step, not elsewhere in the command.
  awk -v s="^## ${step}( |:)" -v b="references/$b" '
    $0 ~ s { on = 1; next } /^## (Step|Path) / { on = 0 } on && index($0, b) { found = 1 }
    END { exit !found }' "$cmd" || err "$cmd points to $b outside $step"
done

# Every pointer in the command resolves to a file.
for p in $(grep -oE 'skills/wp-tailwindify-run/references/[a-z0-9-]+\.md' "$cmd" | sort -u); do
  [ -r "$p" ] || err "$cmd points to $p, which does not exist"
done

# Two pointers in one paragraph would leave the expansion one body short: expand-command.sh
# splices a single reference in at the blank line that closes the paragraph naming it.
awk '/^$/ { n = 0; next } /skills\/wp-tailwindify-run\/references\// { if (++n > 1) bad = 1 }
  END { exit bad }' "$cmd" || err "$cmd names two wp-tailwindify-run references in one paragraph"

# The command stays a map. Steps 1, 2 and 5 stay whole: the argument parse and output path,
# the already-Tailwind check and the report the run needs in view.
size=$(wc -c < "$cmd")
[ "$size" -le 7168 ] || err "$cmd is $size bytes; move long step detail to $refs"

# The expansion the checks read must carry every reference body.
. tests/checks/lib/expand-command.sh
expand_command "$cmd"
for f in "$refs"/*.md; do
  # A closing code fence matches any other fence, so take the last line that is not one.
  last=$(grep -v -e '^$' -e '^```' "$f" | tail -1) || true
  [ -n "$last" ] || { err "$(basename "$f") has no body"; continue; }
  grep -Fqx -- "$last" "$EXPANDED" || err "expand-command.sh dropped the body of $(basename "$f")"
done

[ "$fail" = 0 ] && echo PASS || exit 1
