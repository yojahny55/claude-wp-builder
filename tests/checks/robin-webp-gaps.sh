#!/usr/bin/env bash
# Two wp-robin gaps that cost several rounds on a real site.
#
# 1. The webp sync step selected only attachments with no webp rows at all. A size added
#    later (a new add_image_size() plus `wp media regenerate`) lives on an attachment that
#    already has rows, so it was never converted. The step must compare each attachment's
#    files against its webp rows, and skip the entries the attachment already owns rather
#    than re-inserting them under the collision hash.
#
# 2. With uploads owned by the web server user, every conversion failed one by one and the
#    run printed hundreds of "conversion failed" lines. The script must check writability
#    first and say why — and the skill must document both that and the missing queue table
#    a WP-CLI activation can leave behind.
set -uo pipefail
cd "$(dirname "$0")/../.."

script=skills/wp-robin/scripts/robin-fix.sh
skill=skills/wp-robin/SKILL.md
[ -f "$script" ] || { echo "FAIL: $script is missing"; exit 1; }

grep -q "rio.item_type = 'webp' AND rio.object_id IS NOT NULL" "$script" \
  && { echo "FAIL: $script still selects only attachments with no webp rows at all — later sizes are never converted"; exit 1; }
grep -Fq 'count($files) > (int) ($p[2] ?? 0)' "$script" \
  || { echo "FAIL: $script does not compare an attachment's files on disk against its webp row count"; exit 1; }
grep -Fq "w.item_type = 'webp' AND w.object_id = p.ID" "$script" \
  || { echo "FAIL: $script does not count webp rows per attachment"; exit 1; }
grep -Fq 'grep -qxF -e "$ITEM_HASH" -e "$SUFFIX_HASH"' "$script" \
  || { echo "FAIL: $script does not skip webp entries the attachment already owns — a revisit would duplicate them"; exit 1; }
grep -q 'REMAIN=$(list_webp_gaps' "$script" \
  || { echo "FAIL: $script's final report does not use the same gap rule as the sync step"; exit 1; }

grep -q '! -w "\$UPLOAD_DIR"' "$script" \
  || { echo "FAIL: $script does not check that uploads is writable before converting"; exit 1; }
grep -q 'is not writable by \$(id -un)' "$script" \
  || { echo "FAIL: $script does not name the user that cannot write"; exit 1; }

grep -q 'Hundreds of "conversion failed" lines' "$skill" \
  || { echo "FAIL: $skill has no troubleshooting row for an unwritable uploads directory"; exit 1; }
grep -q 'wp_rio_process_queue does not exist" while the plugin is active' "$skill" \
  || { echo "FAIL: $skill has no troubleshooting row for the queue table a WP-CLI activation leaves missing"; exit 1; }

# 3. The skill documents what the script writes and how to run it. Its settings table once
#    listed 7 of the 16 settings the script overwrites, so an operator could not see that a
#    run resets webp_delivery_mode or the schedule; nothing tied the two together.
keys=$(grep -oE '^\s*\[[a-z_]+\]=|SETTINGS\[[a-z_]+\]=' "$script" | sed -E 's/^[^[]*\[([a-z_]+)\]=$/\1/')
[ -n "$keys" ] || { echo "FAIL: no SETTINGS keys found in $script — this assertion is matching nothing"; exit 1; }
for k in $keys; do
  grep -Fq "| \`$k\` |" "$skill" || { echo "FAIL: $skill's settings table does not list $k, which $script writes on every run"; exit 1; }
done
for bin in convert cwebp gif2webp curl unzip sha256sum; do
  grep -Eq "^[^#]*(^|[^a-z_])$bin([^a-z_]|$)" "$script" || continue
  awk '/^## Requirements/{f=1;next} /^## /{f=0} f' "$skill" | grep -Fq "$bin" \
    || { echo "FAIL: $script calls $bin, which $skill's Requirements does not list"; exit 1; }
done
grep -Fq '"${CLAUDE_PLUGIN_ROOT}/skills/wp-robin/scripts/robin-fix.sh"' "$skill" \
  || { echo "FAIL: $skill does not run the script by its \${CLAUDE_PLUGIN_ROOT} path"; exit 1; }
! grep -Fq '<path-to-skill>' "$skill" || { echo "FAIL: $skill still uses a <path-to-skill> placeholder"; exit 1; }
grep -Fq 'wp db export' "$skill" || { echo "FAIL: $skill does not back up the database before a run that overwrites settings"; exit 1; }
grep -Fq 'Done when `error`, `processing` and `remaining` are all 0' "$skill" \
  || { echo "FAIL: $skill does not say when the work is done"; exit 1; }

echo "PASS"
