#!/usr/bin/env bash
# /wp-clone exported the whole production database to a FIXED path, /tmp/wp-clone-dump.sql,
# on both the production server and the local machine. It removed the remote copy and never
# removed the local one -- so after every SSH clone a full production dump (customer records,
# order rows, password hashes, whatever API keys live in wp_options) sat in /tmp at a
# predictable name, with default permissions, until the machine rebooted.
#
# The fixed name was two problems at once: a predictable path in a world-writable directory
# on a production host, and a collision between two clones running at the same time -- the
# second export overwrites the first, and the first clone then imports the second site's
# database into its own destination with nothing to say so.
#
# This pins that no fixed dump path comes back and that both copies are removed
# unconditionally, since the failing run is the one that leaves a dump behind.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

f=commands/wp-clone.md
[ -f "$f" ] || fail "$f is missing"
need() { grep -Fq "$1" "$f" || fail "$f $2"; }

# No fixed dump path, anywhere. This is the regression that reintroduces every property
# below at once, so it is checked as a literal rather than inferred from the rest.
if grep -Fq '/tmp/wp-clone-dump.sql' "$f"; then
  fail "$f still names the fixed path /tmp/wp-clone-dump.sql -- predictable on a production host, and two concurrent clones share it"
fi

need 'mktemp' 'does not use mktemp for the dump path'
# Needle kept within one line: the sentence wraps in the command, and grep -F matches
# within a line, so a longer phrase would fail on formatting rather than on meaning.
need 'path in a world-writable directory' \
  'does not say why a fixed path on a production server is a problem'
need 'share one filename' \
  'does not say what two concurrent clones do to each other -- the collision silently imports the wrong database'

# Permissions have to be set AS the file is created. A chmod afterwards leaves a window in
# which the whole database is already on disk at the default mode.
need 'umask 077' 'does not restrict the dump permissions on the remote'
need 'chmod 600' 'does not restrict the dump permissions locally'
need 'leaves a window in which the dump already exists' \
  'does not explain why umask is set in the same shell rather than chmod afterwards'

# Both copies deleted, and neither deletion conditional on the preceding step succeeding.
need 'Delete the remote copy whether or not the transfer worked' \
  'makes the remote cleanup conditional on a successful transfer'
need 'delete it whether the import succeeded or not' \
  'makes the local cleanup conditional on a successful import'
need 'absent from every case that needed it' \
  'does not say why cleanup must not be conditional on success'
need 'A failed import is the case that matters' \
  'does not say why the failing run is the one that leaves a dump behind'

# Ordering: each cleanup must follow the step it cleans up after, and both must exist.
rm_remote=$(grep -n "rm -f '\\\\\$REMOTE_DUMP'" "$f" | head -1 | cut -d: -f1 || true)
rm_local=$(grep -n 'rm -f \\"\\\$LOCAL_DUMP\\"' "$f" | head -1 | cut -d: -f1 || true)
imp=$(grep -n 'db import \\"\\\$LOCAL_DUMP\\"' "$f" | head -1 | cut -d: -f1 || true)
[ -n "$rm_remote" ] || fail "$f never removes the remote dump"
[ -n "$imp" ] || fail "$f no longer imports from the captured local dump path"
[ -n "$rm_local" ] || fail "$f never removes the local dump"
[ "$imp" -lt "$rm_local" ] \
  || fail "$f deletes the local dump at line $rm_local, before importing it at line $imp"

# Path B's dump belongs to the operator. Deleting someone's input because the command
# consumed it is not cleanup -- but silence leaves a production database unmentioned.
need 'Do not delete this file' 'deletes the operator-supplied --sql= dump'
need 'may be their only copy' 'does not say why the supplied dump is left in place'
need 'staying silent leaves a production database' \
  'does not require the supplied dump to be named in the summary'
need 'Database dump:' 'the clone summary does not account for the dump'

echo "PASS: dump paths are unique and owner-only, and both copies are removed unconditionally"
