#!/usr/bin/env bash
# The six auditors answer whether the code is safe, findable, compliant, fast, idiomatic
# and legible to an agent. None of them answers whether a person can use the site: a form
# that marks no field as required is valid HTML, escapes correctly, loads fast and passes
# WCAG, and the audit said nothing.
#
# wp-audit-ux fills that, and it is the only auditor whose scope is a list of URLs rather
# than a theme directory. Two things therefore have to hold, and both fail silently:
#
#   - a page-level criterion with no page list must report UNMEASURED, because an audit
#     that measured nothing and printed no failures reads exactly like a clean site;
#   - N/A must stay out of the denominator, because scoring a brochure site against the
#     form criteria it never had punishes it for its own shape.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

c=commands/wp-audit.md
a=agents/wp-audit-ux.md
k=skills/wp-audit-ux-standards/SKILL.md
for f in "$c" "$a" "$k"; do
  [ -f "$f" ] || fail "$f is missing"
  [ -r "$f" ] || fail "$f exists but cannot be read"
done

inc() { grep -Fq -- "$2" "$1" || fail "$1 $3"; }

# --- the command ------------------------------------------------------------------------
inc "$c" '--usability' 'has no --usability flag'
inc "$c" '--pages <list|auto|none>' 'has no page-scope flag, so a page-level auditor has nothing to audit'
inc "$c" 'Step 2.7: Fix the page scope' 'has no step that fixes which pages are measured'
inc "$c" 'wp-audit-ux' 'never dispatches the usability auditor'

# The derivation has to be ordered and to stop, or "audit the site" becomes "audit forty
# pages", which measures five templates eight times each and produces a report nobody acts on.
inc "$c" 'stops at the first that yields pages' 'does not order the page derivation'
inc "$c" 'Cap the list at eight pages and say you capped it' 'does not cap the page list'
inc "$c" 'one page per template' 'does not say what to keep when capping'
# The 404 and the form page are where a third of the catalog lives and no ranking finds them.
inc "$c" 'the 404' 'does not add the 404 to the scope'
inc "$c" 'carrying a form' 'does not add the form page to the scope'

# The two quiet failures.
inc "$c" 'page-level criterion with no page list is `UNMEASURED`, never `PASS`' \
  'lets a page-level check pass without a page, so an audit that measured nothing reads clean'
inc "$c" 'excluded from the denominator' 'scores N/A against the site, punishing it for its own shape'
inc "$c" '`UNMEASURED` is excluded too' 'folds unmeasured work into the score, hiding it'
inc "$c" 'reported on **every page it fails on**' \
  'does not say that a page-level failure is reported per page, so one row would hide which template is wrong'
inc "$c" 'it names the pages it' \
  'does not require a site-level failure to name where the pages disagree'

# The coverage diff in Step 2.5d enumerates the categories in prose, beside the module that
# validates them. A category missing from the prose list is one the matrix can never report
# NEVER RUN -- and it would be the newest category, the one most likely to be skipped.
inc "$c" '`best-practices`, `geo`, `usability`' \
  'leaves usability out of the coverage diff list, so a project that never ran it is never told'

# The default keys off the SELECTED category, not the typed flag. `--all` and a bare
# /wp-audit both select usability without naming it, and keying off the token would make
# the commonest invocation report the whole category UNMEASURED.
inc "$c" 'Selected, not typed' \
  'keys the --pages default off the literal flag, so a bare /wp-audit measures no page'

# The suite takes its page list from the invocation, not from its config file: omit it and
# a first run measures the template placeholder while reporting success.
inc "$c" 'Pass `--pages` with the list Step 2.7 fixed' \
  'never tells Step 6.5 to pass the derived page list to the suite'

# Step 8 requires UNMEASURED counted separately in every summary line, and usability is the
# category most likely to carry a large one.
inc "$c" '? UNMEASURED:' 'has no UNMEASURED line in the usability report block'

