#!/usr/bin/env bash
set -euo pipefail

# Media integrity: attachments whose file is missing on disk (agents/wp-audit-practices.md
# WP-060/061/062), stacked on the site-type/local-clone contract (/wp-audit Step 2.3).
#
# Defects this contract prevents:
#   1. No check at all — a broken <img> or a 404 download ships silently, because there is
#      no core notice for a thumbnail, or a purchased download, that simply is not there.
#   2. A check that does not read Step 2.3 — reporting a WARNING for media that only looks
#      missing because a local clone's file archive predates its database dump audits the
#      copy, not the site (a false positive); reporting NOTHING for a real gap that predates
#      the archive too misses a defect the clone does not excuse (a false negative). Step
#      2.3 already carries this exact case in its clone-artifact catalog, so the check must
#      reference it rather than re-implement clone detection.
#   3. A per-attachment query pattern (get_col() for IDs, then get_post_meta()/
#      get_post_field() per ID) that is 2N extra queries on a site with tens of thousands of
#      attachments, for a report that is read-only.
#   4. A failed query that reads back as "0 attachments checked" instead of an error — silent
#      on both STDOUT and the exit code.
#   5. A bare "Y-m-d" archive-date argument, which parses to midnight: an attachment uploaded
#      later that SAME calendar day compares as "after archive" no matter what time the
#      archive was actually taken, silently suppressing a real pre-archive loss as N/A (local
#      clone). Every bucket name a grep could check for is present and correctly spelled in
#      this exact failure mode — only the runtime comparison for a same-day timestamp is
#      wrong, which is why the date-cutoff behavior is asserted with real PHP execution below
#      rather than another grep.
#
# Both directions are asserted throughout: the new codes/behavior are present, and the old
# anti-patterns (per-ID queries, a suppressed same-day miss) are gone, so this stays honest
# instead of becoming a blanket excuse or a check that would pass on the broken version too.

fail() { echo "FAIL: $1"; exit 1; }

cd "$(dirname "$0")/../.." || fail "cannot cd to the repository root"

practices=agents/wp-audit-practices.md
audit=commands/wp-audit.md
script=skills/wp-cli-patterns/scripts/find-missing-media-files.php
behavior=tests/checks/lib/media-integrity-date-cutoff-behavior.php

for f in "$practices" "$audit" "$script" "$behavior"; do
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

# --- Batched attachment walk, not a per-ID query pattern (round-1 fix) ---
# The literal call, not just the name: WHY-BATCHED prose above mentions
# "BATCH_SIZE" and "update_meta_cache()" too, and a grep for the bare word would
# still pass with the call itself deleted and only the comment left behind.
grep -Fq "update_meta_cache( 'post'," "$script" \
  || fail "$script does not prime the meta cache per batch with update_meta_cache( 'post', ... )"
grep -Fq 'const BATCH_SIZE' "$script" \
  || fail "$script does not declare a bounded BATCH_SIZE"
# The old pattern this replaced: every ID with get_col(), then a per-attachment
# get_post_field( 'post_date', $id ) lookup. Its return would silently reappear as a
# regression that no positive check above would catch, since BATCH_SIZE/update_meta_cache
# could coexist with it left in by accident.
if grep -Fq '$wpdb->get_col(' "$script"; then
  fail "$script reintroduced the un-batched \$wpdb->get_col() ID list"
fi
if grep -Fq "get_post_field( 'post_date'" "$script"; then
  fail "$script reintroduced the per-attachment get_post_field( 'post_date' ) lookup"
fi

# --- A failed query is a failure, not "0 attachments checked" (round-1 fix) ---
# Each of the two queries (the attachment ID+date pull, the meta-cache prime) gets its own
# last_error check, STDERR message and exit( 2 ) — pinned by the literal message text, which
# exists nowhere but the real fwrite() calls, rather than a bare count of "last_error"/
# "STDERR" occurrences that a docblock mentioning them in prose could also satisfy.
grep -Fq 'find-missing-media-files.php: attachment query failed' "$script" \
  || fail "$script does not report a failed attachment query to STDERR"
grep -Fq 'find-missing-media-files.php: meta cache query failed' "$script" \
  || fail "$script does not report a failed meta-cache query to STDERR"
