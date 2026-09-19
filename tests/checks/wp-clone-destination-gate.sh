#!/usr/bin/env bash
# /wp-clone ran `wp db import` against the destination twice -- once per path -- with no
# backup, no existence check and no confirmation. A dump carries DROP TABLE / CREATE TABLE,
# so the import does not merge into the destination database, it replaces it; rsync
# overwrites matching paths under wp-content/uploads/ the same way.
#
# The destination is a local development site, which is exactly where unpushed work lives:
# seeded content, ACF values, test orders, a demo built that afternoon. /wp-seed carries a
# whole ownership model so it never overwrites a client's work inside a database. Replacing
# that database wholesale was one command with no prompt.
#
# This pins the gate, and above all that it is reached from BOTH write paths.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

f=commands/wp-clone.md
[ -f "$f" ] || fail "$f is missing"
need() { grep -Fq "$1" "$f" || fail "$f $2"; }

need 'Step 1.5: The Destination Gate' 'has no destination gate'

# Written once, reached from both paths. A second copy would drift, and the copy that
# drifted would be the one guarding the path nobody tested.
invocations=$(grep -c 'Step 1.5 (The Destination Gate)' "$f" || true)
[ "${invocations:-0}" -ge 3 ] \
  || fail "$f invokes the gate ${invocations:-0} time(s); both db imports and the uploads rsync must each reach it"

# Every destructive site must be downstream of an invocation. Checked by position, because
# prose saying "run the gate" somewhere after the import would read correct and guard nothing.
gate_a=$(grep -n 'Now run Step 1.5 (The Destination Gate)' "$f" | sed -n 1p | cut -d: -f1 || true)
imp_a=$(grep -n 'db import /tmp/wp-clone-dump.sql' "$f" | head -1 | cut -d: -f1 || true)
gate_b=$(grep -n 'Now run Step 1.5 (The Destination Gate)' "$f" | sed -n 2p | cut -d: -f1 || true)
imp_b=$(grep -n 'db import /path/to/dump.sql' "$f" | head -1 | cut -d: -f1 || true)
for pair in "A:$gate_a:$imp_a" "B:$gate_b:$imp_b"; do
  IFS=: read -r label g i <<<"$pair"
  [ -n "$g" ] || fail "$f path $label never invokes the destination gate before its import"
  [ -n "$i" ] || fail "$f path $label no longer imports where this check expects it"
  [ "$g" -lt "$i" ] \
    || fail "$f path $label invokes the gate at line $g, AFTER its import at line $i -- a gate downstream of the write it guards is not a gate"
done

# The ordinary case must stay quiet, or the gate becomes noise people click through and the
# one run that mattered looks like all the others.
need 'empty destination proceeds silently' \
  'does not keep the gate quiet on an empty destination -- a gate that fires every run is one people learn to skip'

# Back up BEFORE asking. A refusal the operator overrides is still a refusal they overrode
# with no copy taken if the export waits for the answer.
need 'back it up **before** asking anything' 'does not take the backup before prompting'
need '.wp-clone-backups' 'does not put the backup outside the project'
need 'shares the fate of the thing it protects' \
  'does not explain why the backup lives outside wp-content -- inside, the next rsync or an rm -rf takes it too'
need 'Print the full path' 'does not print where the backup went'

# "Overwrite?" is a question nobody can answer. What is there is.
need 'Do not ask "overwrite?"' 'lets the gate ask an abstract question instead of naming what would be lost'
need 'Last modified' 'does not show how recent the destination content is'

# --force is consent, not a bypass of the copy.
need '`--force` proceeds, and still backs up' 'does not keep the backup under --force'
need 'never "skip the safety net"' \
  'does not say what --force means -- tying the backup to the flag removes it from the runs most likely to need it'

# The step scrolls away long before the clone ends.
need 'Backup      ~/.wp-clone-backups' 'the clone summary does not carry the backup path'
need 'omit this block entirely when the destination was empty' \
  'does not keep the summary quiet when nothing was replaced'

# The flag has to be parseable, or the gate can never be passed.
grep -Fq '| `--force` |' "$f" || fail "$f does not document --force in the argument table"

echo "PASS: both write paths reach the destination gate before writing, and it backs up first"
