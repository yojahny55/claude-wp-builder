#!/usr/bin/env bash
# Craft vs plain is a RECORDED decision, exactly like the i18n strategy. Every command
# downstream branches on it, so a command that re-derives the mode instead of reading the
# manifest will disagree with the one that wrote it, and the theme ships motion the demo
# never had (or loses the motion the client approved).
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

d=commands/wp-demo.md
y=commands/wp-yolo.md
i=commands/wp-init.md
p=commands/wp-polish.md

# --- The flags and the recorded decision. -----------------------------------
grep -Fq -- '--craft' "$d" || fail "$d does not document the --craft flag"
grep -Fq -- '--plain' "$d" || fail "$d does not document the --plain flag"
grep -Fq 'demo mode' "$d" || fail "$d does not record `demo mode` in the manifest"
grep -Fq '.wp-create.json' "$d" || fail "$d does not name the manifest it writes to"
grep -Fqi 'docs/' "$d" || fail "$d does not read the project docs to choose the mode"

# --- The brief is docs-first and asks only what is missing. -----------------
grep -Fq 'demo/BRIEF.md' "$d" || fail "$d does not write demo/BRIEF.md"
grep -Eqi 'self-author' "$d" || fail "$d does not self-author the brief from the docs"
grep -Eqi 'only the questions|only ask|cannot answer' "$d" \
  || fail "$d does not limit the interview to what the docs cannot answer"
grep -Fq 'wp-demo-craft' "$d" || fail "$d does not read the wp-demo-craft skill"

# --- The gates that make a craft build different from a pretty one. --------
grep -Eqi 'fingerprint' "$d" || fail "$d does not run the fingerprint gate"
grep -Eqi 'feeling curve' "$d" || fail "$d does not write the feeling curve"
grep -Fq '/wp-demo-verify' "$d" || fail "$d does not hand off to /wp-demo-verify"

# --- Downstream commands read the decision, they do not re-derive it. ------
grep -Fq 'demo mode' "$y" || fail "$y does not read `demo mode`"
grep -Fq 'wp-demo-craft' "$y" || fail "$y does not read the craft skill in craft mode"
grep -Fq 'demo mode' "$i" || fail "$i does not read `demo mode`"
grep -Fq 'motion.js' "$i" || fail "$i does not wire motion.js for craft projects"
grep -Fq 'wp-aos-animator' "$i" || fail "$i does not keep wp-aos-animator for plain projects"

# --- The retrofit audit. -----------------------------------------------------
grep -Fq -- '--craft' "$p" || fail "$p does not document the --craft retrofit audit"

echo PASS
