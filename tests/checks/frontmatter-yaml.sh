#!/usr/bin/env bash
# Frontmatter that does not parse as YAML fails silently: Claude Code loads the command, agent or
# skill with NO fields set. wp-demo-craft's description held an unquoted ": " and so had no
# description to be matched on and `user-invocable` back at its default of true, showing in the
# `/` menu as if it were a command; /wp-cinematic-demo had the same ": " (inside its
# `<!-- SECTION: -->` example) and /wp-cinematic-scene an `--cta` argument description starting
# with a backtick, so neither loaded its own description. Nothing errored in any of the three.
#
# The repo has no YAML library to lean on, so this checks the shapes that broke, in every
# frontmatter line of every layer: an unquoted value may not contain ": " or " #" (a mapping
# indicator and a comment) and may not start with a backtick, "@" or "%" (reserved). Quote the
# value or rephrase it. Block scalars (`key: |` / `key: >`) are skipped, since their lines are
# text.
set -euo pipefail
cd "$(dirname "$0")/../.."

bad=$(awk '
  FNR == 1 { infm = ($0 ~ /^---$/); blk = -1; next }
  !infm { next }
  /^---$/ { infm = 0; next }
  {
    match($0, /^ */); ind = RLENGTH
    if (blk >= 0) { if (ind > blk || $0 ~ /^[[:space:]]*$/) next; blk = -1 }
    if (!match($0, /^ *(- )?[A-Za-z_][A-Za-z0-9_-]*: /)) next
    v = substr($0, RLENGTH + 1)
    if (v ~ /^[|>][-+0-9]*[[:space:]]*$/) { blk = ind; next }
    if (v ~ /^["\047]/) next
    if (index(v, ": ") || index(v, " #") || v ~ /^[`@%]/) print FILENAME ":" FNR ": " $0
  }
' commands/*.md agents/*.md skills/*/SKILL.md)

if [ -n "$bad" ]; then
  printf '%s\n' "$bad" | cut -c1-200
  echo "FAIL: the frontmatter lines above are not valid YAML unquoted — quote the value or rephrase it; as written, Claude Code loads the file with no fields set"
  exit 1
fi
echo PASS
