#!/usr/bin/env bash
# commands/wp-seed.md grew to 45 KB, so every /wp-seed run read the parse, media, ACF, bilingual,
# menu and final-setup detail up front, long before it reached those phases. Those phases moved
# to skills/wp-seed-run/references/, read at the phase that needs them. A reference nothing
# points to is a phase the run silently never performs, so every file there must be named in the
# command under its own heading and in the skill's table, and the command must stay a map
# rather than grow back.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail=0
err() { echo "FAIL: $*"; fail=1; }

cmd=commands/wp-seed.md
skill=skills/wp-seed-run/SKILL.md
refs=skills/wp-seed-run/references

[ -r "$skill" ] || { echo "FAIL: $skill is missing"; exit 1; }

# An empty references/ would otherwise run the loop once on the literal glob.
shopt -s nullglob
set -- "$refs"/*.md
[ $# -gt 0 ] || { echo "FAIL: $refs has no references"; exit 1; }

for f in "$refs"/*.md; do
  b=$(basename "$f")
  grep -Fq "\${CLAUDE_PLUGIN_ROOT}/skills/wp-seed-run/references/$b\` now and" "$cmd" \
    || err "$cmd never sends the run to $b"
  grep -Fq "(references/$b)" "$skill" || err "$skill does not list $b"
  # The reference names its step, and that step heading still exists in the command.
  step=$(sed -n '1s/^# \/wp-seed — //p' "$f")
  [ -n "$step" ] || { err "$f has no '# /wp-seed — Phase N' title"; continue; }
  grep -Eq -- "^## ${step}( |:)" "$cmd" || err "$f belongs to $step, which $cmd no longer has"
  # The pointer sits under that step, not elsewhere in the command.
  awk -v s="^## ${step}( |:)" -v b="references/$b" '
    $0 ~ s { on = 1; next } /^## / { on = 0 } on && index($0, b) { found = 1 }
    END { exit !found }' "$cmd" || err "$cmd points to $b outside $step"
done

# Every pointer in the command resolves to a file.
for p in $(grep -oE 'skills/wp-seed-run/references/[a-z0-9-]+\.md' "$cmd" | sort -u); do
  [ -r "$p" ] || err "$cmd points to $p, which does not exist"
done

# Two pointers in one paragraph would leave the expansion one body short: expand-command.sh
# splices a single reference in at the blank line that closes the paragraph naming it.
awk '/^$/ { n = 0; next } /skills\/wp-seed-run\/references\// { if (++n > 1) bad = 1 }
  END { exit bad }' "$cmd" || err "$cmd names two wp-seed-run references in one paragraph"

# The command stays a map. Step 0, Phases 1.5, 2, 4.5, 6.5 and the Seed Report stay whole,
# because they are the gates and the resolve-before-create rule the run needs in view from the
# start. The command is 18 KB after the split; the 20 KB ceiling leaves room for a sentence or
# two per phase, and a step that needs more goes to its reference file instead.
size=$(wc -c < "$cmd")
[ "$size" -le 20480 ] || err "$cmd is $size bytes; move long step detail to $refs"

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
