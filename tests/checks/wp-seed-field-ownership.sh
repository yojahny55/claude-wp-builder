#!/usr/bin/env bash
# Phase 1.5 (added earlier) answers who owns a RECORD. It does not answer who owns a VALUE,
# and those are different questions: a page the seeder created is one it may update, but a
# heading inside that page retyped by the client in wp-admin is theirs. update_field()
# overwrites unconditionally, so re-seeding a record the seeder legitimately owns silently
# reverted every edit made to it since the last run -- and the record-level rule read as if
# that were already handled.
#
# Telling an editor's edit from a source change needs one fact that is not in the database:
# what this command wrote last time. This pins that fact, the compare built on it, and the
# two defaults that make the compare worth having.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

f=commands/wp-seed.md
[ -f "$f" ] || fail "$f is missing"
need() { grep -Fq -- "$1" "$f" || fail "$f $2"; }

need 'whose value is in it?' 'has no field-level ownership rule'
need 'what this command wrote last time' \
  'does not identify the missing fact -- without it an editor edit and a source change are indistinguishable'
need '_<prefix>_seeded_digest' 'does not record what was written last run'

# A digest, not a copy. The distinction is the reason the record is cheap enough to keep.
need 'A digest, not the value' 'does not say why a hash rather than the value is stored'

# The compare, and the two rows that decide whether client work survives.
need 'The three-way compare' 'has no three-way compare'
need 'leave the value, report it' 'overwrites a field the client edited'
need 'treat as a **conflict**; do not overwrite' \
  'overwrites a field with no recorded digest -- on a project seeded before this existed, that is every field'
# Needles are kept within one line: the prose wraps and grep -F matches within a line.
need 'the first re-seed of an older project noisy' \
  'does not justify treating unknown provenance as a conflict'

# No automatic merge. Both values are deliberate; picking either silently discards work.
need 'never merged' 'allows an automatic resolution between the demo and the client'
need 'both deliberate' 'does not say why a conflict has no safe automatic resolution'

# The override exists, is explicit, and is not reachable by accident from another flag.
need '--force-fields' 'has no explicit way to overwrite conflicts'
need 'not implied by `--force`' \
  'lets --force on another command overwrite editor values -- the override must be its own decision'
need 'never the default' 'does not state that overwriting editor values is opt-in'
grep -Fq -- '--force-fields' <(sed -n '1,8p' "$f") \
  || fail "$f does not document --force-fields in its argument-hint, so it cannot be discovered"

# Writing the value and its digest together. A value written without one is reported as a
# client edit forever after.
need 'same step that writes the value' 'does not tie the digest write to the value write'
need 'will be reported as a conflict' \
  'does not say what a missing digest costs on the next run'

# Field counts in the preview, separate from record counts, because ownership is separate.
need 'update 3, skip 18, conflict 2' 'the preview does not report field-level outcomes'
need 'counted separately because they are owned separately' \
  'does not explain why records and fields are counted apart'

# The ceiling, stated where someone would otherwise read the compare as exact.
need 'reads as no edit' 'does not state the case the digest cannot distinguish'

echo "PASS: field values have owners, unknown provenance is a conflict, and overwriting is opt-in"
