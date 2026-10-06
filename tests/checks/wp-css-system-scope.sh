#!/usr/bin/env bash
# wp-css-system must declare itself basic-only. Its unconditional "no
# frameworks" rule previously banned Tailwind even on the tailwind path.
set -euo pipefail
f=skills/wp-css-system/SKILL.md

grep -Eq 'template=basic|`basic`' "$f" \
  || { echo "FAIL: wp-css-system does not scope itself to template=basic"; exit 1; }
grep -q 'wp-tailwind-system' "$f" \
  || { echo "FAIL: wp-css-system does not redirect tailwind projects to wp-tailwind-system"; exit 1; }

# The gate answers every recorded value, not only tailwind. /wp-init writes `tailwind` or
# `cinematic`; the banner used to stop only on `tailwind`, so a cinematic theme read BEM +
# :root rules for its cinematic.css, and a demo — which has no .claude/CLAUDE.md yet — had
# no answer at all while /wp-demo sends every plain demo here.
gate=$(awk 'NR > 1 && /^# /{exit} {print}' "$f" | tr '\n' ' ' | sed 's/  */ /g')
# Here-strings, not `printf | grep -q`: under pipefail an early-exiting grep -q can give
# printf a SIGPIPE and the pipeline then fails with the text present.
grep -Eq '`cinematic` \| \*\*None\. Stop' <<<"$gate" \
  || { echo "FAIL: wp-css-system's scope gate has no stop for Template: cinematic"; exit 1; }
grep -Eq 'no `Template:` line' <<<"$gate" \
  || { echo "FAIL: wp-css-system's scope gate does not say which rules apply to a demo with no Template: line"; exit 1; }
grep -Fq 'demo mode: craft' <<<"$gate" \
  || { echo "FAIL: wp-css-system's scope gate does not hand a craft demo's tokens to demo/DESIGN.md"; exit 1; }

# The framework prohibition must be scoped, not absolute.
#
# Matched against a FLATTENED copy, never against a numbered line. The old form was
# `line=$(grep -n 'No frameworks' … | cut -d: -f1)` followed by `sed -n "${line}p"`,
# so it judged that ONE physical line. Skill files wrap at ~90 columns, and the rule
# is a bold label: re-wrapping it as `**No frameworks on this\n   template**` — a
# formatting change that alters nothing this gate cares about — moved `this template`
# onto the next line and the gate answered "the rule is still unconditional", which
# was false. Anything line-anchored here dies on the next re-wrap.
#
# The `|| true` is load-bearing. A zero-match `grep` inside a command substitution
# exits 1, and under `set -euo pipefail` that kills the whole script BEFORE its own
# FAIL line can run — rc=1 with no output at all, and the "rule not found" FAIL
# below becomes dead code. Proven by renaming the rule out of existence. Same shape
# and same reason as the `|| true` on `qmode` in tests/checks/wp-tailwind-migrate.sh.
#
# The needle tolerates an inserted qualifier ("No CSS frameworks on this template"),
# which is a rename a careful author makes; the scope words, not the label's exact
# wording, are what this gate is about. The window runs to the end of the sentence
# (`[^.]`), so the scope may be stated in the label or in the clause after it.
#
# Ceiling: the FIRST such rule in the file is the one judged — that is the Principles
# rule the tailwind path tripped over. The delivery checklist near the end of the file
# carries its own unconditional "No CSS frameworks, preprocessors, or build tools"
# line, which is a checklist item for a basic theme and is deliberately not gated here.
flatf=$(tr '\n' ' ' < "$f" | sed -e 's/ \\ / /g' -e 's/  */ /g')
clause=$(printf '%s' "$flatf" | { grep -oEi 'no ([A-Za-z]+ )?frameworks[^.]{0,200}' || true; } | head -1)
[ -n "$clause" ] || { echo "FAIL: 'No frameworks' rule not found"; exit 1; }
printf '%s' "$clause" | grep -Eq 'basic|this template' \
  || { echo "FAIL: the 'No frameworks' rule is still unconditional: [$clause]"; exit 1; }

# ---------------------------------------------------------------------------
# Repo-wide skill frontmatter. This lives here because this file is already the
# gate on what a SKILL declares about itself, and the rule is one line: CLAUDE.md
# fixes the skill contract as `name`, `description`, `user-invocable: false`, and
# skills inform — they never act, so none of them is a slash command a user picks
# from a menu. wp-tailwind-system shipped without the key and was the only skill
# in the repo missing it; nothing anywhere asserted it, so it surfaced as a
# user-facing entry.
#
# Frontmatter only: the key is read from the block between the opening `---` and
# the first closing `---`, so a later mention in the skill's prose cannot satisfy
# it. Whitespace around the colon is tolerated because YAML tolerates it.
# ---------------------------------------------------------------------------
# Two skills are deliberately user-invocable and are exempt by name. They INSTALL and
# CONFIGURE rather than inform — `wp-robin` unsticks and reconfigures Robin Image
# Optimizer, `wp-aos-animator` installs and enqueues AOS across a theme's templates —
# and both are offered to the user on purpose. They arrived from main after this branch
# forked, and they mean CLAUDE.md's flat "skills inform; they never act" is now the
# convention for knowledge libraries rather than for every skill in the tree. The
# exemption is a NAMED list, not a pattern, so the next skill that omits the key still
# fails; and each name is asserted to still exist, so a rename cannot leave a silent
# hole behind.
ACTION_SKILLS='wp-robin wp-aos-animator'
for a in $ACTION_SKILLS; do
  [ -f "skills/$a/SKILL.md" ] || { echo "FAIL: skills/$a/SKILL.md is exempted from the user-invocable rule but no longer exists — a stale exemption silently widens this gate"; exit 1; }
done

for s in skills/*/SKILL.md; do
  [ -f "$s" ] || { echo "FAIL: no skills/*/SKILL.md found — this gate is matching nothing"; exit 1; }
  name=$(basename "$(dirname "$s")")
  case " $ACTION_SKILLS " in *" $name "*) continue ;; esac
  fm=$(awk 'NR == 1 && $0 !~ /^---[[:space:]]*$/ { exit } NR > 1 && /^---[[:space:]]*$/ { exit } NR > 1 { print }' "$s")
  [ -n "$fm" ] || { echo "FAIL: $s has no YAML frontmatter block — every skill declares name, description and user-invocable: false"; exit 1; }
  printf '%s\n' "$fm" | grep -Eq '^[[:space:]]*user-invocable[[:space:]]*:[[:space:]]*false[[:space:]]*$' \
    || { echo "FAIL: $s frontmatter does not carry 'user-invocable: false'. Skills are knowledge libraries read by commands and agents; one that omits the key is offered to the user as a slash command."; exit 1; }
done

echo PASS