# The other "cannot measure" modes are pinned the same way, one literal message each, so
# dropping any one guard fails here even if an unrelated exit( 2 ) is added elsewhere.
grep -Fq 'is not a Y-m-d or Y-m-d H:i:s date' "$script" \
  || fail "$script does not reject an archive-date argument it cannot read"
grep -Fq 'is not a non-negative integer' "$script" \
  || fail "$script does not reject a negative or non-numeric sample-size"
grep -Fq 'find-missing-media-files.php: uploads directory unavailable' "$script" \
  || fail "$script does not stop when wp_get_upload_dir() has no usable basedir"

# --- Local-clone suppression rule: references Step 2.3, does not re-implement clone detection ---
grep -Fq 'Step 2.3' "$practices" \
  || fail "$practices does not reference /wp-audit Step 2.3 for local-clone status"
[[ "$flat" == *"does not detect clones itself"* ]] \
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
# Both range anchors are asserted on their own first: with the end anchor gone, sed would
# print from the start anchor to EOF and the match below could land far outside the bullet.
grep -Fq '**Local clone, archive date known**' "$practices" \
  || fail "$practices lost the 'Local clone, archive date known' bullet the section extraction starts at"
grep -Fq '**Local clone, archive date unknown**' "$practices" \
  || fail "$practices lost the 'Local clone, archive date unknown' bullet the section extraction ends at"
clone_known_date_section=$(sed -n '/\*\*Local clone, archive date known\*\*/,/\*\*Local clone, archive date unknown\*\*/p' "$practices" \
  | tr '\n' ' ' | sed 's/  */ /g')
[ -n "$clone_known_date_section" ] \
  || fail "$practices lost the 'Local clone, archive date known' paragraph"
# Piping into `grep -q` under `pipefail` risks a false FAIL: grep can exit as soon as it
# finds a match, and if the writer on the other end of the pipe is still flushing output
# when that happens it can be killed by SIGPIPE, which pipefail then reports as the
# pipeline's exit status even though the match was found. Bash's own =~ operator tests the
# string in-process, with no pipe and nothing to race.
clone_known_date_pattern='BEFORE-ARCHIVE.*(no such excuse|WARNING)'
[[ "$clone_known_date_section" =~ $clone_known_date_pattern ]] \
  || fail "$practices does not still report a pre-archive miss as WARNING — the clone must not become a blanket excuse"

grep -Fq 'run the script with no archive-date argument' "$practices" \
  || fail "$practices does not report every miss WARNING on a site that is not a local clone"

# --- Same-day archive-date ambiguity is documented (round-2 fix) ---
grep -Fq 'Y-m-d H:i:s' "$practices" \
  || fail "$practices does not document passing a full Y-m-d H:i:s timestamp for a precise cutoff"
grep -Fqi 'midnight' "$practices" \
  || fail "$practices does not explain why a bare date is ambiguous (midnight cutoff)"
grep -Fq 'Y-m-d H:i:s' "$script" \
  || fail "$script's own usage doc does not mention the Y-m-d H:i:s timestamp form"
grep -Fq 'mmf_compute_archive_cutoff' "$script" \
  || fail "$script does not isolate the archive-cutoff computation into its own function"
grep -Fq 'mmf_bucket_for' "$script" \
  || fail "$script does not isolate the bucket decision into its own function"

# --- commands/wp-audit.md already carries the matching row in its Step 2.3 catalog ---
grep -Fq 'predates the database' "$audit" \
  || fail "$audit Step 2.3 lost the media-archive-date row this check depends on"
grep -Fq 'see WP-060/061/062 in `agents/wp-audit-practices.md`' "$audit" \
  || fail "$audit Step 2.3 does not point at WP-060/061/062 in the practices agent for this row"

# --- Behavioral check: the real cutoff/bucket functions, not a grep of their names ---
# A same-day upload against a bare-date archive argument must not land in AFTER-ARCHIVE
# (the suppressed bucket) — no grep above can tell a correct comparison from an inverted
# or off-by-one one, since every string it could match is present either way.
if ! command -v php >/dev/null 2>&1; then
  echo "SKIP: php not found — the greps above passed, the date-cutoff behavior test did not run"
else
  if ! behavior_out=$(php "$behavior" 2>&1); then
    fail "the archive-date cutoff/bucket behavior is wrong: ${behavior_out:-(php exited non-zero with no output)}"
  fi
fi

echo PASS
