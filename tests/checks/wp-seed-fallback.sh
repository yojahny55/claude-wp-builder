#!/usr/bin/env bash
# /wp-seed must not hard-abort when .wp-create.json is absent. /wp-debug already falls back to
# a bare `wp` on PATH; /wp-seed mirrors it and takes languages from .claude/CLAUDE.md, so a
# project that adopted an existing WordPress without running /wp-create can still be seeded.
set -euo pipefail
cd "$(dirname "$0")/../.."
f=commands/wp-seed.md
fail() { echo "FAIL: $*"; exit 1; }

grep -Fq 'which wp' "$f" || fail "$f does not probe for a bare wp on PATH"
grep -Eq 'set .?\$WP.? to .?wp.?' "$f" || fail "$f does not fall back to \$WP=wp"
grep -Fq 'Languages:' "$f" || fail "$f does not read languages from .claude/CLAUDE.md when the manifest is absent"
grep -Fq 'no `wp` on PATH' "$f" || fail "$f aborts without saying both the manifest and wp are missing"

# the old unconditional abort must be gone
! grep -Fq 'No `.wp-create.json` found. Run `/wp-create` first' "$f" \
  || fail "$f still aborts unconditionally on a missing .wp-create.json"

# README footnote must match the behavior
grep -Eq 'fall back to a bare .?wp' README.md || fail "README still tells the reader /wp-seed needs .wp-create.json"

echo PASS
