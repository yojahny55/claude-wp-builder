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
set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }

cd "$(dirname "$0")/../.." || fail "cannot cd to the repository root"

audit=agents/wp-audit-performance.md
# -s, not -f: an empty file fails every assertion below on its own, and eleven
# near-identical "does not mention" lines hide the one fact that explains them.
[ -s "$audit" ] || fail "$audit is missing or empty"
flat=$(tr '\n' ' ' < "$audit" | sed 's/  */ /g')

# The fix section alone. Several needles below also appear in the PERF-059 detection row,
# which names the same cmap command it tells the auditor to run — so a whole-file grep stayed
# green with the verification snippet deleted from the fix, which is the one thing that makes
# this finding safe to auto-fix. The slice runs from the fix heading to the next one.
fix=$(awk '/^### Font subsetting fix/{f=1; next} f && /^### /{exit} f{print}' "$audit")
[ -n "$fix" ] || fail "$audit has no '### Font subsetting fix' section, so PERF-059 has no remedy"
flatfix=$(printf '%s' "$fix" | tr '\n' ' ' | sed 's/  */ /g')

# 1. The criterion and its exemption.
grep -Fq 'PERF-059' "$audit" \
  || fail "$audit has no PERF-059 row for an unsubsetted self-hosted font"
printf '%s' "$flat" | grep -Fq 'unicode-range' \
  || fail "PERF-059 does not mention unicode-range, so it cannot tell a subsetted carry from a whole family"
printf '%s' "$flat" | grep -Fq 'Do NOT report a face carried with' \
  || fail "PERF-059 does not exempt the Google unicode-range carry that /wp-init Step 4.5 produces"

# 2. The fix, and the flag that keeps it from degrading the rendering.
printf '%s' "$fix" | grep -Fq 'pyftsubset' \
  || fail "the PERF-059 fix names no subsetting tool"
# `-e --`: the needle starts with a dash, which grep would otherwise read as an option.
printf '%s' "$fix" | grep -Fq -e "--layout-features='*'" \
  || fail "the PERF-059 fix drops kerning and ligatures — a subset that renders worse at the same coverage is a regression, not a saving"
printf '%s' "$fix" | grep -Fq 'brotli' \
  || fail "the PERF-059 fix does not name the brotli dependency woff2 output needs, so --flavor=woff2 fails at the point of use"

# 3. The verification, which is the whole reason this is safe to auto-fix.
printf '%s' "$flatfix" | grep -Fq "against the site's real text" \
  || fail "the PERF-059 fix does not verify coverage against the site's own text — checking the range list against itself proves nothing"
printf '%s' "$fix" | grep -Fq 'getBestCmap()' \
  || fail "the PERF-059 fix carries no cmap coverage check"
printf '%s' "$flatfix" | grep -Fq 'is a refusal, not a warning' \
  || fail "the PERF-059 fix does not make a missing glyph block the replacement"
# Silent failure mode, stated. This is what stops the check being dropped as ceremony.
printf '%s' "$flatfix" | grep -Fq 'does not error' \
  || fail "the PERF-059 fix does not say that a missing glyph fails silently through font fallback"
# Field and term text lives outside post_content. A sample that misses it passes a subset that
# is missing characters the site renders.
printf '%s' "$flatfix" | grep -Fq 'outside `post_content`' \
  || fail "the PERF-059 fix does not warn that ACF/SCF field values and term names are not in post_content"
# A subset is lossy and one-way.
printf '%s' "$flatfix" | grep -Fq 'cannot be widened back' \
  || fail "the PERF-059 fix does not require keeping the original family, which a subset cannot be widened back into"

echo "PASS: PERF-059 reports an unsubsetted self-hosted font and its fix verifies coverage before replacing one"
