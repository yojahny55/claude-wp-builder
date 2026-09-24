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
skill=skills/wp-cli-patterns/SKILL.md

for f in "$practices" "$audit" "$script" "$behavior" "$skill"; do
  [ -s "$f" ] || fail "$f is missing or empty"
done

# Flattened so a wrapped line does not break a literal multi-word match.
flat=$(tr '\n' ' ' < "$practices" | sed 's/  */ /g')

# --- New codes present, in the reserved WP-060..062 range ---
for code in WP-060 WP-061 WP-062; do
  grep -Fq "$code" "$practices" || fail "$practices lost $code"
done

# --- The check is Tier 2 / WP-CLI, not a code-only Tier 1 grep: each row sits between the
#     Tier 2 heading and the next `## ` heading, and its last cell is WARNING ---
tier2=$(awk '/^## Step 2: Tier 2/{f=1; next} f && /^## /{exit} f' "$practices")
[ -n "$tier2" ] || fail "$practices lost its '## Step 2: Tier 2' section"
for code in WP-060 WP-061 WP-062; do
  # A here-string, not a pipe: awk exits on the first match, and a pipe writer still
  # flushing a large section would die of SIGPIPE, which pipefail turns into an abort.
  sev=$(awk -F'|' -v code="$code" '/^\|/ { c = $2; gsub(/^[ \t]+|[ \t]+$/, "", c)
          if (c == code) { s = $(NF - 1); gsub(/^[ \t]+|[ \t]+$/, "", s); print s; exit } }' <<< "$tier2")
  [ -n "$sev" ] || fail "$practices has no $code row in the Tier 2 table"
  [ "$sev" = WARNING ] || fail "$practices: $code is $sev in the Tier 2 table, expected WARNING"
done
grep -Fq 'find-missing-media-files.php' "$practices" \
  || fail "$practices does not point at the WP-CLI script that resolves attachment files"
grep -Fq '### `find-missing-media-files.php`' "$skill" \
  || fail "$skill's Shipped Scripts index does not document find-missing-media-files.php"

# --- Detection covers the main file, its registered sub-sizes, and original_image ---
grep -Fq '_wp_attached_file' "$practices" \
  || fail "$practices does not resolve the attachment's main file (_wp_attached_file)"
grep -Fq '_wp_attachment_metadata' "$practices" \
  || fail "$practices does not read _wp_attachment_metadata for sub-sizes/original_image"
grep -Fq "wp_get_upload_dir()['basedir']" "$practices" \
  || fail "$practices does not resolve files against wp_get_upload_dir()['basedir']"

# --- Counting + sampling is required (never dump the whole list); severity is pinned above ---
grep -Fq 'prints a sample, never the whole list' <<< "$flat" \
  || fail "$practices does not require sampling, not dumping, the missing set"
grep -Fq 'array_slice( $items, 0, $sample_size )' "$script" \
  || fail "$script prints the whole missing set instead of a sample-size-capped sample"

# --- The script itself: enumerates attachments, buckets by archive date, never guesses one ---
grep -Fq "wp_get_upload_dir" "$script" || fail "$script does not resolve paths via wp_get_upload_dir()"
grep -Fq "'sizes'" "$script" || fail "$script does not walk registered image sub-sizes"
grep -Fq "original_image" "$script" || fail "$script does not check original_image"
# Sub-sizes and original_image are bare filenames; without the attachment's own YYYY/MM
# directory every one of them reads as missing (a wall of false WP-061/WP-062 misses).
grep -Eq '\$rel_dir[[:space:]]+=[[:space:]]+dirname\([[:space:]]*\$attached_file[[:space:]]*\)' "$script" \
  || fail "$script does not take the attachment's own subdirectory from _wp_attached_file"
grep -Fq "\$rel_dir . '/' . \$size_info['file']" "$script" \
  || fail "$script does not resolve sub-sizes against the attachment's own subdirectory"
grep -Fq "\$rel_dir . '/' . \$meta['original_image']" "$script" \
  || fail "$script does not resolve original_image against the attachment's own subdirectory"
for bucket in BEFORE-ARCHIVE AFTER-ARCHIVE UNDATED; do
  grep -Fq "$bucket" "$script" || fail "$script lost the $bucket bucket"
done

# --- Batched attachment walk, not a per-ID query pattern (round-1 fix) ---
# The literal call, not just the name: WHY-BATCHED prose above mentions
# "BATCH_SIZE" and "update_meta_cache()" too, and a grep for the bare word would
# still pass with the call itself deleted and only the comment left behind.
grep -Fq "update_meta_cache( 'post'," "$script" \
  || fail "$script does not prime the meta cache per batch with update_meta_cache( 'post', ... )"
