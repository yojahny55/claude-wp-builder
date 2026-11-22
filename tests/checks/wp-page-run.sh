#!/usr/bin/env bash
# commands/wp-page.md was 19 KB, so every /wp-page run read the dispatch prompts of all seven
# page types up front, though a run builds one. The five long types (blog, legal, 404, search,
# embed) moved to skills/wp-page-run/references/, read at the type that needs them. A
# reference nothing points to is a type the run silently never builds, so every file there
# must be named in the command under its own heading and in the skill's table, and the command
# must stay a map rather than grow back.
#
# The command is organized by page type, so the anchor is the "### Type: <name>" heading
# (a reference titles itself "# /wp-page — Type: <name>"), and a pointer must sit before the
# next "###" or "##" heading. Ceiling: the command is 10.8 KB with the five types moved out,
# so 12 KB leaves room for a few added lines but fails if a type's detail is pasted back in.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail=0
err() { echo "FAIL: $*"; fail=1; }

cmd=commands/wp-page.md
skill=skills/wp-page-run/SKILL.md
refs=skills/wp-page-run/references

[ -r "$skill" ] || { echo "FAIL: $skill is missing"; exit 1; }

# An empty references/ would otherwise run the loop once on the literal glob.
shopt -s nullglob
set -- "$refs"/*.md
[ $# -gt 0 ] || { echo "FAIL: $refs has no references"; exit 1; }

for f in "$refs"/*.md; do
  b=$(basename "$f")
  grep -Fq "\${CLAUDE_PLUGIN_ROOT}/skills/wp-page-run/references/$b\` now and" "$cmd" \
    || err "$cmd never sends the run to $b"
  grep -Fq "(references/$b)" "$skill" || err "$skill does not list $b"
  # The reference names its step, and that step heading still exists in the command.
  step=$(sed -n '1s/^# \/wp-page — //p' "$f")
  [ -n "$step" ] || { err "$f has no '# /wp-page — Type: <name>' title"; continue; }
  grep -Fxq -- "### ${step}" "$cmd" || err "$f belongs to $step, which $cmd no longer has"
  # The pointer sits under that step, not elsewhere in the command.
  awk -v s="### ${step}" -v b="references/$b" '
    $0 == s { on = 1; next } /^##+ / { on = 0 } on && index($0, b) { found = 1 }
    END { exit !found }' "$cmd" || err "$cmd points to $b outside $step"
done

# Every pointer in the command resolves to a file.
for p in $(grep -oE 'skills/wp-page-run/references/[a-z0-9-]+\.md' "$cmd" | sort -u); do
  [ -r "$p" ] || err "$cmd points to $p, which does not exist"
done

# Two pointers in one paragraph would leave the expansion one body short: expand-command.sh
# splices a single reference in at the blank line that closes the paragraph naming it.
awk '/^$/ { n = 0; next } /skills\/wp-page-run\/references\// { if (++n > 1) bad = 1 }
  END { exit bad }' "$cmd" || err "$cmd names two wp-page-run references in one paragraph"

# The command stays a map. Steps 1 and 2, the CSS agent routing, the tailwind prompt body and
# the generic and custom types stay whole, because the run needs them in view and the
# dispatch-site walk in wp-commands-tailwind.sh reads them there.
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
