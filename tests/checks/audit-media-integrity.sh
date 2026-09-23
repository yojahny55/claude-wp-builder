#!/usr/bin/env bash
set -uo pipefail

# Media integrity: attachments whose file is missing on disk (agents/wp-audit-practices.md
# WP-060/061/062), stacked on the site-type/local-clone contract (/wp-audit Step 2.3).
#
# Two defects this contract prevents:
#   1. No check at all — a broken <img> or a 404 download ships silently, because there is
#      no core notice for a thumbnail, or a purchased download, that simply is not there.
#   2. A check that does not read Step 2.3 — reporting a WARNING for media that only looks
#      missing because a local clone's file archive predates its database dump audits the
#      copy, not the site (a false positive); reporting NOTHING for a real gap that predates
#      the archive too misses a defect the clone does not excuse (a false negative). Step
#      2.3 already carries this exact case in its clone-artifact catalog, so the check must
#      reference it rather than re-implement clone detection.
#
# Both directions are asserted below: the new codes are present, and the clone-suppression
# rule — N/A only when the miss postdates the archive, WARNING/UNMEASURED otherwise — is
# present too, so this stays honest instead of becoming a blanket excuse.

fail() { echo "FAIL: $1"; exit 1; }

cd "$(dirname "$0")/../.." || fail "cannot cd to the repository root"

practices=agents/wp-audit-practices.md
audit=commands/wp-audit.md
script=skills/wp-cli-patterns/scripts/find-missing-media-files.php

for f in "$practices" "$audit" "$script"; do
  [ -s "$f" ] || fail "$f is missing or empty"
done

# Flattened so a wrapped line does not break a literal multi-word match.
flat=$(tr '\n' ' ' < "$practices" | sed 's/  */ /g')

# --- New codes present, in the reserved WP-060..062 range ---
for code in WP-060 WP-061 WP-062; do
  grep -Fq "$code" "$practices" || fail "$practices lost $code"
done

# --- The check is Tier 2 / WP-CLI, not a code-only Tier 1 grep ---
grep -Fq 'Tier 2' "$practices" || fail "$practices does not place WP-060/061/062 in Tier 2"
grep -Fq 'find-missing-media-files.php' "$practices" \
  || fail "$practices does not point at the WP-CLI script that resolves attachment files"

# --- Detection covers the main file, its registered sub-sizes, and original_image ---
grep -Fq '_wp_attached_file' "$practices" \
  || fail "$practices does not resolve the attachment's main file (_wp_attached_file)"
grep -Fq '_wp_attachment_metadata' "$practices" \
  || fail "$practices does not read _wp_attachment_metadata for sub-sizes/original_image"
grep -Fq "wp_get_upload_dir()['basedir']" "$practices" \
  || fail "$practices does not resolve files against wp_get_upload_dir()['basedir']"

# --- Severity is WARNING, and counting + sampling is required (never dump the whole list) ---
grep -Fq '| WARNING |' "$practices" || fail "$practices table has no WARNING severity row for these codes"
grep -Fq 'sample' "$practices" || fail "$practices does not require sampling, not dumping, the missing set"

# --- The script itself: enumerates attachments, buckets by archive date, never guesses one ---
grep -Fq "wp_get_upload_dir" "$script" || fail "$script does not resolve paths via wp_get_upload_dir()"
grep -Fq "'sizes'" "$script" || fail "$script does not walk registered image sub-sizes"
grep -Fq "original_image" "$script" || fail "$script does not check original_image"
for bucket in BEFORE-ARCHIVE AFTER-ARCHIVE UNDATED; do
  grep -Fq "$bucket" "$script" || fail "$script lost the $bucket bucket"
done

# --- Local-clone suppression rule: references Step 2.3, does not re-implement clone detection ---
grep -Fq 'Step 2.3' "$practices" \
  || fail "$practices does not reference /wp-audit Step 2.3 for local-clone status"
printf '%s' "$flat" | grep -Fq 'does not detect clones itself' \
  || fail "$practices does not disclaim re-implementing clone detection"
grep -Fq 'local_clone' "$practices" \
  || fail "$practices does not read the local_clone flag from Step 2.3"

# --- Both directions of the suppression: N/A only after the archive date, WARNING/UNMEASURED otherwise ---
grep -Fq 'N/A (local clone)' "$practices" \
  || fail "$practices does not suppress AFTER-ARCHIVE misses as N/A (local clone)"
grep -Fq 'UNMEASURED' "$practices" \
  || fail "$practices does not fall back to UNMEASURED when the archive date is unknown"

# The "no such excuse" reasoning is its own paragraph, wrapped across several
# lines, so a line-scoped grep on the whole file would never see BEFORE-ARCHIVE
# and the reasoning together — it would instead pass by coincidence, off the
# WP-060/061/062 table row or the Procedure section's summary line, which both
# happen to hold "BEFORE-ARCHIVE" and "WARNING" on one line regardless of
# whether this specific paragraph still makes the case. Extract just that
# paragraph and flatten it before matching, so the assertion tracks the prose
# it names, not any other line in the file. The range end is the heading of
# the *next* bullet, not any wording from inside this one — an end anchor
# built out of the very phrase under test would stop bounding the section the
# moment that phrase changed, silently falling back to "match anywhere in the
# file" and reintroducing the bug this extraction exists to avoid.
clone_known_date_section=$(sed -n '/\*\*Local clone, archive date known\*\*/,/\*\*Local clone, archive date unknown\*\*/p' "$practices" \
  | tr '\n' ' ' | sed 's/  */ /g')
[ -n "$clone_known_date_section" ] \
  || fail "$practices lost the 'Local clone, archive date known' paragraph"
printf '%s' "$clone_known_date_section" | grep -Eq 'BEFORE-ARCHIVE.*(no such excuse|WARNING)' \
  || fail "$practices does not still report a pre-archive miss as WARNING — the clone must not become a blanket excuse"

grep -Fq 'run the script with no archive-date argument' "$practices" \
  || fail "$practices does not report every miss WARNING on a site that is not a local clone"

# --- commands/wp-audit.md already carries the matching row in its Step 2.3 catalog ---
grep -Fq 'predates the database' "$audit" \
  || fail "$audit Step 2.3 lost the media-archive-date row this check depends on"
grep -Fq 'media-integrity check' "$audit" \
  || fail "$audit Step 2.3 does not point at the media-integrity check for this row"

echo PASS
