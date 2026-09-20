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
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

AGENT="agents/wp-audit-seo.md"
SKILL="skills/wp-audit-local-standards/SKILL.md"

[ -f "$SKILL" ] || fail "$SKILL is missing — the local checks have no criteria to read"
[ -f "$AGENT" ] || fail "$AGENT is missing — the local checks have no agent to read"

# The skill is a knowledge library, not an actor. A skill that acts is the one thing the
# layer rules forbid, and claude-seo's original shipped as user-invocable: true.
grep -Fq 'user-invocable: false' "$SKILL" \
  || fail "$SKILL does not declare user-invocable: false"

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
