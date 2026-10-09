#!/usr/bin/env bash
# /wp-audit ran the browser suite only when --suite was typed, so a bare /wp-audit never
# loaded a page as a visitor does. Without the flag, Step 1 must ask for it up front,
# before the adoption and plugin-install prompts, and a yes must act as the typed flag.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

audit=commands/wp-audit.md
[ -f "$audit" ] || fail "$audit missing"

step1=$(awk '/^## Step 1:/{on=1} /^## Step 2:/{on=0} on' "$audit")
[ -n "$step1" ] || step1=$(cat "$audit")

grep -Fq 'If `--suite` was NOT passed, ask right after the report-only question' <<<"$step1" \
  || fail "Step 1 no longer asks for the suite when the flag is absent"
grep -Fq 'Also run the browser suite (web-portal-audit' <<<"$step1" \
  || fail "Step 1 lost the suite question"
grep -Fq 'On A, set `--suite` for the rest of the run, exactly as if it had been typed' <<<"$step1" \
  || fail "a yes to the suite question no longer sets the flag"
grep -Fq 'answering A asks for nothing more here' <<<"$step1" \
  || fail "the suite question no longer reuses Step 6.5's URL resolution"

# Scoped to the suite subsection: the report-only subsection carries the same sentence, so a
# grep over all of Step 1 would pass with this one deleted.
suite=$(awk '/^### Ask for the browser suite up front/{on=1;print;next} on&&/^#/{on=0} on' "$audit")
[ -n "$suite" ] || fail "no suite subsection in Step 1"
grep -Fq 'When the flag was passed, do not ask.' <<<"$suite" \
  || fail "Step 1 asks for the suite even when --suite was typed"

line_of() { grep -nF -- "$1" "$audit" | head -1 | cut -d: -f1; }
q=$(line_of 'Also run the browser suite (web-portal-audit')
ro=$(line_of '[A] Report only')
adopt=$(line_of '[A] Adopt it now')
install=$(line_of '[A] Install all recommended WordPress plugins')
[ -n "$q" ] && [ -n "$ro" ] && [ -n "$adopt" ] && [ -n "$install" ] || fail "a prompt was not found in $audit"
[ "$ro" -lt "$q" ] || fail "suite question comes before the report-only question"
[ "$q" -lt "$adopt" ] || fail "suite question comes after the adoption prompt"
[ "$q" -lt "$install" ] || fail "suite question comes after the plugin-install prompt"

tr '\n' ' ' < docs/commands.md | grep -Fq 'question of the run also asks whether to run the suite' \
  || fail "docs/commands.md does not describe the suite question"

echo PASS