# The walk must advance: the keyset predicate and the cursor moved past each batch. Without
# either, every iteration re-reads the same rows and the audit hangs instead of reporting.
grep -Fq 'AND ID > %d' "$script" \
  || fail "$script's batch query lost its ID > %d keyset predicate"
grep -Eq '\$last_id[[:space:]]*=[[:space:]]*\(int\)[[:space:]]*end\([[:space:]]*\$batch_ids[[:space:]]*\)' "$script" \
  || fail "$script does not advance the keyset cursor past the batch it just read — the walk would never terminate"
# Only a sample of each bucket is held in memory; the totals come from separate counters.
grep -Fq '$bucket_counts[ $bucket ]++;' "$script" \
  || fail "$script does not count every miss separately from the sample it keeps"
grep -Fq 'if ( count( $buckets[ $bucket ] ) < $sample_size ) {' "$script" \
  || fail "$script keeps every miss record in memory instead of at most sample-size per bucket"
# A positive value: BATCH_SIZE = 0 would make the first query LIMIT 0, and the script would
# report "0 attachments checked" with exit 0 — defect #4 again.
grep -Eq 'const BATCH_SIZE = [1-9][0-9]{0,4};' "$script" \
  || fail "$script does not declare a positive, bounded BATCH_SIZE"
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
# The other "cannot measure" modes are pinned the same way, one literal message each, and
# every pinned message must be followed by an exit( 2 ) before the next statement block: a
# message with no exit after it is defect #4 back again — the script would fall through and
# print "0 attachments checked" with exit 0.
# The success/failure exit code is the contract a caller keys off: a script that always exits
# 0 would report a site with real BEFORE-ARCHIVE or UNDATED losses as clean.
grep -Fq "exit( ( \$bucket_counts['BEFORE-ARCHIVE'] > 0 || \$bucket_counts['UNDATED'] > 0 ) ? 1 : 0 );" "$script" \
  || fail "$script no longer exits 1 on BEFORE-ARCHIVE/UNDATED misses"
for msg in 'attachment query failed' 'meta cache query failed' 'uploads directory unavailable' \
           'is not a Y-m-d or Y-m-d H:i:s date' 'is not a non-negative integer'; do
  grep -Fq "$msg" "$script" || fail "$script no longer reports '$msg' to STDERR"
  awk -v msg="$msg" 'index($0, msg) { want = 1; n = 0; next }
      want && /exit[[:space:]]*\([[:space:]]*2[[:space:]]*\)/ { ok = 1; exit }
      want && ++n > 2 { exit }
      END { exit(ok ? 0 : 1) }' "$script" \
    || fail "$script reports '$msg' but no exit( 2 ) follows it — the failure would read as '0 attachments checked'"
done

# --- Local-clone suppression rule: references Step 2.3, does not re-implement clone detection ---
grep -Fq 'Step 2.3' "$practices" \
  || fail "$practices does not reference /wp-audit Step 2.3 for local-clone status"
[[ "$flat" == *"does not detect clones itself"* ]] \
  || fail "$practices does not disclaim re-implementing clone detection"
grep -Fq 'local_clone' "$practices" \
  || fail "$practices does not read the local_clone flag from Step 2.3"

# --- Both directions of the suppression: N/A only after the archive date, WARNING/UNMEASURED otherwise ---
[[ "$flat" == *'buckets `AFTER-ARCHIVE` is exactly that case'* \
   && "$flat" == *'report it `N/A (local clone)`, out of the denominator'* ]] \
  || fail "$practices does not suppress AFTER-ARCHIVE misses as N/A (local clone)"
# UNMEASURED appears for other checks too (the WP-043/044 network gate, the Rules), so it is
# matched inside the "archive date unknown" bullet only, ended by the report's fix note.
# Column 0, the shape the sed end anchor needs: an indented or bulleted line would not end the
# range, which would then run to EOF with the phrase still inside it.
grep -Eq '^Fix note for the report' "$practices" \
  || fail "$practices lost the column-0 'Fix note for the report' line the 'archive date unknown' extraction ends at"
clone_unknown_date_section=$(sed -n '/\*\*Local clone, archive date unknown\*\*/,/^Fix note for the report/p' "$practices" \
  | tr '\n' ' ' | sed 's/  */ /g')
[[ "$clone_unknown_date_section" == *'Fix note for the report'* ]] \
  || fail "$practices: the 'archive date unknown' extraction never reached its end anchor"
[[ "$clone_unknown_date_section" == *'every miss comes back `UNDATED`'* \
   && "$clone_unknown_date_section" == *'Report `UNMEASURED`'* ]] \
  || fail "$practices does not fall back to UNMEASURED for UNDATED misses when the archive date is unknown"

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
# sed only stops at an end anchor that follows the start one; reordered bullets would run the
# range to EOF, so the end anchor must be inside what was extracted.
[[ "$clone_known_date_section" == *'**Local clone, archive date unknown**'* ]] \
  || fail "$practices: the 'archive date known' extraction ran to EOF without reaching its end anchor"
