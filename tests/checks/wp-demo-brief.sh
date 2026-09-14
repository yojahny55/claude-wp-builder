#!/usr/bin/env bash
set -euo pipefail

# The brief: what the operator is asked before anything is built.
#
# Step 3 used to capture person, pain, promise, vibe words, references, the feeling
# curve and the peak -- every field about STORY, what the site says. Not one about
# FORM: what it looks like, how much it moves, how much of it is reading. So a build
# could satisfy the brief completely and still ship twelve pages of dense paragraphs
# with one animation, and nothing in the brief had a field that would have caught it.
#
# It also said "ask, in one pass, only what the docs cannot answer. Show the brief once
# and proceed on a yes" -- while the command's own frontmatter granted no
# AskUserQuestion tool. An instruction to interview, with nothing to interview with.

fail() { echo "FAIL: $*"; exit 1; }

demo=commands/wp-demo.md
[ -f "$demo" ] || fail "$demo is missing"

# --- the command can actually ask ---------------------------------------------
# This is the enabling pin. Without the tool the whole interview is prose that
# describes something the command cannot do.
grep -qE '^allowed-tools:.*AskUserQuestion' "$demo" \
  || fail "$demo is told to interview the operator but is granted no AskUserQuestion tool"

# --- form is interviewed, not inferred ----------------------------------------
grep -qF '3a. Interview the operator about form' "$demo" \
  || fail "$demo must interview the operator about form, not only self-author story"
grep -qF 'Project documents describe a business. They almost never describe a' "$demo" \
  || fail "$demo must say why the form fields are nearly always unanswered by the docs"

# All six fields. Each one exists because its absence produced a specific complaint
# on a real build: no visual vocabulary, walls of text, one animation, no detail,
# no call to action, and references cited without saying what to take from them.
for field in "draw, don't write" "text density" "motion appetite" \
             "microinteraction appetite" "the one action" "reference: what to take" \
             "surface vocabulary" "name the moving things" \
             "where the background does work" "what may we not claim"; do
  grep -qF "$field" "$demo" || fail "$demo: the brief must ask about '$field'"
done

grep -qF 'Offer concrete options rather than open questions' "$demo" \
  || fail "$demo: an open question about density gets an answer nobody can build to"

# --- the answers bind on the plan ---------------------------------------------
# A recorded answer that no later step reads is decoration, which is the failure
# mode this whole file exists to catch.
grep -qF 'The form answers from sub-step 3a bind here' "$demo" \
  || fail "$demo: the composition plan must read the form answers, or they are decoration"

# --- approval is a gate, not a notice -----------------------------------------
grep -qF '3b. The operator approves the brief before anything is built' "$demo" \
  || fail "$demo must gate the build on an approved brief"
grep -qF 'This is a gate, not a courtesy' "$demo" \
  || fail "$demo must say the approval blocks the build"
grep -qF 'no \"proceed unless told otherwise\"' "$demo" \
  || grep -qF 'proceed unless told otherwise' "$demo" \
  || fail "$demo must refuse the proceed-unless-objected reading"
grep -qF 'There is no pass limit' "$demo" \
  || fail "$demo: revision must loop until approved, not for a fixed number of rounds"

# The one-pass rule is what this replaces. If it comes back, the gate is gone.
grep -qF 'Ask, in one pass, only what the docs cannot answer' "$demo" \
  && fail "$demo: the one-pass brief is back, which removes the interview and the gate"

# --- the run records whether it was approved ----------------------------------
grep -qF 'built from a guess' "$demo" \
  || fail "$demo must record approval, so a later run can tell a confirmed brief from a guess"

# --- the question that would have changed the build ---------------------------
# The docs said "impactful animated website", so the old brief step asked nothing --
# and "impactful" is unfalsifiable, which is how it survived four rounds of revision
# without ever being satisfied. The answerable version is a list of pictures.
grep -qF 'what is quantitative here' "$demo" \
  || fail "$demo must ask what this business has that could be drawn"
grep -qF 'Ask this one first' "$demo" \
  || fail "$demo: the quantitative question leads, it does not trail the others"
grep -qF 'three sites whose motion you want' "$demo" \
  || fail "$demo must convert an unfalsifiable adjective into named references"
grep -qF 'the ten-second page' "$demo" \
  || fail "$demo must ask which page carries the business in ten seconds"

# --- a recorded client decision outranks the defaults -------------------------
# The root cause of four rounds of the same complaint: /wp-context wrote an explicit
# animation brief into the project's .claude/CLAUDE.md -- counters, timeline,
# before/after score chart -- and nothing in the craft rules gave it authority over
# the taste floor. The floor won, and every item on that brief shipped missing.
grep -qF 'A recorded client decision outranks the craft defaults' "$demo" \
  || fail "$demo must carry a recorded client brief into the form fields"

craft=skills/wp-demo-craft/SKILL.md
grep -qF "The project's brief outranks this skill" "$craft" \
  || fail "$craft must defer to the project's recorded brief, or the floor overrides the client"
grep -qF 'the brief wins and the discouragement does not apply' "$craft" \
  || fail "$craft must say a recorded brief beats its own defaults"
grep -qF '.claude/CLAUDE.md' "$craft" \
  || fail "$craft never mentions the file that records what the client asked for"

# --- cards and icons: identical and decorative are the failures ---------------
# Read as a ban, the card rule produces a hairline definition list per section,
# which is the same undifferentiated shape it exists to prevent. And `icon` used to
# appear in the whole skill exactly once, inside a prohibition, while the client was
# asking for animated icons by name.
taste=skills/wp-demo-craft/references/taste.md
grep -qF 'The failure is identical cards, not cards' "$taste" \
  || fail "$taste reads as a ban on cards, which produces a hairline list per section instead"
grep -qF 'Decorative' "$taste" \
  || fail "$taste must distinguish a decorative icon from one that carries meaning"

# The one positive instruction in a file otherwise made of prohibitions.
grep -qF 'When a section states something quantitative, draw it' "$taste" \
  || fail "$taste is all prohibition and never says reach for a graphic"

echo PASS
