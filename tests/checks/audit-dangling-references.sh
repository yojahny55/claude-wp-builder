#!/usr/bin/env bash
# Two defects that render a clean page and a dead feature, and that no existing criterion could
# see:
#   WP-051 — the theme sends an action name admin-ajax.php has no hook for. The endpoint answers
#     400 with `0`, the page renders, the console shows one failed request, and the feature is
#     simply gone. On one audited theme all four filter UIs had been dead this way, because the
#     localized names carried the theme prefix that the add_action() calls did not.
#   WP-052 — a section is printed for a plugin record that no longer exists. WP-048 resolves IDs
#     that point at POSTS; these point into a plugin's own table, so get_post() sees nothing and
#     the orphan sweep cannot reach them.
#
# What must not rot, in both cases, is the part that makes the finding actionable rather than a
# guess: WP-051 is confirmed against the real endpoint before it is reported, and both fixes name
# the wrong remedy so it is not proposed as an improvement later.
set -uo pipefail
cd "$(dirname "$0")/../.." || { echo "FAIL: cannot cd to the repository root"; exit 1; }

audit=agents/wp-audit-practices.md
[ -f "$audit" ] || { echo "FAIL: $audit is missing"; exit 1; }
flat=$(tr '\n' ' ' < "$audit" | sed 's/  */ /g')

# --- WP-051 ---------------------------------------------------------------------------------
grep -Fq 'WP-051' "$audit" \
  || { echo "FAIL: $audit has no WP-051 row for an unregistered admin-ajax action name"; exit 1; }
grep -Fq 'Procedure — WP-051' "$audit" \
  || { echo "FAIL: $audit has no WP-051 procedure"; exit 1; }
# BOTH sides, because a grep over one of them can never see a mismatch.
printf '%s' "$flat" | grep -Fq 'wp_ajax_nopriv_' \
  || { echo "FAIL: WP-051 does not collect the registered wp_ajax_nopriv_ actions"; exit 1; }
printf '%s' "$flat" | grep -Fq 'wp_localize_script()' \
  || { echo "FAIL: WP-051 does not collect the action names the theme sends through wp_localize_script()"; exit 1; }
# The runtime confirmation. This one is cheap to measure, so reporting it unmeasured is a choice.
grep -Fq 'admin-ajax.php" -d "action=' "$audit" \
  || { echo "FAIL: WP-051 does not confirm the mismatch against the real endpoint before reporting it"; exit 1; }
printf '%s' "$flat" | grep -Fq '400' \
  || { echo "FAIL: WP-051 does not state what an unregistered action answers, so nothing tells a reader the request failed at all"; exit 1; }
# A dead filter is broken functionality, not a style finding.
printf '%s' "$flat" | grep -Fq 'Report it CRITICAL' \
  || { echo "FAIL: WP-051 does not set the severity to CRITICAL — a pagination answering 400 is not an advisory"; exit 1; }
# The wrong fix, named. Renaming the hook to match the message changes a public contract.
printf '%s' "$flat" | grep -Fq 'never by renaming the hook' \
  || { echo "FAIL: WP-051 does not reject renaming the hook to match the message"; exit 1; }
# The two neighbours whose fix is in the same file.
printf '%s' "$flat" | grep -Fq 'check_ajax_referer()' \
  || { echo "FAIL: WP-051 does not fold in the nonce that no localized value feeds"; exit 1; }

# --- WP-052 ---------------------------------------------------------------------------------
grep -Fq 'WP-052' "$audit" \
  || { echo "FAIL: $audit has no WP-052 row for a section printed for a deleted record"; exit 1; }
grep -Fq 'Procedure — WP-052' "$audit" \
  || { echo "FAIL: $audit has no WP-052 procedure"; exit 1; }
# The reason this is not WP-048: the rows are not posts.
printf '%s' "$flat" | grep -Fq "plugin's own table" \
  || { echo "FAIL: WP-052 does not say the record lives in the plugin's own table, which is why the WP-048 sweep cannot see it"; exit 1; }
printf '%s' "$flat" | grep -Fq 'get_post()' \
  || { echo "FAIL: WP-052 does not state that get_post() cannot resolve these IDs"; exit 1; }
# What the visitor actually gets, so the finding is not filed as cosmetic.
printf '%s' "$flat" | grep -Eq 'printed as literal text|empty band' \
  || { echo "FAIL: WP-052 does not describe what renders when the record is gone"; exit 1; }
# The fix guards the whole section, and the wrong remedy is named.
printf '%s' "$flat" | grep -Fq 'Never hide the empty section with CSS' \
  || { echo "FAIL: WP-052 does not reject hiding the empty section with CSS, which leaves the data broken and a gap in the layout"; exit 1; }
printf '%s' "$flat" | grep -Fq 'heading, padding and background' \
  || { echo "FAIL: WP-052's fix does not skip the whole section — a guard around the shortcode alone still ships an empty band"; exit 1; }

echo "PASS: WP-051 and WP-052 are defined, measured and fixed without the two wrong remedies"
