#!/usr/bin/env bash
# The gate is uniform on purpose. /wp-section and /wp-demo can be run standalone, so
# "the caller already validated" is an assumption that breaks the first time someone
# runs one directly -- which is exactly how a manifest and its generated context
# started disagreeing in the first place.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

for c in wp-create wp-init wp-yolo wp-seed wp-section wp-demo wp-audit wp-finalize wp-clone wp-debug wp-robin wp-aos-animator; do
  f="commands/$c.md"
  grep -Fq '.wp-create.json' "$f" || continue   # only commands that read the manifest
  grep -Fq 'wp-config.mjs validate' "$f" || fail "$f reads the manifest but never calls the validator"
  grep -Fq 'exit 2' "$f" || fail "$f does not say what to do when a migration is available"
done

# --- The ceilings are recorded where the other ceilings live. ---------------
grep -Fq 'wp-config.mjs' CLAUDE.md || fail "CLAUDE.md does not mention the validator"
grep -Fqi 'binds the commands that call it' CLAUDE.md || fail "CLAUDE.md does not record the validator's ceiling"

echo PASS
