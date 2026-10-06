#!/usr/bin/env bash
# skills/wp-audit-ux-standards/SKILL.md is the usability catalog, and it contradicted itself
# and the code around it in ways that each changed what an audit reports:
#
#   - applicability was stated twice and the two copies disagreed (UX-019 N/A for "no image
#     used as a link" in one place and for "no images" in the other; UX-034 "N/A, or reduced"
#     against plain N/A), so two runs on one site scored different denominators;
#   - it said the criteria that need a rendered page are UNMEASURED without --suite, when
#     bin/ux-probe.mjs measures them in the agent's own Step 2 with no suite at all;
#   - it said every `code` fix is a visual change while the agent said almost every -- UX-014,
#     UX-016 and UX-035 fixes are not;
#   - it called UX-045 "deliberately absent" while the suite emits UX-045 for contrast, and
#     never said which numbers the suite owns, so the next new criterion would take UX-039, a
#     number the suite already emits.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

k=skills/wp-audit-ux-standards/SKILL.md
[ -r "$k" ] || fail "$k is missing or unreadable"
flat=$(tr '\n' ' ' < "$k" | sed 's/  */ /g')
has() { case "$flat" in *"$1"*) return 0 ;; *) return 1 ;; esac; }

# One statement of applicability, and the copies in the groups are gone.
has 'This list is the only statement of applicability' || fail "$k does not make its applicability list the only one"
has '- no image used as a link → `UX-019`' || fail "$k does not scope UX-019 to image links"
has '- no images, tables or charts → `UX-033`' || fail "$k does not scope UX-033 to images, tables and charts"
has 'no images → `UX-019`' && fail "$k still makes UX-019 N/A for a site with no images at all"
grep -Eq '^Applicability: no ' "$k" && fail "$k still states applicability inside a group as well as in the list"
has 'reduces it to "the logo is present"' && fail "$k still offers UX-034 two answers on a single-page site"
has '`UX-017` is reduced' && fail "$k still says UX-017 is 'reduced' without saying what that means"
has 'site small enough that search adds nothing' && fail "$k still makes UX-020 N/A on an unmeasurable 'small enough'"

# The rendered measurements come from the harness, not only from --suite.
has 'Rendered measurements come from `${CLAUDE_PLUGIN_ROOT}/bin/ux-probe.mjs`' \
  || fail "$k does not name bin/ux-probe.mjs as where rendered measurements come from"
has 'Without it, the criteria that need a rendered page are `UNMEASURED`' \
  && fail "$k still says the rendered criteria are UNMEASURED without --suite"

# Not every code fix is visual.
has 'Every fix in the `code` column' && fail "$k still says every code fix is a visual change"
has 'Almost every fix in a row whose Owner is `code` is a visual change' \
  || fail "$k does not say which fixes are visual changes"

# The numbers the suite owns.
has '`UX-022`, `UX-023` and `UX-039` to `UX-058` are not holes' \
  || fail "$k does not name the UX numbers the browser suite emits"
has 'A new usability criterion takes the next number above `UX-058`' \
  || fail "$k does not say where a new criterion's number starts"
has '`UX-045` (contrast) is deliberately absent' && fail "$k still calls UX-045 absent while the suite emits it"
for n in 022 023 039 045 058; do
  grep -qE "^\| UX-$n \|" "$k" && fail "$k tabulates UX-$n, a number the browser suite already emits"
done

# --- contracts that lived only here, with no pin -------------------------------------------
# UX-014 is one finding per page. A row per link turns one bad footer into forty findings, and
# matches nothing the suite emits, so the check+resource merge keeps both copies.
has '**One row per page, not per link.**' || fail "$k lost the one-row-per-page rule for UX-014"
has '`UX-014 : page:/contact/`' || fail "$k lost the UX-014 resource example"
# The site-level list: every id in it is a catalog row, and the seven are all there.
site=$(grep -E '^- \*\*Site-level\*\*' "$k" || true)
[ -n "$site" ] || fail "$k lost its site-level list"
for id in UX-015 UX-028 UX-029 UX-032 UX-034 UX-036 UX-038; do
  grep -Fq "\`$id\`" <<<"$site" || fail "$k site-level list lost $id"
done
for id in $(grep -oE 'UX-[0-9]{3}' <<<"$site"); do
  grep -qE "^\| $id \|" "$k" || fail "$k names $id as site-level but has no catalog row for it"
done
# The standard a visual fix must meet.
for t in '**Consent.**' '**Equivalence, measured.**' '**Coverage.**'; do
  has "$t" || fail "$k lost the fix standard: $t"
done
# A catalog store has no checkout: the recorded tier decides, not a guess.
has 'a catalog store (`site.store_tier` = `catalog`, recorded by `/wp-audit` Step 2.3)' \
  || fail "$k does not read the recorded store tier for the checkout criteria"
has '`unknown` is not `catalog`: it audits as a store' || fail "$k does not say an unknown tier audits as a store"
# Plugin paths resolve from the plugin, not from the user's project.
has 'see `agents/wp-audit-ux.md`' && fail "$k points at the agent with a relative path"
has '`${CLAUDE_PLUGIN_ROOT}/agents/wp-audit-ux.md`' || fail "$k does not point at the agent's procedure"
# The near-miss boundary the description carries.
grep -Eq '^description: .*Not for contrast, ARIA, focus or target size \(wp-audit-a11y\)' "$k" \
  || fail "$k description does not hand accessibility requests to wp-audit-a11y"

echo "PASS: the usability catalog states applicability once, names its measurements, and leaves the suite's numbers alone"