# Every other category has a fix-dispatch block. Without one, usability findings are counted
# into the "apply them?" prompt and then silently never applied.
inc "$c" '**Usability fixes:**' 'counts usability into the fix offer and dispatches nothing to apply it'
inc "$c" 'agreed to visual changes' \
  'lets the fixer restyle the site without the consent the catalog requires'

# --- the agent --------------------------------------------------------------------------
grep -q '^name: wp-audit-ux$' "$a" || fail "$a has no name in its frontmatter"
grep -q '^model: sonnet$' "$a" || fail "$a does not declare its cost tier"
grep -q '^tools: Read, Write, Edit, Grep, Glob, Bash$' "$a" || fail "$a has the wrong tools line"
inc "$a" 'First Action (MANDATORY)' 'does not open with the mandatory first-action block'
inc "$a" 'skills/wp-audit-ux-standards/SKILL.md' 'does not read its own catalog'
inc "$a" 'work from memory' 'lets the agent invent codes instead of reading the catalog'

# Applicability is decided first, or an awkward criterion becomes N/A because it was hard
# to measure -- which is the failure the three-way split exists to prevent.
inc "$a" 'Decide what applies, before measuring' 'decides applicability while scoring'
inc "$a" 'hard to measure' 'does not say why applicability is decided first'

# The three criteria that are measured rather than read. Reading them instead is how this
# audit goes wrong while producing a full report.
inc "$a" 'follow the links' 'infers broken links instead of following them'
# UX-014 is page-level and UX-015 is site-level. Grouped under one procedure, an
# implementer emits UX-015 per page, its resource matches nothing the suite emits, and the
# merge on check+resource leaves both copies in the report.
inc "$a" 'UX-015` is **site-level**' \
  'counts UX-015 per page, contradicting the catalog and breaking the merge key'
inc "$a" 'UX-015 : site' 'does not give UX-015 the resource its site-level classification requires'
inc "$a" 'count rendered characters, per breakpoint' 'reads CSS instead of measuring line length'
inc "$a" 'getBoundingClientRect()' 'does not measure the rendered gap between action elements'

# Ownership crosses into the report as the column that says whose work a row is.
inc "$a" 'Owner: <code|setting|content|manual>' 'does not report an owner per finding'
inc "$a" 'never from whether you could' \
  'lets ownership follow what the agent can automate, which collapses setting into code'

# Almost every fix here is a visual change, and the house rule is measure before and after.
inc "$a" 'Fixes change how the site looks' 'does not warn that its fixes are visual changes'
inc "$a" 'getComputedStyle()' 'does not require a before-and-after measurement'
inc "$a" 'element carrying that class' 'measures only the element it was looking at'

# --- the standards skill ------------------------------------------------------------------
grep -q '^user-invocable: false$' "$k" || fail "$k is not marked user-invocable: false"
grep -qE '\bUX-0[0-9]{2}\b' "$k" || fail "$k holds no UX-NNN codes, so the catalog it is named as is empty"
inc "$k" 'Numbers are never reused' 'lets a retired code be reassigned, which breaks every ledger entry holding it'
inc "$k" 'the accessibility code wins' 'does not resolve the overlap with wp-audit-a11y, so one defect gets two codes'
inc "$k" 'When in doubt, the criterion applies' 'lets N/A be used to dodge an unimplemented criterion'
inc "$k" 'Site-level' 'does not split page-level from site-level'

# Contrast belongs to A11Y-003 and must not be restated here under a second code.
if grep -qE '^\| UX-045 ' "$k"; then
  fail "$k restates contrast as UX-045 -- it is A11Y-003, and two codes for one defect inflate every count"
fi

# Every catalog row names an owner, or the report's last column ships blank for these.
missing=$(awk -F'|' '/^\| UX-[0-9]+ /{ o=$(NF-1); gsub(/ /,"",o); if (o !~ /^(code|setting|content|manual)$/) print $2 }' "$k")
[ -z "$missing" ] || fail "$k has catalog rows with no valid owner:
$missing"

echo "PASS: usability has a catalog, a page scope that refuses to pass unmeasured checks, and an owner on every row"
