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
             "microinteraction appetite" "the one action" "reference: what to take"; do
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

echo PASS
