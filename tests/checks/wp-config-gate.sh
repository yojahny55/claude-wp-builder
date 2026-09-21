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

`${PROJECT_PATH}` is not an environment variable the way `${CLAUDE_PLUGIN_ROOT}` beside it is: it is the WordPress project root, the directory holding `.wp-create.json`, and you substitute the real path yourself — the one the user named, or the working directory when they named none — because an empty argument makes the validator print its usage line and exit `1`, which the table below then reads as "stop and report".

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs validate '${PROJECT_PATH}'"
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
found=0
for f in commands/*.md; do
  grep -Fq '.wp-create.json' "$f" || continue   # only commands that read the manifest
  rm -f "$tmp"/blk.*
  n=$(awk -v out="$tmp/blk." '
    /^\*\*First: validate the project configuration\.\*\*$/ { n++; inb = 1 }
    inb { print > (out n) }
    inb && /^On exit 2, run the migration before continuing\.$/ { inb = 0 }
    END { print n + 0 }
  ' "$f")
  [ "$n" -gt 0 ] || fail "$f reads the manifest but never calls the validator"
  for i in $(seq 1 "$n"); do
    diff -u "$tmp/canonical" "$tmp/blk.$i" >"$tmp/d" \
      || fail "$f gate block #$i is not byte-identical to the canonical block:
$(cat "$tmp/d")"
  done
  found=$((found + n))
done
[ "$found" -ge 13 ] || fail "only $found gate blocks found, want at least 13"

# --- Where exit 3 is not a stop, the table row is AMENDED, not contradicted. -
# The row three lines above says "stop and say so"; these commands legitimately
# fall through. The block stays byte-identical everywhere, so the amendment has to
# live outside it -- and it has to announce itself, or a Claude acts on the row it
# just read and stops on a legitimate path.
for c in wp-seed wp-debug wp-robin wp-init wp-audit wp-clone wp-adopt; do
  grep -Fq 'Amending the exit `3` row above:' "commands/$c.md" \
    || fail "commands/$c.md contradicts the exit 3 table row instead of amending it"
done

# --- The ceilings are recorded where the other ceilings live. ---------------
grep -Fq 'wp-config.mjs' CLAUDE.md || fail "CLAUDE.md does not mention the validator"
grep -Fqi 'binds the commands that call it' CLAUDE.md || fail "CLAUDE.md does not record the validator's ceiling"

echo PASS
