#!/usr/bin/env bash
# PERF-059 reports a self-hosted family that carries scripts the site never writes. On a real
# build that was 442KB of woff2 where 263KB covers every character the site renders.
#
# The three parts that must not rot:
#   1. the criterion exempts a face carried with Google's own unicode-range blocks. /wp-init
#      Step 4.5 carries fonts that way on purpose, so reporting them would fire on every
#      theme this plugin scaffolds;
#   2. the fix keeps layout features. A subset without kerning and ligatures renders visibly
#      worse at the same glyph coverage, which is a regression wearing the shape of a saving;
#   3. the fix verifies coverage against the SITE'S OWN TEXT before replacing a file, and
#      treats a missing glyph as a refusal. A missing glyph does not error: the browser falls
#      back for that one character, so the damage is a font that is "slightly off" somewhere
#      and nobody can say why.
set -uo pipefail
cd "$(dirname "$0")/../.." || { echo "FAIL: cannot cd to the repository root"; exit 1; }

audit=agents/wp-audit-performance.md
[ -f "$audit" ] || { echo "FAIL: $audit is missing"; exit 1; }
flat=$(tr '\n' ' ' < "$audit" | sed 's/  */ /g')

# 1. The criterion and its exemption.
grep -Fq 'PERF-059' "$audit" \
  || { echo "FAIL: $audit has no PERF-059 row for an unsubsetted self-hosted font"; exit 1; }
printf '%s' "$flat" | grep -Fq 'unicode-range' \
  || { echo "FAIL: PERF-059 does not mention unicode-range, so it cannot tell a subsetted carry from a whole family"; exit 1; }
printf '%s' "$flat" | grep -Fq 'Do NOT report a face carried with' \
  || { echo "FAIL: PERF-059 does not exempt the Google unicode-range carry that /wp-init Step 4.5 produces"; exit 1; }

# 2. The fix, and the flag that keeps it from degrading the rendering.
grep -Fq 'Font subsetting fix' "$audit" \
  || { echo "FAIL: $audit has no fix section for PERF-059, so the finding has no remedy"; exit 1; }
grep -Fq 'pyftsubset' "$audit" \
  || { echo "FAIL: the PERF-059 fix names no subsetting tool"; exit 1; }
# `-e --`: the needle starts with a dash, which grep would otherwise read as an option.
grep -Fq -e "--layout-features='*'" "$audit" \
  || { echo "FAIL: the PERF-059 fix drops kerning and ligatures — a subset that renders worse at the same coverage is a regression, not a saving"; exit 1; }
grep -Fq 'brotli' "$audit" \
  || { echo "FAIL: the PERF-059 fix does not name the brotli dependency woff2 output needs, so --flavor=woff2 fails at the point of use"; exit 1; }

# 3. The verification, which is the whole reason this is safe to auto-fix.
printf '%s' "$flat" | grep -Fq "against the site's real text" \
  || { echo "FAIL: the PERF-059 fix does not verify coverage against the site's own text — checking the range list against itself proves nothing"; exit 1; }
grep -Fq 'getBestCmap()' "$audit" \
  || { echo "FAIL: the PERF-059 fix carries no cmap coverage check"; exit 1; }
printf '%s' "$flat" | grep -Fq 'is a refusal, not a warning' \
  || { echo "FAIL: the PERF-059 fix does not make a missing glyph block the replacement"; exit 1; }
# Silent failure mode, stated. This is what stops the check being dropped as ceremony.
printf '%s' "$flat" | grep -Fq 'does not error' \
  || { echo "FAIL: the PERF-059 fix does not say that a missing glyph fails silently through font fallback"; exit 1; }
# Field and term text lives outside post_content. A sample that misses it passes a subset that
# is missing characters the site renders.
printf '%s' "$flat" | grep -Fq 'outside `post_content`' \
  || { echo "FAIL: the PERF-059 fix does not warn that ACF/SCF field values and term names are not in post_content"; exit 1; }
# A subset is lossy and one-way.
printf '%s' "$flat" | grep -Fq 'cannot be widened back' \
  || { echo "FAIL: the PERF-059 fix does not require keeping the original family, which a subset cannot be widened back into"; exit 1; }

echo "PASS: PERF-059 reports an unsubsetted self-hosted font and its fix verifies coverage before replacing one"
