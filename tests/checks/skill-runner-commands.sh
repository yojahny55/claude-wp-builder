#!/usr/bin/env bash
# `wp-robin` and `wp-aos-animator` are the only two ACTION skills in the repo, and every
# skill is `user-invocable: false`, so for two releases there was no way to reach them by
# name: the README carried phantom `/wp-robin` and `/wp-aos-animator` rows for commands that
# did not exist, they were deleted, and the docs then told users to describe the task in
# prose instead — discoverable only by reading the docs a user typing a slash never opens.
#
# The fix is a runner command per skill, NOT `user-invocable: true` on the skill; that value
# is the one state the layer rules forbid, and bin/doc-sync-check.sh pins it. So this check
# asserts both halves of the arrangement at once:
#
#   - the commands exist, say they are runners, and dispatch the skill;
#   - the skills stay non-invocable and keep owning the procedure — the commands must NOT
#     carry a second copy of the phases, because a second copy diverges the first time the
#     skill is fixed and nothing at runtime says which one ran.
#
# The negative assertions are the load-bearing ones: the positive greps alone would pass on a
# command that pasted the whole skill in under a "runner" heading.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

# Prose in this repo is hard-wrapped, so a contract sentence routinely straddles a newline and
# a line-oriented grep misses it. Flatten whitespace first and match a plain substring: an
# assertion that fails on a rewrap gets muted, which is worse than no assertion.
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }
# Substring via `case`, not a pipe into `grep -q`: under `set -o pipefail`, grep exits on its
# match, `tr` takes SIGPIPE and the pipeline reports 141 — a FALSE failure on a correct file.
has() { case "$(flat "$1")" in *"$2"*) return 0 ;; *) return 1 ;; esac; }

robin_cmd=commands/wp-robin.md
aos_cmd=commands/wp-aos-animator.md
robin_skill=skills/wp-robin/SKILL.md
aos_skill=skills/wp-aos-animator/SKILL.md

for f in "$robin_cmd" "$aos_cmd" "$robin_skill" "$aos_skill"; do
  [ -f "$f" ] || fail "$f is missing"
done

# ---------------------------------------------------------------------------
# 1. Frontmatter. A command missing these is inert, not broken — nothing errors,
#    it simply never loads, which is how it goes unnoticed.
# ---------------------------------------------------------------------------
fm() {  # file, regex — frontmatter only
  awk -v re="$2" 'NR <= 8 && $0 ~ re { found = 1 } END { exit !found }' "$1"
}
for f in "$robin_cmd" "$aos_cmd"; do
  for key in '^description:' '^allowed-tools:' '^argument-hint:'; do
    fm "$f" "$key" || fail "$f has no ${key#^} in its frontmatter"
  done
done

# ---------------------------------------------------------------------------
# 2. The skills stay non-invocable. Flipping this is the workaround these two
#    commands exist to make unnecessary.
# ---------------------------------------------------------------------------
for f in "$robin_skill" "$aos_skill"; do
  grep -Fq 'user-invocable: false' "$f" \
    || fail "$f no longer declares user-invocable: false — a runner command is the supported way in, not an invocable skill"
  ! grep -Fq 'user-invocable: true' "$f" \
    || fail "$f declares user-invocable: true, the one state the layer rules forbid"
done

# ---------------------------------------------------------------------------
# 3. Each command says what it is — a runner whose skill still owns the method —
#    in the repo's own words for it.
# ---------------------------------------------------------------------------
for f in "$robin_cmd" "$aos_cmd"; do
  has "$f" 'runner' || fail "$f never says it is a runner for the skill of the same name"
  has "$f" 'Dispatch, never reimplement' \
    || fail "$f does not state the layer rule it depends on ('dispatch, never reimplement')"
  has "$f" 'source of truth' \
    || fail "$f does not say the skill is the source of truth for the procedure"
  has "$f" 'user-invocable: false' \
    || fail "$f does not explain WHY it exists — the skill it runs is not user-invocable"
done
grep -Fq '${CLAUDE_PLUGIN_ROOT}/skills/wp-robin/SKILL.md' "$robin_cmd" \
  || fail "$robin_cmd does not read its skill by plugin-relative path"
