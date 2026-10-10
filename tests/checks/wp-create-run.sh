#!/usr/bin/env bash
# commands/wp-create.md grew to 37 KB, so every /wp-create run read the environment template
# detail, the whole plugin-profile install and the manifest shape long before it reached
# them. Those steps moved to skills/wp-create-run/references/, read at the step that needs
# them. A reference nothing points to is a step the run silently never performs, so every
# file there must be named in the command under its own step heading and in the skill's
# table, and the command must stay a map rather than grow back.
#
# Unlike /wp-init, this command's steps are `### Step 4.N:` subheadings as well as
# `## Step N:` ones, so the heading anchor below accepts either level, and a step's section
# ends at the next heading of either level.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail=0
err() { echo "FAIL: $*"; fail=1; }

cmd=commands/wp-create.md
skill=skills/wp-create-run/SKILL.md
refs=skills/wp-create-run/references

[ -r "$skill" ] || { echo "FAIL: $skill is missing"; exit 1; }

for f in "$refs"/*.md; do
  b=$(basename "$f")
  grep -Fq "\${CLAUDE_PLUGIN_ROOT}/skills/wp-create-run/references/$b\` now and" "$cmd" \
    || err "$cmd never sends the run to $b"
  grep -Fq "(references/$b)" "$skill" || err "$skill does not list $b"
  # The reference names its step, and that step heading still exists in the command.
  step=$(sed -n '1s/^# \/wp-create — //p' "$f")
  [ -n "$step" ] || { err "$f has no '# /wp-create — Step N' title"; continue; }
  # Compared as literal text, not a regex: the dot in "Step 4.3" would match any character.
  awk -v s="$step" 'index($0, "## " s ":") == 1 || index($0, "### " s ":") == 1 { f = 1 }
    END { exit !f }' "$cmd" || err "$f belongs to $step, which $cmd no longer has"
  # The pointer sits under that step, not elsewhere in the command.
  awk -v s="${step}" -v b="references/$b" '
    # Only a level-2 or level-3 heading opens or closes a step; a deeper subheading stays inside it.
    /^###? / { on = (index($0, "## " s ":") == 1 || index($0, "### " s ":") == 1); next }
    on && index($0, b) { found = 1 }
    END { exit !found }' "$cmd" || err "$cmd points to $b outside $step"
done

# Every pointer in the command resolves to a file.
for p in $(grep -oE 'skills/wp-create-run/references/[a-z0-9-]+\.md' "$cmd" | sort -u); do
  [ -r "$p" ] || err "$cmd points to $p, which does not exist"
done

# Two pointers in one paragraph would leave the expansion one body short: expand-command.sh
# splices a single reference in at the blank line that closes the paragraph naming it.
awk '/^$/ { n = 0; next } /skills\/wp-create-run\/references\// { if (++n > 1) bad = 1 }
  END { exit bad }' "$cmd" || err "$cmd names two wp-create-run references in one paragraph"

# The command stays a map. Configuration collection (Step 3), Failure Handling, Adopt Mode
# and the short steps stay whole, because they are the choices and the gates the run needs in
# view from the start. The command is 26 KB; the ceiling sits 1 KB above that, enough for a
# sentence or two of wording and not enough to move a step's detail back in.
size=$(wc -c < "$cmd")
[ "$size" -le 27648 ] || err "$cmd is $size bytes; move long step detail to $refs"

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
