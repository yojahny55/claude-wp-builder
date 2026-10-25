#!/usr/bin/env bash
# The gate is uniform on purpose. /wp-section and /wp-demo can be run standalone, so
# "the caller already validated" is an assumption that breaks the first time someone
# runs one directly -- which is exactly how a manifest and its generated context
# started disagreeing in the first place.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# The gate block, once, byte for byte. Every insertion site is diffed against this
# rather than grepped for a few of its lines: byte-identity is the property that lets
# a reviewer diff thirteen sites against each other and read nothing, and a grep for
# one phrase cannot see a site that kept the phrase and lost the sentence beside it.
# Quoted heredoc -- ${PROJECT_PATH} and ${CLAUDE_PLUGIN_ROOT} are literal text here.
cat >"$tmp/canonical" <<'GATE'
**First: validate the project configuration.**

`${PROJECT_PATH}` is not an environment variable the way `${CLAUDE_PLUGIN_ROOT}` beside it is: it is the WordPress project root, the directory holding `.wp-create.json`, and you substitute the real path yourself — the one the user named, or the working directory when they named none — because an empty argument makes the validator print its usage line and exit `1`, which the table below then reads as "stop and report". The path travels as a positional argument, never inside the `-c` string: write it in single quotes, and a path that holds a single quote gets each one written as `'\''`.

```bash
bash -c 'node "$1/bin/wp-config.mjs" validate "$2"' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

| Exit | Meaning | Do |
|---|---|---|
| `0` | valid | continue |
| `1` | invalid, or the generated context block disagrees with the manifest | stop and report the message verbatim |
| `2` | an older manifest can migrate | run `wp-config.mjs migrate '${PROJECT_PATH}'`, then continue |
| `3` | no manifest | this project was not created by `/wp-create`; stop and say so |

On exit 2, run the migration before continuing.
GATE

# ${PROJECT_PATH} is defined in exactly one command (/wp-create Step 1) and used in
# twelve. A Claude that reads it as an environment variable the way ${CLAUDE_PLUGIN_ROOT}
# genuinely is runs `validate ''`, which prints the usage line and exits 1 -- and the
# table above then says "stop and report". Every gated command hard-stopped on every
# project. The sentence that says where the path comes from is part of the block.
grep -Fq 'is not an environment variable the way' "$tmp/canonical" \
  || fail "the canonical gate block no longer says where \${PROJECT_PATH} comes from"

# The list of gated commands is the filesystem, not a list kept here: a hardcoded
# twelve-name loop happened to be right on the day it was written and shipped a
# thirteenth ungated manifest-reading command green.
# A command that moved a step's detail to its <name>-run references is read expanded: the
# gate block can sit in a reference, and the block is what the run sees either way.
. tests/checks/lib/expand-command.sh
found=0
for f in commands/*.md; do
  x=$f
  if grep -Fq "skills/$(basename "$f" .md)-run/references/" "$f"; then expand_command "$f"; x=$EXPANDED; fi
  grep -Fq '.wp-create.json' "$x" || continue   # only commands that read the manifest
  rm -f "$tmp"/blk.*
  n=$(awk -v out="$tmp/blk." '
    /^\*\*First: validate the project configuration\.\*\*$/ { n++; inb = 1 }
    inb { print > (out n) }
    inb && /^On exit 2, run the migration before continuing\.$/ { inb = 0 }
    END { print n + 0 }
  ' "$x")
  [ "$n" -gt 0 ] || fail "$f reads the manifest but never calls the validator"
  for i in $(seq 1 "$n"); do
    diff -u "$tmp/canonical" "$tmp/blk.$i" >"$tmp/d" \
      || fail "$f gate block #$i is not byte-identical to the canonical block:
$(cat "$tmp/d")"
  done
  found=$((found + n))
done
[ "$found" -ge 13 ] || fail "only $found gate blocks found, want at least 13"

# --- Exit 3 has ONE definition: skills/wp-manifest-gate/SKILL.md. ---------
# Nine commands each carried their own "Amending the exit `3` row above" paragraph, hand-copied,
# and they drifted (/wp-audit also told adoptable sites to run /wp-init). The block stays
# byte-identical everywhere; what a command does on exit 3 is now one named policy line that
# points at the skill. Assert both directions: the policy line is present and names a policy the
# skill defines, and no command (or step reference) still carries the old inline paragraph.
gate=skills/wp-manifest-gate/SKILL.md
[ -f "$gate" ] || fail "$gate is missing"
grep -Eq '^user-invocable: false$' "$gate" || fail "$gate must stay user-invocable: false"
policy_of() { sed -n 's/^\*\*Exit `3` policy:\*\* `\([a-zA-Z0-9_-]*\)`.*/\1/p' "$1" | head -n 1; }
declare -A want=(
  [wp-seed]=bare-wp-fallback [wp-robin]=bare-wp-fallback [wp-s3]=bare-wp-fallback [wp-update]=bare-wp-fallback
  [wp-debug]=adopt-or-bare-wp [wp-audit]=adopt-or-stop [wp-adopt]=register [wp-init]=scaffold
  [wp-clone]=destination-adopt
)
for c in $(printf '%s\n' "${!want[@]}" | sort); do
  src=commands/$c.md
  if grep -Fq "skills/$c-run/references/" "$src"; then expand_command "$src"; src=$EXPANDED; fi
  got=$(policy_of "$src")
  [ "$got" = "${want[$c]}" ] || fail "commands/$c.md exit 3 policy is '${got:-none}', want '${want[$c]}'"
  grep -Fq "### \`$got\`" "$gate" || fail "$gate does not define the policy $got"
done
# Any command that names a policy at all must name one the skill defines.
for f in commands/*.md; do
  x=$f
  if grep -Fq "skills/$(basename "$f" .md)-run/references/" "$f"; then expand_command "$f"; x=$EXPANDED; fi
  p=$(policy_of "$x"); [ -n "$p" ] || continue
  grep -Fq "### \`$p\`" "$gate" || fail "$f names an undefined exit 3 policy: $p"
done
# The old inline amendment, anywhere a run reads: gone.
! grep -rFq --include='*.md' 'Amending the exit `3` row above' commands skills \
  || fail "an inline 'Amending the exit 3 row above' paragraph is back: name a policy from $gate instead"
# The prologue is not copied beside the block either: the paragraph that says where PROJECT_PATH
# comes from lives only inside the byte-identical block, once per gate.
for f in commands/*.md; do
  x=$f
  if grep -Fq "skills/$(basename "$f" .md)-run/references/" "$f"; then expand_command "$f"; x=$EXPANDED; fi
  n=$(grep -Fc 'is not an environment variable the way' "$x" || true)
  g=$(grep -Fc '**First: validate the project configuration.**' "$x" || true)
  [ "$n" -le "$g" ] || fail "$f repeats the PROJECT_PATH prologue outside its gate block"
done
# wp-audit must not send an adoptable site to /wp-init when the context file is missing.
! grep -Fq 'Project not initialized. Run /wp-init first' commands/wp-audit.md \
  || fail "wp-audit.md tells an existing site to run /wp-init"
grep -Fq 'Run /wp-adopt for an existing site' commands/wp-audit.md \
  || fail "wp-audit.md does not offer /wp-adopt when .claude/CLAUDE.md is missing"

# --- The ceilings are recorded where the other ceilings live. ---------------
grep -Fq 'wp-config.mjs' CLAUDE.md || fail "CLAUDE.md does not mention the validator"
grep -Fqi 'binds the commands that call it' CLAUDE.md || fail "CLAUDE.md does not record the validator's ceiling"

echo PASS
