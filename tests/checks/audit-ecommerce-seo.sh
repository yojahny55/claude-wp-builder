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
[ -s "$SKILL" ] || fail "$SKILL is readable but empty"
# The commerce assertions read only what belongs to SEO-064..068: their table rows plus their
# own procedure. A phrase that also appears elsewhere in the agent (UNMEASURED, site.commerce)
# must not satisfy a gate that the commerce text itself has dropped.
commerce_flat=$( { grep -E '^\| *SEO-06[4-8] *\|' "$AGENT" || true   # no rows: the per-code gate below names them
                   awk '/^### Procedure — commerce checks \(SEO-064 to SEO-068\)/ { f = 1; print; next }
                        f && /^(## |### )/ { exit }
                        f' "$AGENT"; } | tr '\n' ' ' | sed 's/  */ /g')
grep -Fq '### Procedure — commerce checks (SEO-064 to SEO-068)' <<< "$commerce_flat" \
  || fail "$AGENT has no '### Procedure — commerce checks (SEO-064 to SEO-068)' section for the gates to read"
# The heading proves only that extraction started. The last numbered step proves it ran to the
# end of the procedure instead of stopping at a stray subheading.
grep -Fq '8. **SEO-068** never fetches anything' <<< "$commerce_flat" \
  || fail "the commerce procedure extract is truncated — its last step (8. SEO-068) is missing"
# The agent must still send the reader to the skill, or the curl snippets below are orphaned.
grep -Fq 'Read `skills/wp-audit-seo-standards/SKILL.md` §18 before running these' <<< "$commerce_flat" \
  || fail "the commerce procedure no longer sends the reader to the skill's §18"

# --- all five codes exist, in the agent's check table -------------------------------------
for code in SEO-064 SEO-065 SEO-066 SEO-067 SEO-068; do
  grep -Fq "| $code |" "$AGENT" || fail "$AGENT has no table row for $code"
  # The row is what an agent reads when it scans the table, so each carries its own gate.
  grep -Eq "^\| *$code *\|[^|]*\| *WooCommerce only" "$AGENT" \
    || fail "$AGENT's $code row lost its WooCommerce-only gate"
done

# The skill carries the methodology section these codes point back to. Skill-side gates read
# §18 alone: phrases such as sitemap_index.xml also appear in earlier sections, and must not
# satisfy a gate §18 itself has dropped. §18 runs to the next top-level section or EOF.
grep -Fq '## 18. E-commerce SEO nuances' "$SKILL" \
  || fail "$SKILL has no e-commerce SEO section for SEO-064..SEO-068 to reference"
ecom=$(awk '/^## 18\. E-commerce SEO nuances/ { f = 1; print; next } f && /^## / { exit } f' "$SKILL")
[ -n "$ecom" ] || fail "$SKILL §18 extracted to nothing — the heading is present but not as a top-level '## 18.' section"
ecom_flat=$(tr -s '[:space:]' ' ' <<< "$ecom")

# Every curl in §18 is bounded on its own — a single bounded call elsewhere in the section must
# not cover a new unbounded one. Backslash-continued lines are joined first, and each command
# is cut from `curl -` to the next backtick or `|`, so a second curl sharing a line is its own
# entry and prose that merely says "curl" is not a command at all.
curls=$(sed -e ':a' -e '/\\$/N; s/\\\n//; ta' <<< "$ecom" | grep -oE 'curl +-[^`|]*' || true)
[ "$(grep -c . <<< "$curls")" -ge 5 ] || fail "$SKILL §18 lost its bounded curl fetches (fewer than 5 left)"
# Parity: every `curl` word in §18 must be one the extractor recognized. A fetch written URL-first
# (no leading dash flag) would otherwise escape the bound checks below entirely.
curl_words=$(grep -oE '(^|[^[:alnum:]_-])curl([^[:alnum:]_-]|$)' <<< "$ecom" | grep -c . || true)
[ "$curl_words" -eq "$(grep -c . <<< "$curls")" ] \
  || fail "$SKILL §18 mentions curl $curl_words times but only $(grep -c . <<< "$curls") are recognized commands — a fetch is escaping the bounded-curl guard"
while IFS= read -r c; do
  # Present is not enough: --max-time 0 means no timeout, and --max-redirs 0 never follows.
  grep -qE -- '--max-redirs[ =][1-9][0-9]*' <<< "$c" \
    || fail "$SKILL §18 has a curl without a positive --max-redirs: $c"
  grep -qE -- '--max-time[ =][1-9][0-9]*' <<< "$c" \
    || fail "$SKILL §18 has a curl without a positive --max-time: $c"
  # --max-redirs does nothing unless curl follows redirects; without -L every fetch reads the
  # empty 301 body and all four live checks turn UNMEASURED for good.
  # L anywhere in a short-option bundle (-L, -sL, -Ls, -fsSL) or the long form.
  grep -qE -- '(^|[[:space:]])-[^[:space:]-]*L|--location' <<< "$c" \
    || fail "$SKILL §18 has a curl that does not follow redirects (-L), so --max-redirs is inert: $c"
done <<< "$curls"

# --- gate: site.commerce, not a re-detection ------------------------------------------------
grep -Fq 'N/A ("no WooCommerce")' <<< "$commerce_flat" \
  || fail "the commerce checks do not report N/A (\"no WooCommerce\") on a non-commerce site"
grep -Fq 'site.commerce' <<< "$commerce_flat" \
  || fail "the commerce checks do not read site.commerce from /wp-audit Step 2.3"
grep -Fq 'Never re-detect WooCommerce' <<< "$commerce_flat" \
  || fail "the commerce checks re-detect WooCommerce instead of trusting Step 2.3's site.commerce"

# --- production host, never the clone, for the four checks that fetch a page --------------
grep -Fq 'target the production host, never the local clone' <<< "$ecom_flat" \
  || fail "the skill does not send the live commerce checks at the production host"
grep -Fq 'Production host, never the clone' <<< "$commerce_flat" \
  || fail "the agent does not repeat the production-host rule for the commerce checks"
grep -Fq 'With no public URL, the check is `UNMEASURED`, never `PASS`' <<< "$commerce_flat" \
  || fail "the commerce checks do not fall back to UNMEASURED without a public URL"

# --- SEO-064: faceted/filtered URL must NOT self-canonicalize ------------------------------
grep -Fq 'canonicalizing to itself tells Google every filter' <<< "$ecom_flat" \
  || fail "SEO-064 does not say a self-canonicalizing filtered URL is the defect"
# The skill wraps this sentence across two lines; $ecom_flat has newlines folded to spaces,
# so the whole clause is matched as one string.
grep -Fq 'Each variant should declare a canonical back at the clean category URL' <<< "$ecom_flat" \
  || fail "SEO-064 does not require the filtered URL's canonical to point at the clean category URL"
# A redirect must be followed (bounded), and an empty fetch is UNMEASURED, never a match/pass.
grep -Fq 'is `UNMEASURED`, never a match and never a pass' <<< "$ecom_flat" \
  || fail "SEO-064/18.1 does not say an empty canonical fetch is UNMEASURED rather than a match"

# --- SEO-065: category pagination — the inverted assumption, both directions --------------
# The wrong form: canonical to page 1 must be named as the defect for category pagination,
# not silently allowed the way SEO-038 allows it for a single post.
grep -Fq 'canonical back to page 1 is the defect' <<< "$commerce_flat" \
  || fail "SEO-065 does not name canonical-to-page-1 as the defect for category pagination"
grep -Fq 'Self-referencing is correct and required' <<< "$commerce_flat" \
  || fail "SEO-065 does not require self-referencing canonical on category page 2+"
# SEO-038's own allowance must still be intact — this PR narrows SEO-065, it does not touch
# SEO-038's rule for a paginated single post.
grep -Fq 'A paginated page canonicalising to page 1 is allowed' <<< "$agent_flat" \
  || fail "SEO-038's own pagination allowance was removed instead of left alone"
# ...and SEO-065 must say plainly that the allowance does not carry over to a category archive.
grep -Fq 'unlike a paginated single post' <<< "$ecom_flat" \
  || fail "SEO-065 does not say the SEO-038 pagination allowance does not extend to a category archive"
grep -Fq 'is not the same finding as a bare category URL' <<< "$ecom_flat" \
  || fail "SEO-065/18.2 does not say an empty canonical fetch is UNMEASURED rather than the page-1 defect"

# --- SEO-066: Offer.availability vs real stock — CRITICAL, and never a stale local query ---
grep -E '^\| *SEO-066 *\|.*\| *CRITICAL *\| *$' "$AGENT" >/dev/null \
  || fail "SEO-066 is not CRITICAL — a stale InStock claim is a manual-action risk, same tier as SEO-063"
grep -Fq 'never a WP-CLI stock query against the local database' <<< "$commerce_flat" \
  || fail "SEO-066 does not reject comparing availability against a possibly-stale local DB value"
grep -Fq 'next to an `outofstock` class from the same fetch is the finding' <<< "$ecom_flat" \
  || fail "SEO-066 does not name the rendered stock class it compares the schema claim against"
# The stock-class grep must be scoped to the MAIN product's own wrapper. Related products and
# up-sells go through the same wc_get_product_class() and carry their own stock class, so an
# unscoped grep can match a decoy product instead of the one the fetch is actually about.
grep -Fq 'related products and up-sells' <<< "$ecom_flat" \
  || fail "SEO-066 does not warn that related products/up-sells carry their own stock class"
grep -Fq 'id=\"product-$pid\"' <<< "$ecom_flat" \
  || fail "SEO-066's stock-class grep is not scoped to the main product's own wrapper id"
# The class alternation must be the real WooCommerce class names. (in|out)ofstock concatenates
# to "inofstock"/"outofstock" — it can never match the actual "instock" class, so the InStock
# side of the mismatch this check exists to catch was undetectable.
# Only command text is scanned — lines inside §18's fenced blocks that are not # comments — so
# the doc may still name the old alternation to warn against it.
ecom_code=$(awk '/^[[:space:]]*```/ { fence = !fence; next } fence && !/^[[:space:]]*#/' <<< "$ecom")
[ -n "$ecom_code" ] || fail "$SKILL §18 extracted no code lines — fence detection broke"
# SEO-064 compares the clean category URL with a filtered one, and SEO-065 fetches page 2; each
# needs its own fetch, which the curl count alone would not notice losing.
grep -Fq '/product-category/<slug>/?orderby=price' <<< "$ecom_code" \
  || fail "SEO-064 lost its filtered-URL fetch (?orderby=price) — there is nothing to compare the clean URL against"
grep -Fq '/product-category/<slug>/page/2/' <<< "$ecom_code" \
  || fail "SEO-065 lost its page-2 fetch"
if grep -Fq '(in|out)ofstock' <<< "$ecom_code"; then
  fail "SEO-066 still uses the (in|out)ofstock alternation, which can never match WooCommerce's real 'instock' class"
fi
grep -Fq 'instock|outofstock|onbackorder' <<< "$ecom_flat" \
  || fail "SEO-066 does not match the real WooCommerce stock class names"
grep -Fq 'never read as "no mismatch found."' <<< "$ecom_flat" \
  || fail "SEO-066/18.3 does not say a missing schema/stock signal is UNMEASURED, not a pass"

# --- SEO-067: sitemap vs noindex contradiction ---------------------------------------------
grep -Fq 'contradictory signals for the same page' <<< "$commerce_flat" \
  || fail "SEO-067 does not call a sitemap-listed, noindexed URL a contradictory signal"
# Large catalogs split the product sitemap into numbered files and redirect the bare name to
# the first one; a fetch without -L or without reading the index silently checks nothing.
grep -Fq 'sitemap_index.xml' <<< "$ecom_flat" \
  || fail "SEO-067 does not read the sitemap index to find the numbered product-sitemap files"
# The primary method must be a local WP-CLI comparison, not a live fetch of every sitemap URL
# — a catalog-sized sitemap otherwise means a catalog-sized number of production requests.
grep -Fq 'Primary method is a WP-CLI database comparison' <<< "$commerce_flat" \
  || fail "SEO-067 does not name the WP-CLI database comparison as its primary method"
grep -Fq 'Primary method: compare locally via WP-CLI' <<< "$ecom_flat" \
  || fail "SEO-067's skill methodology does not lead with the WP-CLI comparison"
grep -Fq 'does not scale' <<< "$commerce_flat" \
  || fail "SEO-067 does not say why a live fetch per sitemap URL does not scale"
# Category coverage: product_cat, not just products, and Yoast's real storage shape for both
# levels (post meta for a post; the wpseo_taxonomy_meta OPTION, not term meta, for a term).
grep -Fq 'product-category URLs' <<< "$commerce_flat" \
  || fail "SEO-067's table row narrowed back to products only"
grep -Fq 'product_cat-sitemap.xml' <<< "$ecom_flat" \
  || fail "SEO-067 does not read the product_cat taxonomy sitemap"
grep -Fq '_yoast_wpseo_meta-robots-noindex' <<< "$ecom_flat" \
  || fail "SEO-067 dropped the Yoast post-level noindex fallback"
grep -Fq 'wpseo_taxonomy_meta' <<< "$ecom_flat" \
  || fail "SEO-067's Yoast term-level fallback reads term meta instead of the wpseo_taxonomy_meta option Yoast actually uses"
# The option name alone is satisfied by a mention; pin the lookup that reads the term's flag.
grep -Fq "tax_meta['product_cat'][" <<< "$ecom_code" \
  || fail "SEO-067 names wpseo_taxonomy_meta but no longer looks up the product_cat term inside it"
grep -Fq "['wpseo_noindex']" <<< "$ecom_code" \
  || fail "SEO-067's term-level lookup does not read Yoast's wpseo_noindex flag"
# The WP-CLI pass must actually PRODUCE the unresolved-URL file the fallback reads — a
# fallback pointed at a file nothing writes silently checks zero URLs.
grep -Fq "fopen('/tmp/sitemap-urls-unresolved.txt', 'w')" <<< "$ecom_flat" \
  || fail "SEO-067's WP-CLI pass does not open the unresolved-URL file its own fallback reads"
grep -Fq 'fwrite(\$unresolved' <<< "$ecom_flat" \
  || fail "SEO-067's WP-CLI pass opens the unresolved-URL file but never writes an unresolved URL to it"
# Any HTTP that remains (sitemap files themselves, and the fallback for URLs the DB comparison
# could not resolve) must be explicitly capped, not open-ended.
grep -Fq 'head -n 50 > /tmp/product-sitemaps.txt' <<< "$ecom_flat" \
  || fail "SEO-067 does not cap the sitemap-FILE list itself at 50, independent of the fallback cap"
grep -Fq 'head -n 50 /tmp/sitemap-urls-unresolved.txt' <<< "$ecom_flat" \
  || fail "SEO-067's fallback does not cap the unresolved-URL list at 50, independent of the sitemap-file cap"
grep -Fq 'capped at 50' <<< "$commerce_flat" \
  || fail "SEO-067's procedure does not state the 50-item cap on sitemap files and the fallback"
# A body-text `grep -qi noindex` over the whole page false-positives on the word inside a
# comment/script and misses a page noindexed only via the X-Robots-Tag header. Both signals
# must be read, and the meta check must be anchored to the actual robots tag. This survives
# only in the fallback path now, but the anchoring must still hold there.
grep -Fq 'X-Robots-Tag' <<< "$ecom_flat" \
  || fail "SEO-067 does not check the X-Robots-Tag response header"
grep -Fq 'Anchor to the actual robots meta tag' <<< "$ecom_flat" \
  || fail "SEO-067's meta check is not anchored to the robots meta tag"
grep -Fq 'tolerate attribute order and' <<< "$ecom_flat" \
  || fail "SEO-067's meta check does not tolerate attribute order (content before name)"
# The prose above can survive a code change; pin the operative patterns in the commands too.
grep -Fq "grep -qiE '^X-Robots-Tag:.*noindex'" <<< "$ecom_code" \
  || fail "SEO-067 no longer tests the X-Robots-Tag header for noindex"
meta_needle=$'grep -oiE \'<meta[^>]+>\' /tmp/sitemap-url-body.html | grep -i \'name=["'
grep -Fq "$meta_needle" <<< "$ecom_code" \
  || fail "SEO-067's meta check is no longer anchored to the robots <meta> tag"

# --- SEO-068: migration reminder — warning-level, no fetch ---------------------------------
grep -Fq 'Not a live fetch' <<< "$commerce_flat" \
  || fail "SEO-068 is not marked as a non-fetching, reminder-only check"
grep -Fq 'Reviews and `AggregateRating`** disappear from the schema' <<< "$ecom_flat" \
  || fail "SEO-068 does not name the lost AggregateRating as one of the two migration risks"
grep -Fq 'soft 404' <<< "$ecom_flat" \
  || fail "SEO-068 does not warn that a blanket redirect to the home page reads as a soft 404"
grep -E '^\| *SEO-068 *\|.*\| *WARNING *\| *$' "$AGENT" >/dev/null \
  || fail "SEO-068 is not WARNING severity, as specified for the migration reminder"

echo "PASS: SEO-064..SEO-068 are gated by site.commerce, target production not the clone, and SEO-065 does not inherit SEO-038's page-1 allowance"
