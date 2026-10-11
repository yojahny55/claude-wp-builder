#!/usr/bin/env bash
# commands/wp-demo.md grew to 56 KB, so every /wp-demo run read the craft brief, the
# composition plan and the craft build before it had chosen a mode, and a plain build paid
# for all three without using them. Those steps moved to skills/wp-demo-run/references/,
# read at the step that needs them. A reference nothing points to is a step the run
# silently never performs, so every file there must be named in the command under its own
# step heading and in the skill's table, and the command must stay a map rather than grow
# back.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail=0
err() { echo "FAIL: $*"; fail=1; }

cmd=commands/wp-demo.md
skill=skills/wp-demo-run/SKILL.md
refs=skills/wp-demo-run/references

[ -r "$skill" ] || { echo "FAIL: $skill is missing"; exit 1; }

# An empty references/ would otherwise run the loop once on the literal glob.
shopt -s nullglob
set -- "$refs"/*.md
[ $# -gt 0 ] || { echo "FAIL: $refs has no references"; exit 1; }

for f in "$refs"/*.md; do
  b=$(basename "$f")
  grep -Fq "\${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-run/references/$b\` now and" "$cmd" \
    || err "$cmd never sends the run to $b"
  grep -Fq "(references/$b)" "$skill" || err "$skill does not list $b"
  # The reference names its step, and that step heading still exists in the command.
  step=$(sed -n '1s/^# \/wp-demo — //p' "$f")
  [ -n "$step" ] || { err "$f has no '# /wp-demo — Step N' title"; continue; }
  grep -Eq -- "^## ${step}( |:)" "$cmd" || err "$f belongs to $step, which $cmd no longer has"
  # The pointer sits under that step, not elsewhere in the command.
  awk -v s="^## ${step}( |:)" -v b="references/$b" '
    $0 ~ s { on = 1; next } /^## / { on = 0 } on && index($0, b) { found = 1 }
    END { exit !found }' "$cmd" || err "$cmd points to $b outside $step"
done

# Every pointer in the command resolves to a file.
for p in $(grep -oE 'skills/wp-demo-run/references/[a-z0-9-]+\.md' "$cmd" | sort -u); do
  [ -r "$p" ] || err "$cmd points to $p, which does not exist"
done

# Two pointers in one paragraph would leave the expansion one body short: expand-command.sh
# splices a single reference in at the blank line that closes the paragraph naming it.
awk '/^$/ { n = 0; next } /skills\/wp-demo-run\/references\// { if (++n > 1) bad = 1 }
  END { exit bad }' "$cmd" || err "$cmd names two wp-demo-run references in one paragraph"

# The command stays a map. Steps 2.4, 2.5 and the rest of 2.6 stay whole, because they are
# the mode choice and the gates the run needs in view from the start.
size=$(wc -c < "$cmd")
[ "$size" -le 25600 ] || err "$cmd is $size bytes; move long step detail to $refs"

# The expansion the checks read must carry every reference body.
. tests/checks/lib/expand-command.sh
expand_command "$cmd"
for f in "$refs"/*.md; do
  # A closing code fence matches any other fence, so take the last line that is not one.
  last=$(grep -v -e '^$' -e '^```' "$f" | tail -1) || true
  [ -n "$last" ] || { err "$(basename "$f") has no body"; continue; }
  grep -Fqx -- "$last" "$EXPANDED" || err "expand-command.sh dropped the body of $(basename "$f")"
done

# Only the command's own -run references are spliced in. /wp-demo also names
# wp-demo-craft's references as reading, and their text is not the command's.
grep -Fq '## The seven dimensions' "$EXPANDED" \
  && err "expand-command.sh spliced in a reference from another skill (fingerprint.md)"

[ "$fail" = 0 ] && echo PASS || exit 1
