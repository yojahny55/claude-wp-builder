#!/usr/bin/env bash
# commands/wp-finalize.md was 36 KB, and every /wp-finalize run read all seven long checks
# and the three demo-parity layers up front, whichever the project needed. That detail moved to
# skills/wp-finalize-run/references/, read at the check that needs it. A reference nothing points
# to is a check the run silently never performs, so every file there must be named in the
# command under its own heading and in the skill's table, and the command must stay a map
# rather than grow back.
#
# Unlike /wp-finalize, this command has no long `## Step N:` sections: its detail sits in `###`
# checks under Step 3. So a reference is titled with the `###` heading it belongs to
# (`# /wp-finalize — Check 2: ...`), and the heading anchor below is `### <title>`, not `## Step N`.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail=0
err() { echo "FAIL: $*"; fail=1; }

cmd=commands/wp-finalize.md
skill=skills/wp-finalize-run/SKILL.md
refs=skills/wp-finalize-run/references

[ -r "$skill" ] || { echo "FAIL: $skill is missing"; exit 1; }

# An empty references/ would otherwise run the loop once on the literal glob.
shopt -s nullglob
set -- "$refs"/*.md
[ $# -gt 0 ] || { echo "FAIL: $refs has no references"; exit 1; }

for f in "$refs"/*.md; do
  b=$(basename "$f")
  grep -Fq "\${CLAUDE_PLUGIN_ROOT}/skills/wp-finalize-run/references/$b\` now and" "$cmd" \
    || err "$cmd never sends the run to $b"
  grep -Fq "(references/$b)" "$skill" || err "$skill does not list $b"
  # The reference names its step, and that step heading still exists in the command.
  step=$(sed -n '1s/^# \/wp-finalize — //p' "$f")
  [ -n "$step" ] || { err "$f has no '# /wp-finalize — <heading>' title"; continue; }
  grep -Fxq -- "### ${step}" "$cmd" || err "$f belongs to $step, which $cmd no longer has"
  # The pointer sits under that step, not elsewhere in the command.
  awk -v s="### ${step}" -v b="references/$b" '
    $0 == s { on = 1; next } /^##+ / { on = 0 } on && index($0, b) { found = 1 }
    END { exit !found }' "$cmd" || err "$cmd points to $b outside $step"
done

# Every pointer in the command resolves to a file.
for p in $(grep -oE 'skills/wp-finalize-run/references/[a-z0-9-]+\.md' "$cmd" | sort -u); do
  [ -r "$p" ] || err "$cmd points to $p, which does not exist"
done

# Two pointers in one paragraph would leave the expansion one body short: expand-command.sh
# splices a single reference in at the blank line that closes the paragraph naming it.
awk '/^$/ { n = 0; next } /skills\/wp-finalize-run\/references\// { if (++n > 1) bad = 1 }
  END { exit bad }' "$cmd" || err "$cmd names two wp-finalize-run references in one paragraph"

# The command stays a map. Steps 1, 2 and 4 and the short checks (1, 3, 5, 6, the Tailwind
# convention, the craft gate) stay whole: the report format and the short gates are what the
# run needs in view from the start. 12288 is the new size (about 11.6 KB) plus headroom for a
# few added lines; past it, move the next long check to a reference instead of raising it.
size=$(wc -c < "$cmd")
[ "$size" -le 12288 ] || err "$cmd is $size bytes; move long step detail to $refs"

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
