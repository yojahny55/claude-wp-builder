#!/usr/bin/env bash
# PERF-058 reports a theme that serves its own JavaScript unminified, and the fix swaps the
# URL in one `script_loader_src` filter rather than editing every wp_enqueue_script() call.
#
# Three things in the contract are load-bearing, and each one is a defect if it goes:
#   1. the criterion exempts a bundled theme. A `@wordpress/scripts` or vite build already
#      minifies, so reporting it is a false finding on every theme this plugin generates;
#   2. the filter tests that the twin exists before swapping. Without that test a checkout
#      where the build has never run 404s every script in the theme;
#   3. the fix tells the project that editing a source file changes nothing once the twin
#      exists. That failure is silent — the page loads, the console is clean, the old
#      behaviour persists, and reading the source confirms a change that is not live.
set -uo pipefail
cd "$(dirname "$0")/../.." || { echo "FAIL: cannot cd to the repository root"; exit 1; }

audit=agents/wp-audit-performance.md
[ -f "$audit" ] || { echo "FAIL: $audit is missing"; exit 1; }
flat=$(tr '\n' ' ' < "$audit" | sed 's/  */ /g')

# 1. The criterion, and the exemption that keeps it off generated themes.
grep -Fq 'PERF-058' "$audit" \
  || { echo "FAIL: $audit has no PERF-058 row for unminified theme JavaScript"; exit 1; }
printf '%s' "$flat" | grep -Fq 'is NOT a finding' \
  || { echo "FAIL: PERF-058 does not exempt a bundled theme — a build that already minifies would be reported on every theme this plugin generates"; exit 1; }
# Both twin shapes. Checking only one of them reports a theme that already has the fix.
printf '%s' "$flat" | grep -Fq '.min.js' \
  || { echo "FAIL: PERF-058 does not check for a sibling <name>.min.js twin"; exit 1; }
printf '%s' "$flat" | grep -Fq 'assets/js/min/' \
  || { echo "FAIL: PERF-058 does not check for an assets/js/min/ twin"; exit 1; }

# 2. The fix: one filter, and the existence test inside it.
grep -Fq 'Unminified theme JavaScript fix' "$audit" \
  || { echo "FAIL: $audit has no fix section for PERF-058, so the finding has no remedy"; exit 1; }
grep -Fq "add_filter( 'script_loader_src'" "$audit" \
  || { echo "FAIL: the PERF-058 fix does not swap the URL through script_loader_src"; exit 1; }
grep -Fq 'file_exists( get_template_directory()' "$audit" \
  || { echo "FAIL: the PERF-058 fix swaps the URL with no on-disk test — a checkout where the build never ran would 404 every theme script"; exit 1; }
# `\*? ?` absorbs the docblock's leading asterisk, which flattening leaves behind when the
# sentence wraps inside the code fence.
printf '%s' "$flat" | grep -Eq 'serves the \*? ?original unchanged' \
  || { echo "FAIL: the PERF-058 fix does not state that a missing twin falls back to the source"; exit 1; }
# The obvious wrong fix is named, so it is not re-proposed as an improvement.
printf '%s' "$flat" | grep -Fq 'the obvious fix and the wrong one' \
  || { echo "FAIL: the PERF-058 fix does not say why rewriting every wp_enqueue_script() call is rejected"; exit 1; }

# 3. The trap. A silent failure that reads as a working change is the one thing an auditor
# must hand to the project rather than keep.
printf '%s' "$flat" | grep -Fq 'editing a file under' \
  || { echo "FAIL: the PERF-058 fix does not warn that editing a source file has no effect once the twin exists"; exit 1; }
printf '%s' "$flat" | grep -Fq 'version constant' \
  || { echo "FAIL: the PERF-058 fix does not require the theme version constant to be bumped, so the rebuilt file is served from cache"; exit 1; }
printf '%s' "$flat" | grep -Fq ".claude/CLAUDE.md" \
  || { echo "FAIL: the PERF-058 fix does not record the trap in the project's own CLAUDE.md, where the next session will read it"; exit 1; }

echo "PASS: PERF-058 reports unminified theme JavaScript and its fix carries the filter, the fallback and the trap"
