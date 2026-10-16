#!/usr/bin/env bash
# /wp-clone Path B took a dump plus an uploads archive, so a hosting-panel backup (whole docroot
# archive plus dump) had no path: users restored by hand and forgot the parts that bite --
# a docroot nested under a folder, a dump that USEs the source's database, a wp-config that pins
# the source URL, a Redis drop-in that kills WP-CLI, uploads symlinked to a directory Apache
# cannot traverse. Path C carries those; this pins them and that Path C joins the shared gates.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
. tests/checks/lib/expand-command.sh; expand_command commands/wp-clone.md; f=$EXPANDED
need() { grep -Fq -- "$1" "$f" || fail "$2"; }

need '`--files=`' 'the argument table does not document --files='
need '`--db=`' 'the argument table does not document --db='
need '`--uploads-target=`' 'the argument table does not document --uploads-target='
need '| `--files=` is provided' 'Step 1 does not route --files= to Path C'
need 'Path C — Site Archive Restore' 'the command has no Path C'

need 'wp-load.php' 'Path C does not find the docroot from wp-load.php'
need 'shallowest match'  'Path C does not pick the shallowest wp-load.php'
need 'Never unpack it' 'Path C may unpack a multi-GB archive into /tmp'
need 'CREATE DATABASE' 'Path C does not strip CREATE DATABASE/USE from the dump'
need 'local database stays empty' 'Path C does not say why USE must go'
need '`<prefix>users`' 'Path C does not confirm the table prefix against the users table'
need 'only if the file defines them' 'Path C does not undo pinned WP_HOME/WP_SITEURL'
need 'FORCE_SSL_ADMIN' 'Path C leaves forced SSL on a local http vhost'
need 'object-cache.php' 'Path C does not set the cache drop-ins aside'
need '--skip-tables' 'Path C search-replace does not skip heavy tables'
need 'the old domain can remain in those tables' 'Path C does not warn the old domain may remain'
need 'every directory on the way to the target needs search permission' 'Path C does not warn Apache must traverse the uploads target'
need 'mode `700`' 'Path C does not name the 700 home directory trap'
need 'gid=<web group>,umask=002' 'Path C does not give the NTFS mount options'
need 'Do not move or rename those files' 'Path C does not warn that upload paths live in the database'

# Path C joins the shared gates, in order: gate before extraction, isolation before import.
gate=$(grep -n 'Now run Step 1.5 (The Destination Gate)' "$f" | sed -n 3p | cut -d: -f1 || true)
ext=$(grep -n 'tar -xzf /path/site.tar.gz' "$f" | head -1 | cut -d: -f1 || true)
[ -n "$gate" ] && [ -n "$ext" ] && [ "$gate" -lt "$ext" ] || fail "Path C extracts before the destination gate"
iso=$(grep -n 'Now run Step 5.4 (Isolate the Clone' "$f" | sed -n 3p | cut -d: -f1 || true)
imp=$(grep -n 'db import \\"\$SCRATCH' "$f" | head -1 | cut -d: -f1 || true)
[ -n "$iso" ] && [ -n "$imp" ] && [ "$iso" -lt "$imp" ] || fail "Path C imports before Step 5.4 isolation"

# The scratch dump copy is removed regardless of outcome; the operator's file is not.
need 'whether the import succeeded or not' 'Path C leaves the decompressed dump behind on failure'
need 'The operator'"'"'s file is never edited' 'Path C may edit the operator dump'

# Old wrong forms are gone.
! grep -Fq 'Two paths' commands/wp-clone.md || fail "command still says two paths"
echo PASS
