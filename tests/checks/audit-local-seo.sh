#!/usr/bin/env bash
# The local SEO checks are only correct when three guards survive editing, and each one
# looks like a paragraph someone could trim for brevity:
#
#   1. The applicability gate. Without it SEO-055..SEO-063 fire on every brochure site
#      that happens to have a phone number in its footer, and the audit fills with
#      findings no one can act on.
#   2. The business-type resolution ahead of the address checks. A service-area business
#      has no street address by design; reporting one as missing is a false critical, and
#      false criticals are how an audit stops being read.
#   3. NAP normalization before comparison. Unnormalized, "+34 900 00 00 00" and
#      "900000000" disagree, SEO-057 fires on every site, and the check gets muted.
#
# The agent also must not auto-apply the two local fixes that change rendered markup,
# and must keep pointing at the skill that carries all of the above.
#
# Every assertion below greps for the exact wording that carries the contract, which is
# this repo's house style: a failure here means the sentence changed, not that the code
# broke. Reword one on purpose and update its line in the same commit, so a reviewer sees
# both halves of the change at once.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

AGENT="agents/wp-audit-seo.md"
SKILL="skills/wp-audit-local-standards/SKILL.md"

[ -f "$SKILL" ] || fail "$SKILL is missing — the local checks have no criteria to read"
[ -f "$AGENT" ] || fail "$AGENT is missing — the local checks have no agent to read"

# The skill is a knowledge library, not an actor. A skill that acts is the one thing the
# layer rules forbid, and claude-seo's original shipped as user-invocable: true.
awk 'NR<=8 && /^user-invocable: false/ { f = 1 } END { exit !f }' "$SKILL" \
  || fail "$SKILL does not declare user-invocable: false in its frontmatter"

# Every local code the agent tables must exist, or the report cites codes with no criteria.
for code in SEO-055 SEO-056 SEO-057 SEO-058 SEO-059 SEO-060 SEO-061 SEO-062 SEO-063; do
  grep -Fq "$code" "$AGENT" || fail "$AGENT does not define $code"
done

# Guard 1 — the gate, and the agent's instruction to run it before anything else.
grep -Fq 'Applicability Gate' "$SKILL" \
  || fail "$SKILL lost the applicability gate — the local checks would run on every site"
grep -Fq 'any two' "$SKILL" \
  || fail "$SKILL no longer requires two independent local signals for the gate"
grep -Fq 'Run the applicability gate first' "$AGENT" \
  || fail "$AGENT no longer runs the applicability gate before the local checks"
grep -Fq 'not_applicable' "$AGENT" \
  || fail "$AGENT no longer reports the local checks as not_applicable on a non-local site"

# Guard 2 — business type resolved first, and the SAB exemption stated in both places.
grep -Fq 'Determine the business type before anything else' "$AGENT" \
  || fail "$AGENT no longer resolves the business type before the address checks"
grep -Fq 'no street address by design' "$AGENT" \
  || fail "$AGENT lost the reason SAB sites are exempt from the address checks"
grep -Fq 'Service-area (SAB)' "$SKILL" \
  || fail "$SKILL lost the service-area business type"

# Guard 3 — normalization, with the concrete phone case that proves it is about digits.
grep -Fq 'Normalize before comparing' "$SKILL" \
  || fail "$SKILL lost the NAP normalization rules — SEO-057 would fire on formatting"
grep -Fq 'Normalize before comparing' "$AGENT" \
  || fail "$AGENT no longer normalizes NAP values before comparing them"

# Options-page fields keep their _<lang> suffixes under BOTH i18n strategies. A local
# audit that compares only one language reports a stale address as correct.
grep -Fq '_<lang>' "$AGENT" \
  || fail "$AGENT no longer compares the _<lang> variants under the suffix strategy"
grep -Fq '_<lang>' "$SKILL" \
  || fail "$SKILL lost the bilingual options-page rule"
grep -Fq 'suffixes under *both* i18n strategies' "$SKILL" \
  || fail "$SKILL lost the crossover clause — under polylang the suffixed options fields would go unchecked"

# The bilingual rule used to open "Under the `suffix` strategy ...", in the skill and in the
# agent's SEO-057 row, which made the comparison conditional on suffix and left a Polylang
# site's stale suffixed address unchecked -- the crossover clause above says the opposite.
grep -Fq 'Under the `suffix` strategy the options-page fields' "$SKILL" \
  && fail "$SKILL still makes the _<lang> comparison conditional on the suffix strategy"
grep -Fq 'Under the `suffix` i18n strategy compare' "$AGENT" \
  && fail "$AGENT SEO-057 still compares _<lang> variants only under the suffix strategy"
grep -Fq 'always compare every `_<lang>` variant' "$AGENT" \
  || fail "$AGENT SEO-057 does not compare the _<lang> variants under both strategies"

# Rank Math stores its titles and local values in `rank-math-options-titles`. The local
# check read `rank_math_titles`, which does not exist, so `wp option get` failed and the
# Rank Math source silently dropped out of the NAP comparison.
for f in "$SKILL" "$AGENT"; do
  grep -Fq 'rank_math_titles' "$f" && fail "$f reads rank_math_titles, an option Rank Math never writes"
  grep -Fq 'rank-math-options-titles' "$f" || fail "$f does not read Rank Math's real titles option"
done
grep -Fq 'knowledgegraph_name' "$SKILL" || fail "$SKILL does not name the Rank Math key the business name comes from"
grep -Eq '^wp option get' "$SKILL" && fail "$SKILL shows bare wp, which fails on a Docker, DDEV or Lando wrapper"
grep -Fq 'five different places' "$SKILL" && fail "$SKILL counts five sources over a table of three"

