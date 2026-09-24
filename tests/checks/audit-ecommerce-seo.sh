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
set -euo pipefail

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
# The commerce assertions read only what belongs to SEO-064..068: their table rows plus their
# own procedure. A phrase that also appears elsewhere in the agent (UNMEASURED, site.commerce)
# must not satisfy a gate that the commerce text itself has dropped.
commerce_flat=$( { grep -E '^\| *SEO-06[4-8] *\|' "$AGENT"
                   awk '/^### Procedure — commerce checks \(SEO-064 to SEO-068\)/ { f = 1; print; next }
                        f && /^##/ { exit }
                        f' "$AGENT"; } | tr '\n' ' ' | sed 's/  */ /g')
printf '%s' "$commerce_flat" | grep -Fq '### Procedure — commerce checks (SEO-064 to SEO-068)' \
  || fail "$AGENT has no '### Procedure — commerce checks (SEO-064 to SEO-068)' section for the gates to read"

# --- all five codes exist, in the agent's check table -------------------------------------
for code in SEO-064 SEO-065 SEO-066 SEO-067 SEO-068; do
  grep -Fq "| $code |" "$AGENT" || fail "$AGENT has no table row for $code"
done

# The skill carries the methodology section these codes point back to.
grep -Fq '## 18. E-commerce SEO nuances' "$SKILL" \
  || fail "$SKILL has no e-commerce SEO section for SEO-064..SEO-068 to reference"

# --- gate: site.commerce, not a re-detection ------------------------------------------------
printf '%s' "$commerce_flat" | grep -Fq 'N/A ("no WooCommerce")' \
  || fail "the commerce checks do not report N/A (\"no WooCommerce\") on a non-commerce site"
printf '%s' "$commerce_flat" | grep -Fq 'site.commerce' \
  || fail "the commerce checks do not read site.commerce from /wp-audit Step 2.3"
printf '%s' "$commerce_flat" | grep -Fq 'Never re-detect WooCommerce' \
  || fail "the commerce checks re-detect WooCommerce instead of trusting Step 2.3's site.commerce"

# --- production host, never the clone, for the four checks that fetch a page --------------
printf '%s' "$skill_flat" | grep -Fq 'target the production host, never the local clone' \
  || fail "the skill does not send the live commerce checks at the production host"
printf '%s' "$commerce_flat" | grep -Fq 'Production host, never the clone' \
  || fail "the agent does not repeat the production-host rule for the commerce checks"
printf '%s' "$commerce_flat" | grep -Fq 'With no public URL, the check is `UNMEASURED`, never `PASS`' \
  || fail "the commerce checks do not fall back to UNMEASURED without a public URL"

# --- SEO-064: faceted/filtered URL must NOT self-canonicalize ------------------------------
printf '%s' "$skill_flat" | grep -Fq 'canonicalizing to itself tells Google every filter' \
  || fail "SEO-064 does not say a self-canonicalizing filtered URL is the defect"
printf '%s' "$skill_flat" | grep -Fq 'canonical back at the clean category URL' \
  || fail "SEO-064 does not require the filtered URL's canonical to point at the clean category URL"
# A redirect must be followed (bounded), and an empty fetch is UNMEASURED, never a match/pass.
printf '%s' "$skill_flat" | grep -Fq -- '--max-redirs 3 --max-time 15' \
  || fail "the §18 fetches do not bound -L with --max-redirs/--max-time"
printf '%s' "$skill_flat" | grep -Fq 'is `UNMEASURED`, never a match and never a pass' \
  || fail "SEO-064/18.1 does not say an empty canonical fetch is UNMEASURED rather than a match"

# --- SEO-065: category pagination — the inverted assumption, both directions --------------
# The wrong form: canonical to page 1 must be named as the defect for category pagination,
# not silently allowed the way SEO-038 allows it for a single post.
printf '%s' "$commerce_flat" | grep -Fq 'canonical back to page 1 is the defect' \
  || fail "SEO-065 does not name canonical-to-page-1 as the defect for category pagination"
printf '%s' "$commerce_flat" | grep -Fq 'Self-referencing is correct and required' \
  || fail "SEO-065 does not require self-referencing canonical on category page 2+"
# SEO-038's own allowance must still be intact — this PR narrows SEO-065, it does not touch
# SEO-038's rule for a paginated single post.
printf '%s' "$agent_flat" | grep -Fq 'A paginated page canonicalising to page 1 is allowed' \
  || fail "SEO-038's own pagination allowance was removed instead of left alone"
# ...and SEO-065 must say plainly that the allowance does not carry over to a category archive.
printf '%s' "$skill_flat" | grep -Fq 'unlike a paginated single post' \
  || fail "SEO-065 does not say the SEO-038 pagination allowance does not extend to a category archive"
printf '%s' "$skill_flat" | grep -Fq 'is not the same finding as a bare category URL' \
  || fail "SEO-065/18.2 does not say an empty canonical fetch is UNMEASURED rather than the page-1 defect"

# --- SEO-066: Offer.availability vs real stock — CRITICAL, and never a stale local query ---
grep -E '^\| *SEO-066 *\|.*\| *CRITICAL *\| *$' "$AGENT" >/dev/null \
  || fail "SEO-066 is not CRITICAL — a stale InStock claim is a manual-action risk, same tier as SEO-063"
printf '%s' "$commerce_flat" | grep -Fq 'never a WP-CLI stock query against the local database' \
  || fail "SEO-066 does not reject comparing availability against a possibly-stale local DB value"
printf '%s' "$skill_flat" | grep -Fq 'next to an `outofstock` class from the same fetch is the finding' \
  || fail "SEO-066 does not name the rendered stock class it compares the schema claim against"
# The stock-class grep must be scoped to the MAIN product's own wrapper. Related products and
# up-sells go through the same wc_get_product_class() and carry their own stock class, so an
# unscoped grep can match a decoy product instead of the one the fetch is actually about.
printf '%s' "$skill_flat" | grep -Fq 'related products and up-sells' \
  || fail "SEO-066 does not warn that related products/up-sells carry their own stock class"
printf '%s' "$skill_flat" | grep -Fq 'id=\"product-$pid\"' \
  || fail "SEO-066's stock-class grep is not scoped to the main product's own wrapper id"
# The class alternation must be the real WooCommerce class names. (in|out)ofstock concatenates
# to "inofstock"/"outofstock" — it can never match the actual "instock" class, so the InStock
# side of the mismatch this check exists to catch was undetectable.
if printf '%s' "$skill_flat" | grep -Fq '(in|out)ofstock'; then
  fail "SEO-066 still uses the (in|out)ofstock alternation, which can never match WooCommerce's real 'instock' class"
fi
printf '%s' "$skill_flat" | grep -Fq 'instock|outofstock|onbackorder' \
  || fail "SEO-066 does not match the real WooCommerce stock class names"
printf '%s' "$skill_flat" | grep -Fq 'never read as "no mismatch found."' \
  || fail "SEO-066/18.3 does not say a missing schema/stock signal is UNMEASURED, not a pass"

# --- SEO-067: sitemap vs noindex contradiction ---------------------------------------------
printf '%s' "$commerce_flat" | grep -Fq 'contradictory signals for the same page' \
  || fail "SEO-067 does not call a sitemap-listed, noindexed URL a contradictory signal"
# Large catalogs split the product sitemap into numbered files and redirect the bare name to
# the first one; a fetch without -L or without reading the index silently checks nothing.
printf '%s' "$skill_flat" | grep -Fq 'sitemap_index.xml' \
  || fail "SEO-067 does not read the sitemap index to find the numbered product-sitemap files"
# The primary method must be a local WP-CLI comparison, not a live fetch of every sitemap URL
# — a catalog-sized sitemap otherwise means a catalog-sized number of production requests.
printf '%s' "$commerce_flat" | grep -Fq 'Primary method is a WP-CLI database comparison' \
  || fail "SEO-067 does not name the WP-CLI database comparison as its primary method"
printf '%s' "$skill_flat" | grep -Fq 'Primary method: compare locally via WP-CLI' \
  || fail "SEO-067's skill methodology does not lead with the WP-CLI comparison"
printf '%s' "$commerce_flat" | grep -Fq 'does not scale' \
  || fail "SEO-067 does not say why a live fetch per sitemap URL does not scale"
# Category coverage: product_cat, not just products, and Yoast's real storage shape for both
# levels (post meta for a post; the wpseo_taxonomy_meta OPTION, not term meta, for a term).
printf '%s' "$commerce_flat" | grep -Fq 'product-category URLs' \
  || fail "SEO-067's table row narrowed back to products only"
printf '%s' "$skill_flat" | grep -Fq 'product_cat-sitemap.xml' \
  || fail "SEO-067 does not read the product_cat taxonomy sitemap"
printf '%s' "$skill_flat" | grep -Fq '_yoast_wpseo_meta-robots-noindex' \
  || fail "SEO-067 dropped the Yoast post-level noindex fallback"
printf '%s' "$skill_flat" | grep -Fq 'wpseo_taxonomy_meta' \
  || fail "SEO-067's Yoast term-level fallback reads term meta instead of the wpseo_taxonomy_meta option Yoast actually uses"
# The WP-CLI pass must actually PRODUCE the unresolved-URL file the fallback reads — a
# fallback pointed at a file nothing writes silently checks zero URLs.
printf '%s' "$skill_flat" | grep -Fq "fopen('/tmp/sitemap-urls-unresolved.txt', 'w')" \
  || fail "SEO-067's WP-CLI pass does not open the unresolved-URL file its own fallback reads"
printf '%s' "$skill_flat" | grep -Fq 'fwrite(\$unresolved' \
  || fail "SEO-067's WP-CLI pass opens the unresolved-URL file but never writes an unresolved URL to it"
# Any HTTP that remains (sitemap files themselves, and the fallback for URLs the DB comparison
# could not resolve) must be explicitly capped, not open-ended.
printf '%s' "$skill_flat" | grep -Fq 'head -n 50 > /tmp/product-sitemaps.txt' \
  || fail "SEO-067 does not cap the sitemap-FILE list itself at 50, independent of the fallback cap"
printf '%s' "$skill_flat" | grep -Fq 'head -n 50 /tmp/sitemap-urls-unresolved.txt' \
  || fail "SEO-067's fallback does not cap the unresolved-URL list at 50, independent of the sitemap-file cap"
printf '%s' "$commerce_flat" | grep -Fq 'capped at 50' \
  || fail "SEO-067's procedure does not state the 50-item cap on sitemap files and the fallback"
# A body-text `grep -qi noindex` over the whole page false-positives on the word inside a
# comment/script and misses a page noindexed only via the X-Robots-Tag header. Both signals
# must be read, and the meta check must be anchored to the actual robots tag. This survives
# only in the fallback path now, but the anchoring must still hold there.
printf '%s' "$skill_flat" | grep -Fq 'X-Robots-Tag' \
  || fail "SEO-067 does not check the X-Robots-Tag response header"
printf '%s' "$skill_flat" | grep -Fq 'Anchor to the actual robots meta tag' \
  || fail "SEO-067's meta check is not anchored to the robots meta tag"
printf '%s' "$skill_flat" | grep -Fq 'tolerate attribute order and' \
  || fail "SEO-067's meta check does not tolerate attribute order (content before name)"

# --- SEO-068: migration reminder — warning-level, no fetch ---------------------------------
printf '%s' "$commerce_flat" | grep -Fq 'Not a live fetch' \
  || fail "SEO-068 is not marked as a non-fetching, reminder-only check"
printf '%s' "$skill_flat" | grep -Fq 'Reviews and `AggregateRating`** disappear from the schema' \
  || fail "SEO-068 does not name the lost AggregateRating as one of the two migration risks"
printf '%s' "$skill_flat" | grep -Fq 'soft 404' \
  || fail "SEO-068 does not warn that a blanket redirect to the home page reads as a soft 404"
grep -E '^\| *SEO-068 *\|.*\| *WARNING *\| *$' "$AGENT" >/dev/null \
  || fail "SEO-068 is not WARNING severity, as specified for the migration reminder"

echo "PASS: SEO-064..SEO-068 are gated by site.commerce, target production not the clone, and SEO-065 does not inherit SEO-038's page-1 allowance"