grep -Fq '${CLAUDE_PLUGIN_ROOT}/skills/wp-aos-animator/SKILL.md' "$aos_cmd" \
  || fail "$aos_cmd does not read its skill by plugin-relative path"

# ---------------------------------------------------------------------------
# 4. /wp-robin runs the skill's bundled script, and honours the WP_ROOT override
#    the skill documents — without it the script walks up from the working
#    directory and silently fixes whichever install happens to be above it.
# ---------------------------------------------------------------------------
grep -Fq '${CLAUDE_PLUGIN_ROOT}/skills/wp-robin/scripts/robin-fix.sh' "$robin_cmd" \
  || fail "$robin_cmd does not run the skill's bundled robin-fix.sh"
grep -Fq 'WP_ROOT=' "$robin_cmd" \
  || fail "$robin_cmd never passes WP_ROOT, so a target root argument cannot reach the script"
grep -Fq 'wp-config.php' "$robin_cmd" \
  || fail "$robin_cmd does not validate the target is a WordPress root"

# ---------------------------------------------------------------------------
# 5. /wp-aos-animator takes a scope and the house audit-only flag, and
#    parallelizes the phase the skill says is parallelizable — one agent per
#    template, so two agents never edit the same file.
# ---------------------------------------------------------------------------
grep -Fq -- '--report-only' "$aos_cmd" \
  || fail "$aos_cmd has no --report-only mode (the house flag, as in /wp-audit) for an audit-only run"
has "$aos_cmd" 'one subagent per template' \
  || fail "$aos_cmd does not dispatch Phase 5 per template, which is the parallelism the skill describes"
grep -Fq 'Agent' "$aos_cmd" \
  || fail "$aos_cmd dispatches subagents but does not carry Agent in allowed-tools"

# ---------------------------------------------------------------------------
# 6. And the commands did NOT copy the skills' procedures. These greps are the
#    ones that fail if someone "helpfully" inlines the steps: each string below
#    is a piece of an implementation that must live in exactly one file.
# ---------------------------------------------------------------------------
! grep -Fq "wp_enqueue_style('aos-css'" "$aos_cmd" \
  || fail "$aos_cmd carries the enqueue snippet — that is Phase 3, and it belongs only in $aos_skill"
! grep -Fq 'AOS.init(' "$aos_cmd" \
  || fail "$aos_cmd carries the init snippet — that is Phase 4, and it belongs only in $aos_skill"
! grep -Fq 'dist/aos.js' "$aos_cmd" \
  || fail "$aos_cmd carries the download URL — that is Phase 2, and it belongs only in $aos_skill"
! grep -Fq 'data-aos-delay' "$aos_cmd" \
  || fail "$aos_cmd restates the animation/delay convention, which only $aos_skill may define"
! grep -Fq 'rio_process_queue' "$robin_cmd" \
  || fail "$robin_cmd reaches into Robin's queue table itself — robin-fix.sh owns that"
! grep -Eq 'sha256sum|json_decode|unserialize' "$robin_cmd" \
  || fail "$robin_cmd reimplements part of robin-fix.sh instead of running it"

# ---------------------------------------------------------------------------
# 7. The prose that said these two have no slash command is gone from all three
#    docs. It was true and is now the opposite of true; a reader who believes it
#    never types the command.
# ---------------------------------------------------------------------------
for doc in README.md docs/commands.md docs/workflows.md; do
  ! grep -Eqi 'skills, not commands|are \*\*skills\*\*|is no `?/wp-robin' "$doc" \
    || fail "$doc still says wp-robin/wp-aos-animator have no slash command"
done
# ...and replaced, not merely deleted: each doc must still explain that the skills are
# reached THROUGH the commands, or the layer rule reads as having been abandoned.
for doc in README.md docs/commands.md docs/workflows.md; do
  grep -Eqi 'through (their|its) command|invoked through' "$doc" \
    || fail "$doc dropped the old prose without saying the skills are now invoked through their commands"
done

echo PASS
