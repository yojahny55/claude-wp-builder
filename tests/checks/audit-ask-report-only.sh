#!/usr/bin/env bash
# /wp-audit without --report-only learned that the operator wanted a read-only audit only at
# Step 9, after Step 4 had already offered to install plugins and Step 5 to configure AIOS on
# the site. The command must ask for report-only in Step 1, before any other prompt, and a
# report-only run must not offer plugin installs.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

audit=commands/wp-audit.md
[ -f "$audit" ] || fail "$audit missing"

step1=$(awk '/^## Step 1:/{on=1} /^## Step 2:/{on=0} on' "$audit")
[ -n "$step1" ] || step1=$(cat "$audit")

grep -Fq 'If `--report-only` was NOT passed, ask before any other question of the run' <<<"$step1" \
  || fail "Step 1 no longer asks for report-only when the flag is absent"
grep -Fq '[A] Report only' <<<"$step1" || fail "Step 1 question lost the report-only option"
grep -Fq 'set `--report-only` for the rest of the run' <<<"$step1" \
  || fail "the report-only answer no longer sets the flag"
grep -Fq 'When the flag was passed, do not ask.' <<<"$step1" \
  || fail "Step 1 asks even when --report-only was typed"

# Order, independent of headings: the question must come before the adoption prompt and the
# plugin-install prompt, so a whole-file fallback above cannot hide it moving back to Step 9.
line_of() { grep -nF -- "$1" "$audit" | head -1 | cut -d: -f1; }
q=$(line_of '[A] Report only')
adopt=$(line_of '[A] Adopt it now')
install=$(line_of '[A] Install all recommended WordPress plugins')
[ -n "$adopt" ] && [ -n "$install" ] || fail "adoption or plugin-install prompt not found in $audit"
[ "$q" -lt "$adopt" ] || fail "report-only question comes after the adoption prompt"
[ "$q" -lt "$install" ] || fail "report-only question comes after the plugin-install prompt"

step4=$(awk '/^## Step 4:/{on=1} /^## Step 5:/{on=0} on' "$audit")
[ -n "$step4" ] || step4=$(cat "$audit")
grep -Fq 'With `--report-only`, this step installs nothing.' <<<"$step4" \
  || fail "Step 4 can install plugins on a report-only run"

# A report-only run wrote no .md/.html unless --report was also typed, so the operator who
# chose "report only" got nothing but console scrollback and no baseline for the next run.
grep -Fq 'A report-only run always writes the deliverable.' <<<"$step1" \
  || fail "Step 1 no longer defaults --report on a report-only run"
grep -Fq 'and `--report` is absent, set `--report both`' <<<"$step1" \
  || fail "Step 1 lost the --report both default for report-only"
grep -Fq '[A] Report only — audit and write the report (.md + .html)' <<<"$step1" \
  || fail "answer A no longer says a document will be written"
step85=$(awk '/^## Step 8\.5:/{on=1;print;next} on&&/^## /{on=0} on' "$audit")
[ -n "$step85" ] || fail "no Step 8.5 in $audit"
grep -Fq 'or the run is report-only (Step 1 defaults `--report`' <<<"$step85" \
  || fail "Step 8.5 does not run on a report-only run"
step11=$(awk '/^## Step 11:/{on=1;print;next} on&&/^## /{on=0} on' "$audit")
[ -n "$step11" ] || fail "no Step 11 in $audit"
ro=$(awk '/^If `--report-only` was used:/{on=1} on' <<<"$step11")
[ -n "$ro" ] || fail "Step 11 no longer has a report-only summary block"
grep -Fq 'Report: .wp-audit/informe-<AAAA-MM-DD>.md' <<<"$ro" \
  || fail "Step 11 report-only summary does not print the .md path"
grep -Fq '.wp-audit/informe-<AAAA-MM-DD>.html' <<<"$ro" \
  || fail "Step 11 report-only summary does not print the .html path"
grep -Fq 'Review the report written above' <<<"$ro" \
  || fail "Step 11 report-only summary no longer points at the written deliverable"
# The paths are what Step 8.5 wrote, not a fixed pair: --report md writes one file, and a
# failed render writes none.
grep -Fq '**The `Report:` lines name only what Step 8.5 actually wrote**' <<<"$step11" \
  || fail "Step 11 prints a fixed pair of paths whatever was written"
grep -Fq 'Report: not written — <the reason>' <<<"$step11" \
  || fail "Step 11 has no summary for a render that wrote nothing"

# What the operator reads before running the command must say the same thing.
tr '\n' ' ' < docs/commands.md | grep -Fq 'report-only run always writes the dated deliverable (`--report` defaults to `both`)' \
  || fail "docs/commands.md no longer says a report-only run writes the deliverable"
grep -Fq '/wp-audit --report-only      # Report without fixing (writes the .md + .html deliverable)' README.md \
  || fail "README.md usage line no longer says report-only writes the deliverable"
grep -Fq 'the first question of the run asks whether you want the report only' docs/commands.md \
  || fail "docs/commands.md does not describe the report-only question"

echo PASS
