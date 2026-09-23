#!/usr/bin/env bash
# Five WooCommerce-only SEO checks (SEO-064..SEO-068), gated by the `site.commerce` flag
# `/wp-audit` Step 2.3 already computes. Two ways this drifts silently, both worth pinning:
#
#   1. The gate. Without "N/A (\"no WooCommerce\")" and a rule against re-detecting commerce,
#      these checks fire on every blog and score it for a cart it never had — the exact
#      regression the base PR (site-type gating) exists to prevent.
#   2. SEO-065 inverts what SEO-038 says elsewhere in the SAME agent file. SEO-038's own
#      procedure allows a paginated page to canonicalize to page 1 (true for a single post
#      split with <!--nextpage-->). Read on its own and misapplied to a WooCommerce category
#      archive, that would tell you page-1 canonical is fine there too — it is the classic
#      mistake that drops page-2+ products from the index. SEO-065 must say the opposite for
#      category pagination, so this test asserts BOTH readings survive: SEO-038's allowance
#      stays put, and SEO-065 explicitly does not extend it to category archives.
#
# Grepping the exact wording is this repo's house style: a failure here means the sentence
# changed, not that the code broke. Reword one on purpose and update its line in the same
# commit, so a reviewer sees both halves of the change at once.
set -uo pipefail

fail() { echo "FAIL: $1"; exit 1; }

cd "$(dirname "$0")/../.." || fail "cannot cd to the repository root"

AGENT="agents/wp-audit-seo.md"
SKILL="skills/wp-audit-seo-standards/SKILL.md"

[ -f "$AGENT" ] || fail "$AGENT is missing"
[ -r "$AGENT" ] || fail "$AGENT exists but cannot be read"
[ -f "$SKILL" ] || fail "$SKILL is missing"
[ -r "$SKILL" ] || fail "$SKILL exists but cannot be read"

agent_flat=$(tr '\n' ' ' < "$AGENT" | sed 's/  */ /g') || fail "could not read $AGENT"
[ -n "$agent_flat" ] || fail "$AGENT flattened to nothing — it was readable and is now empty"
skill_flat=$(tr '\n' ' ' < "$SKILL" | sed 's/  */ /g') || fail "could not read $SKILL"
[ -n "$skill_flat" ] || fail "$SKILL flattened to nothing — it was readable and is now empty"

# --- all five codes exist, in the agent's check table -------------------------------------
for code in SEO-064 SEO-065 SEO-066 SEO-067 SEO-068; do
  grep -Fq "| $code |" "$AGENT" || fail "$AGENT has no table row for $code"
done

# The skill carries the methodology section these codes point back to.
grep -Fq '## 18. E-commerce SEO nuances' "$SKILL" \
  || fail "$SKILL has no e-commerce SEO section for SEO-064..SEO-068 to reference"

# --- gate: site.commerce, not a re-detection ------------------------------------------------
printf '%s' "$agent_flat" | grep -Fq 'N/A ("no WooCommerce")' \
  || fail "the commerce checks do not report N/A (\"no WooCommerce\") on a non-commerce site"
printf '%s' "$agent_flat" | grep -Fq 'site.commerce' \
  || fail "the commerce checks do not read site.commerce from /wp-audit Step 2.3"
printf '%s' "$agent_flat" | grep -Fq 'Never re-detect WooCommerce' \
  || fail "the commerce checks re-detect WooCommerce instead of trusting Step 2.3's site.commerce"

# --- production host, never the clone, for the four checks that fetch a page --------------
printf '%s' "$skill_flat" | grep -Fq 'target the production host, never the local clone' \
  || fail "the skill does not send the live commerce checks at the production host"
printf '%s' "$agent_flat" | grep -Fq 'Production host, never the clone' \
  || fail "the agent does not repeat the production-host rule for the commerce checks"
printf '%s' "$agent_flat" | grep -Fq 'UNMEASURED' \
  || fail "the commerce checks do not fall back to UNMEASURED without a public URL"

# --- SEO-064: faceted/filtered URL must NOT self-canonicalize ------------------------------
printf '%s' "$skill_flat" | grep -Fq 'canonicalizing to itself tells Google every filter' \
  || fail "SEO-064 does not say a self-canonicalizing filtered URL is the defect"
printf '%s' "$skill_flat" | grep -Fq 'canonical back at the clean category URL' \
  || fail "SEO-064 does not require the filtered URL's canonical to point at the clean category URL"

# --- SEO-065: category pagination — the inverted assumption, both directions --------------
# The wrong form: canonical to page 1 must be named as the defect for category pagination,
# not silently allowed the way SEO-038 allows it for a single post.
printf '%s' "$agent_flat" | grep -Fq 'canonical back to page 1 is the defect' \
  || fail "SEO-065 does not name canonical-to-page-1 as the defect for category pagination"
printf '%s' "$agent_flat" | grep -Fq 'Self-referencing is correct and required' \
  || fail "SEO-065 does not require self-referencing canonical on category page 2+"
# SEO-038's own allowance must still be intact — this PR narrows SEO-065, it does not touch
# SEO-038's rule for a paginated single post.
printf '%s' "$agent_flat" | grep -Fq 'A paginated page canonicalising to page 1 is allowed' \
  || fail "SEO-038's own pagination allowance was removed instead of left alone"
# ...and SEO-065 must say plainly that the allowance does not carry over to a category archive.
printf '%s' "$skill_flat" | grep -Fq 'unlike a paginated single post' \
  || fail "SEO-065 does not say the SEO-038 pagination allowance does not extend to a category archive"

# --- SEO-066: Offer.availability vs real stock — CRITICAL, and never a stale local query ---
grep -E '^\| *SEO-066 *\|.*\| *CRITICAL *\| *$' "$AGENT" >/dev/null \
  || fail "SEO-066 is not CRITICAL — a stale InStock claim is a manual-action risk, same tier as SEO-063"
printf '%s' "$agent_flat" | grep -Fq 'never a WP-CLI stock query against the local database' \
  || fail "SEO-066 does not reject comparing availability against a possibly-stale local DB value"
printf '%s' "$skill_flat" | grep -Fq 'outofstock' \
  || fail "SEO-066 does not name the rendered stock class it compares the schema claim against"

# --- SEO-067: sitemap vs noindex contradiction ---------------------------------------------
printf '%s' "$agent_flat" | grep -Fq 'contradictory signals for the same page' \
  || fail "SEO-067 does not call a sitemap-listed, noindexed URL a contradictory signal"

# --- SEO-068: migration reminder — warning-level, no fetch ---------------------------------
printf '%s' "$agent_flat" | grep -Fq 'Not a live fetch' \
  || fail "SEO-068 is not marked as a non-fetching, reminder-only check"
printf '%s' "$skill_flat" | grep -Fq 'AggregateRating' \
  || fail "SEO-068 does not name the lost AggregateRating as one of the two migration risks"
printf '%s' "$skill_flat" | grep -Fq 'soft 404' \
  || fail "SEO-068 does not warn that a blanket redirect to the home page reads as a soft 404"
grep -E '^\| *SEO-068 *\|.*\| *WARNING *\| *$' "$AGENT" >/dev/null \
  || fail "SEO-068 is not WARNING severity, as specified for the migration reminder"

echo "PASS: SEO-064..SEO-068 are gated by site.commerce, target production not the clone, and SEO-065 does not inherit SEO-038's page-1 allowance"
