#!/usr/bin/env bash
set -euo pipefail
# Every slash command declares the three frontmatter fields Claude Code reads to run it:
# `description` (the `/` menu), `allowed-tools` and `argument-hint`. Two drifts shipped:
# commands that asked the user a question (or dispatched agents) without declaring the
# tool, so the run was denied it or prompted for it mid-flow, and flags the body accepted
# that the hint never listed, so a user could not discover them.
#
# Rules, checked on every commands/*.md:
#   1. `description`, `allowed-tools` and `argument-hint` are all present. A command that
#      accepts no arguments writes `argument-hint: ""` rather than omitting the key, so an
#      absent hint always means "forgotten", never "none".
#   2. A command whose expanded body (its own `<name>-run` references included) names
#      `AskUserQuestion` lists it in `allowed-tools`.
#
# The rules run through one function so the self-test at the bottom can feed it a fixture
# tree: a check that only ever sees the real tree would pass on an empty glob.
cd "$(dirname "$0")/.."/..
. tests/checks/lib/expand-command.sh

fail() { echo "FAIL: $*"; exit 1; }

# fm_value <file> <key>: prints the frontmatter line for key, empty and status 1 when absent.
fm_value() {
  awk -v k="$2" '
    NR == 1 { if ($0 != "---") exit 1; next }
    /^---$/ { exit }
    index($0, k ":") == 1 { print; found = 1; exit }
    END { exit !found }
  ' "$1"
}

# check_command <file> <body-file>: prints one problem per line.
check_command() {
  local f=$1 body=$2 tools
  fm_value "$f" description >/dev/null || echo "$f: no description"
  fm_value "$f" argument-hint >/dev/null || echo "$f: no argument-hint (write argument-hint: \"\" when it takes none)"
  if tools=$(fm_value "$f" allowed-tools); then
    if grep >/dev/null -c 'AskUserQuestion' "$body" && ! grep >/dev/null -c 'AskUserQuestion' <<<"$tools"; then
      echo "$f: names AskUserQuestion but allowed-tools does not list it"
    fi
  else
    echo "$f: no allowed-tools"
  fi
}

# ── Self-test: the rules must fire on a broken fixture and stay quiet on a good one ──
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
printf -- '---\ndescription: ok\nallowed-tools: Read, AskUserQuestion\nargument-hint: ""\n---\nAsk with AskUserQuestion.\n' >"$scratch/good.md"
printf -- '---\ndescription: ok\nallowed-tools: Read\n---\nAsk with AskUserQuestion.\n' >"$scratch/bad.md"
printf -- '---\nallowed-tools: Read\nargument-hint: x\n---\nbody\n' >"$scratch/nodesc.md"
[ -z "$(check_command "$scratch/good.md" "$scratch/good.md")" ] || fail "self-test: a compliant command was reported"
bad=$(check_command "$scratch/bad.md" "$scratch/bad.md")
grep >/dev/null -c 'no argument-hint' <<<"$bad" || fail "self-test: a missing argument-hint was not reported"
grep >/dev/null -c 'AskUserQuestion but' <<<"$bad" || fail "self-test: an undeclared AskUserQuestion was not reported"
grep >/dev/null -c 'no description' <<<"$(check_command "$scratch/nodesc.md" "$scratch/nodesc.md")" || fail "self-test: a missing description was not reported"

# ── The real tree ──
n=0; problems=""
for f in commands/*.md; do
  # expand_command greps for run references; a command with none makes that grep exit 1.
  set +o pipefail; expand_command "$f"; set -o pipefail
  problems+=$(check_command "$f" "$EXPANDED")$'\n'
  n=$((n + 1))
done
[ "$n" -gt 0 ] || fail "no commands found"
problems=$(sed '/^$/d' <<<"$problems")
[ -z "$problems" ] || { echo "$problems"; fail "command frontmatter contract broken"; }
echo PASS