# The phone rule has to reconcile the agent's own example. Digits alone turn
# "+34 900 00 00 00" into 34900000000 and leave it unequal to 900000000.
grep -Fq 'country calling code' "$SKILL" || fail "$SKILL phone normalization has no country-code step"
grep -Fq '| `+34 900 00 00 00` (JSON-LD, Spain) | `900000000` (footer `tel:`) | `900000000` and `900000000` | same number, no finding |' "$SKILL" \
  || fail "$SKILL lost the worked pair that proves the phone rule reconciles +34 900 00 00 00 with 900000000"
grep -Fq 'a leading `+`; compare the digits.' "$SKILL" \
  && fail "$SKILL still normalizes phones to bare digits, which reports +34 900 00 00 00 against 900000000"

# The service-area exemption covers the map and the address, never click-to-call, in both files.
grep -Eq '^\| SEO-056 \|.*`tel:` link is WARNING on every business type' "$AGENT" \
  || fail "$AGENT SEO-056 does not apply the click-to-call half to every business type"
grep -Fq 'Brick-and-mortar or hybrid only. Grep templates' "$AGENT" \
  && fail "$AGENT SEO-056 still exempts a service-area business from click-to-call"
grep -Fq 'a service-area business is never reported for an absent address' "$AGENT" \
  || fail "$AGENT SEO-057 does not scope the absent-address finding to brick-and-mortar and hybrid"
grep -Fq 'for it an absent address is not a finding' "$SKILL" \
  || fail "$SKILL reports an absent address on a service-area business"

# SEO-063 reads only the schema, and it is the one CRITICAL: an undetermined site still gets it.
grep -Fq '(SEO-055, SEO-058, SEO-060, SEO-061, SEO-063)' "$SKILL" \
  || fail "$SKILL leaves SEO-063 out of the type-independent checks"
grep -Fq 'SEO-061 and SEO-063' "$AGENT" || fail "$AGENT leaves SEO-063 out of the undetermined-type run"

# A recommended property with no check id cannot be a finding, and aggregateRating is never
# recommended: an INFO nudge toward it is a nudge toward what SEO-063 rates CRITICAL.
grep -Fq 'each one its own INFO finding when absent' "$SKILL" \
  && fail "$SKILL turns recommended properties into findings that no check id carries"
grep -Fq '`aggregateRating` **only when real review data backs it**' "$SKILL" \
  && fail "$SKILL still recommends aggregateRating"
grep -Fq '`aggregateRating` is never on that list' "$SKILL" \
  || fail "$SKILL does not keep aggregateRating out of the recommendations"

# schema.org supersedes branchOf with parentOrganization.
grep -Fq 'through `parentOrganization`' "$SKILL" || fail "$SKILL does not link locations with parentOrganization"
grep -Fq 'Organization through `branchOf`.' "$SKILL" && fail "$SKILL still requires the superseded branchOf"

# Criteria that lived only in the skill, with nothing to fail when they were trimmed:
# the subtype each vertical requires (SEO-058 defers to it), one default per vertical so two
# runs decide SEO-058 the same way, the sampling gates SEO-062 applies, a reproducible sample,
# and the unique @id per location.
for subtype in '`Restaurant`' '`MedicalClinic`' '`LegalService`' '`RealEstateAgent`' '`AutoDealer`' '`HomeAndConstructionBusiness`'; do
  grep -Eq "^\| [A-Z][a-z ]+ \|.*\| .*$subtype" "$SKILL" || fail "$SKILL vertical table lost the required subtype $subtype"
done
grep -Fq '`MedicalClinic`, `Dentist` or `Hospital`' "$SKILL" \
  && fail "$SKILL offers three healthcare subtypes with no rule for choosing"
grep -Fq 'passes SEO-058 with either subtype' "$SKILL" || fail "$SKILL has no tie-break for a site matching two verticals"
grep -Fq 'Audit a sample of 10' "$SKILL" || fail "$SKILL lost the location-page sampling gate"
grep -Fq 'sort the location pages by slug' "$SKILL" || fail "$SKILL sample is not reproducible between runs"
grep -Fq 'unique `@id`' "$SKILL" || fail "$SKILL lost the unique @id per location"
grep -Fq 'Deprecated subtypes' "$SKILL" || fail "$SKILL lost the deprecated subtypes SEO-058 flags"

# Rendered markup is never changed without asking: a new element inherits browser default
# styles and can override the utility classes already on the page.
grep -Fq 'never auto-applied' "$AGENT" \
  || fail "$AGENT no longer forbids auto-applying the local fixes that change markup"
grep -Fq '| SEO-056 |' "$AGENT" && grep -E '^\| *SEO-056 *\|.*\| *No *\| *$' "$AGENT" >/dev/null \
  || fail "SEO-056 is not marked auto-fix No — it adds a visible tel: link or map embed"

# Severity: SEO-063 is the only CRITICAL, because it is a manual-action risk.
grep -E '^\| *SEO-063 *\|.*\| *CRITICAL *\| *$' "$AGENT" >/dev/null \
  || fail "SEO-063 is no longer CRITICAL — a fabricated aggregateRating risks a manual action"

# The agent must still send the reader to the skill, or the criteria are orphaned.
grep -Fq 'wp-audit-local-standards' "$AGENT" \
  || fail "$AGENT no longer reads skills/wp-audit-local-standards/SKILL.md"

# Off-site limits are stated, so a local report never implies a completeness it lacks.
grep -Fq 'What This Audit Cannot See' "$SKILL" \
  || fail "$SKILL lost the limitations section the local report must end with"

# MIT attribution for the ported taxonomies travels with the file that carries them.
grep -Fq 'claude-seo' "$SKILL" \
  || fail "$SKILL lost the upstream attribution for the ported taxonomies"

echo PASS