# Piping into `grep -q` under `pipefail` risks a false FAIL: grep can exit as soon as it
# finds a match, and if the writer on the other end of the pipe is still flushing output
# when that happens it can be killed by SIGPIPE, which pipefail then reports as the
# pipeline's exit status even though the match was found. Bash's own =~ operator tests the
# string in-process, with no pipe and nothing to race.
# Two separate anchors: the reasoning (a pre-archive miss has no clone excuse) and the
# severity that follows from it, so losing either one fails on its own.
clone_known_date_pattern='bucketed `BEFORE-ARCHIVE` predates the archive and has no such excuse'
[[ "$clone_known_date_section" =~ $clone_known_date_pattern ]] \
  || fail "$practices no longer says a BEFORE-ARCHIVE miss has no clone excuse — the clone must not become a blanket excuse"
clone_known_date_pattern='no such excuse .* report it WARNING like any other site'
[[ "$clone_known_date_section" =~ $clone_known_date_pattern ]] \
  || fail "$practices does not still report a pre-archive miss as WARNING"

[[ "$flat" == *'run the script with no archive-date argument and report every miss WARNING'* ]] \
  || fail "$practices does not report every miss WARNING on a site that is not a local clone"

# --- Same-day archive-date ambiguity is documented (round-2 fix) ---
grep -Fq 'Y-m-d H:i:s' "$practices" \
  || fail "$practices does not document passing a full Y-m-d H:i:s timestamp for a precise cutoff"
grep -Fqi 'midnight' "$practices" \
  || fail "$practices does not explain why a bare date is ambiguous (midnight cutoff)"
grep -Fq 'Archive cutoff:' "$script" \
  || fail "$script no longer prints the effective cutoff — $practices names that line as the report's evidence of which reading applied"
grep -Fq 'Y-m-d H:i:s' "$script" \
  || fail "$script's own usage doc does not mention the Y-m-d H:i:s timestamp form"
grep -Fq 'mmf_compute_archive_cutoff' "$script" \
  || fail "$script does not isolate the archive-cutoff computation into its own function"
grep -Fq 'mmf_bucket_for' "$script" \
  || fail "$script does not isolate the bucket decision into its own function"
# The caller buckets only when a cutoff exists: mmf_bucket_for( $post_date, false ) compares
# against 0, so every dated miss would read AFTER-ARCHIVE and the clone a blanket excuse.
grep -Fq "( false === \$archive_ts ) ? 'UNDATED' : mmf_bucket_for(" "$script" \
  || fail "$script buckets misses even when no archive cutoff exists — every dated miss would read AFTER-ARCHIVE"

# --- commands/wp-audit.md already carries the matching row in its Step 2.3 catalog ---
awk '/^\|/ && /predates the database/ { found = 1 } END { exit(found ? 0 : 1) }' "$audit" \
  || fail "$audit Step 2.3 lost the media-archive-date row this check depends on"
grep -Fq 'see WP-060/061/062 in `agents/wp-audit-practices.md`' "$audit" \
  || fail "$audit Step 2.3 does not point at WP-060/061/062 in the practices agent for this row"

# --- Behavioral check: the real cutoff/bucket functions, not a grep of their names ---
# A same-day upload against a bare-date archive argument must not land in AFTER-ARCHIVE
# (the suppressed bucket) — no grep above can tell a correct comparison from an inverted
# or off-by-one one, since every string it could match is present either way.
# Required, not skipped: without php this check would shrink to doc greps and still PASS.
command -v php >/dev/null 2>&1 \
  || fail "php not found — the date-cutoff behavior test cannot run, and no grep above can replace it"
grep -Fq "'/skills/wp-cli-patterns/scripts/find-missing-media-files.php'" "$behavior" \
  || fail "$behavior no longer loads the production script — it would validate its own copy of the functions"
# TZ=UTC: the script runs under WordPress, which sets UTC; the fixture pins it too.
if ! behavior_out=$(TZ=UTC php "$behavior" 2>&1); then
  fail "the archive-date cutoff/bucket behavior is wrong: ${behavior_out:-(php exited non-zero with no output)}"
fi
# A run that asserted nothing must not pass: the fixture prints its case count on success.
[[ "$behavior_out" =~ ^OK\ [1-9][0-9]*\ cases$ ]] \
  || fail "$behavior did not report its cases as run: ${behavior_out:-(no output)}"
# The same-day cases are the defect this check exists to pin; dropping them must fail by name,
# not just shrink the case count.
for same_day in 'same-day upload, morning, bare date arg' 'same-day upload, last second, bare date arg'; do
  grep -Fq "'$same_day'" "$behavior" || fail "$behavior lost the '$same_day' case"
done

echo PASS
