#!/usr/bin/env bash
# Three costs a real full-site build paid for nothing.
#
# 1. wp-normalize captured verbatim `cssRules` for every section on the tailwind
#    path — a full read of every stylesheet and a full write of every rule — to
#    produce a field /wp-yolo Step 4 then forbids the section walk from reading.
# 2. Step 2.6 converted every copy of a repeated card. A directory page drawing
#    16 cards from 4 records, and a board page drawing 18 from 3, were the two
#    most expensive conversions in the run; in the theme all N collapse into one
#    template part inside a loop, so the extra conversions were discarded work.
# 3. wp-acf and wp-template each ship a "WP-CLI Integration" section telling the
#    agent to run `$WP ...`, while their frontmatter granted no Bash. Both agents
#    reported verification they could not run, and the orchestrator re-ran it.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $1"; exit 1; }

# --- 3. an agent told to run a shell must have one ------------------------
for a in wp-acf wp-template; do
  f=agents/$a.md
  grep -q '^tools:.*\bBash\b' "$f" || fail "$a is told to run WP-CLI but its frontmatter grants no Bash"
done
# ...and an agent that is NOT told to run one must not gain it by copy-paste.
for a in wp-css wp-tailwind wp-normalize; do
  f=agents/$a.md
  if grep -q '^tools:.*\bBash\b' "$f"; then
    grep -Eq '\$WP |wp --path|php -l' "$f" || fail "$a grants Bash but never needs a shell"
  fi
done

# --- 1. no CSS capture on the tailwind path -------------------------------
n=agents/wp-normalize.md
cap=$(awk '/^## Fidelity capture/,/^### Extended per-section schema/' "$n")
[ -n "$cap" ] || fail "no Fidelity capture region in wp-normalize"
grep -Fq 'Skip this capture entirely when the project' <<<"$cap" \
  || fail "wp-normalize still captures cssRules unconditionally"
grep -Fq '"cssRules": null' <<<"$cap" \
  || fail "wp-normalize does not say what to write instead of the skipped CSS"
grep -Fq 'fonts' <<<"$cap" \
  || fail "wp-normalize does not keep capturing fonts on both paths"
grep -Fq 'cannot be recovered from converted' <<<"$cap" \
  || fail "wp-normalize does not say why fonts survive the skip (conversion strips @font-face)"
grep -Fq '"cssRules": "<string>|null"' "$n" \
  || fail "the per-section schema still types cssRules as always-present"

# --- 2. a repeated card is transcribed once -------------------------------
grep -Fq '**Repeated cards collapse to one exemplar.**' <<<"$cap" \
  || fail "wp-normalize does not record repeated-card runs"
for k in '"selector"' '"count"' '"distinct"' '"exemplar"' '"variants"'; do
  grep -Fq "$k" "$n" || fail "the repetition block has no $k"
done
grep -Fq 'most' <<<"$cap" \
  || fail "wp-normalize does not say which sibling to pick as the exemplar"
grep -Fq 'Omit the entry when a list' <<<"$cap" \
  || fail "wp-normalize never says when NOT to collapse a list"
grep -Fq '"repetition": [' "$n" \
  || fail "the per-section schema does not carry repetition as an array"
grep -Fq 'ONE ENTRY PER REPEATED LIST' "$n" \
  || fail "the schema does not say repetition holds one entry per repeated list"
grep -Fq 'one entry per repeated list' <<<"$cap" \
  || fail "wp-normalize treats a section as having at most one repeated list"
grep -Fq 'must not' <<<"$cap" \
  || fail "wp-normalize does not forbid picking a variant as the exemplar"
grep -Fq 'never in variants[]' "$n" \
  || fail "the schema does not record that the exemplar is never a variant"

y=commands/wp-yolo.md
s26=$(awk '/^## Step 2\.6:/,/^## Step 3:/' "$y")
[ -n "$s26" ] || fail "no Step 2.6 region in wp-yolo"
grep -Fq 'Convert a repeated card once, not once per copy.' <<<"$s26" \
  || fail "Step 2.6 still converts every copy of a repeated card"
grep -Fq 'position-for-position' <<<"$s26" \
  || fail "Step 2.6 does not say how the exemplar's classes reach its siblings"
for a in href src alt 'data-*'; do
  grep -Fq "$a" <<<"$s26" || fail "Step 2.6 does not protect each sibling's own $a"
done
grep -Fq 'variant' <<<"$s26" \
  || fail "Step 2.6 has no escape hatch for a sibling that is really a variant"
grep -Fq 'one entry per repeated list' <<<"$s26" \
  || fail "Step 2.6 handles only the first repeated list in a section"
grep -Fq 'A variant never donates its classes' <<<"$s26" \
  || fail "Step 2.6 may stamp a variant's classes onto plain siblings"
grep -Fq 'keeps its own' <<<"$s26" \
  || fail "Step 2.6 does not say a variant keeps its own converted classes"
grep -Fq "Do not apply the exemplar's" <<<"$s26" \
  || fail "Step 2.6 lets a differing sibling be stamped with the exemplar's classes anyway"
grep -Fq 'Only the `class` attribute is written' <<<"$s26" \
  || fail "Step 2.6 does not restrict the stamp to the class attribute"
for a in id 'aria-*' title; do
  grep -Fq "$a" <<<"$s26" || fail "Step 2.6's untouched-attribute list omits $a"
done
# Step 2.6 runs before the section walk, so it cannot know what the walk produced.
# An unbounded edit once copied Step 4.4's skip clause up here, which would have
# skipped the whole tailwind demo conversion on a condition that cannot be evaluated.
if grep -Fq 'template-parts/section-*.php` files' <<<"$s26"; then
  fail "Step 2.6 carries Step 4.4's promotion skip condition; it cannot evaluate it yet"
fi
if grep -Fq 'nothing to promote' <<<"$s26"; then
  fail "Step 2.6 talks about promotion, which does not exist until after the walk"
fi

# --- 4. one @apply promotion pass, not one per section --------------------
# The ladder promotes a group seen "3+ times, or on 2+ distinct pages" — a
# whole-theme judgment. Run per section, wp-tailwind author mode could only grep
# what earlier sections had already written, so promotion became a function of
# dispatch order: the first section shipped raw utilities and was never revisited
# once a later sighting crossed the threshold. 26 serialized agents, each
# re-reading a template part wp-template had just written, for a split result.
grep -Fq '3+ times, or on 2+ distinct pages' skills/wp-tailwind-system/SKILL.md \
  || fail "the ladder's cross-section criterion moved; this check's premise needs rechecking"

s=commands/wp-section.md
grep -Fq '**`--defer-promotion` flag**' "$s" \
  || fail "wp-section has no --defer-promotion flag"
grep -Fq -e '--defer-promotion` suppresses Agent 3 on the `tailwind` path only' "$s" \
  || fail "wp-section does not scope --defer-promotion to the tailwind path"
grep -Fq 'skipping it would ship an unstyled section' "$s" \
  || fail "wp-section does not say why the flag must never suppress wp-css on basic"
grep -Fq 'promotion deferred' "$s" \
  || fail "wp-section does not report a deferred promotion, so it reads as a missed dispatch"

s44=$(awk '/^## Step 4\.4:/,/^## Step 4\.5:/' "$y")
[ -n "$s44" ] || fail "wp-yolo has no Step 4.4 promotion pass"
grep -Fq 'Skip this step entirely when `template == basic`' <<<"$s44" \
  || fail "Step 4.4 is not gated to the tailwind template"
grep -Fq 'template-parts/section-*.php` files' <<<"$s44" \
  || fail "Step 4.4 dispatches the promotion even when the walk produced no template parts"
grep -Fq 'after the whole section walk has finished' <<<"$s44" \
  || fail "Step 4.4 does not run after the walk"
grep -Fq 'exactly once' <<<"$s44" \
  || fail "Step 4.4 does not dispatch the promotion exactly once"
grep -Fq 'distinct pages, not files' <<<"$s44" \
  || fail "Step 4.4 does not tell the pass to count distinct pages rather than template parts"
grep -Fq 'class names only' <<<"$s44" \
  || fail "Step 4.4 does not keep wp-template's ACF wiring and escaping out of reach"
grep -Fq 'Hand-invoked `/wp-section` keeps promoting inline' <<<"$s44" \
  || fail "Step 4.4 does not preserve the hand-invoked single-section behaviour"

# every /wp-section dispatch in the walk must actually carry the flag
walk=$(awk '/^## Step 4: Phase 2/,/^## Step 4\.4:/' "$y")
# Count per LINE, not two independent totals: a dispatch missing the flag could
# otherwise be offset by an unrelated line that carries it.
disp=$(grep -c '/wp-section .*--transcribe' <<<"$walk" || true)
[ "$disp" -gt 0 ] || fail "no /wp-section transcribe dispatches found in the Step 4 walk"
bare=$(grep '/wp-section .*--transcribe' <<<"$walk" | grep -cv -e '--defer-promotion' || true)
[ "$bare" = "0" ] || fail "$bare of $disp /wp-section dispatches still promote per section"

echo PASS
