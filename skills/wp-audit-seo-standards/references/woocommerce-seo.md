# WooCommerce SEO checks

Part of the `wp-audit-seo-standards` skill; section numbers match its SKILL.md.

## Contents

- 18. E-commerce SEO nuances — the `site.commerce` gate and the production-host rule
- 18.1 Faceted/filtered URLs canonicalizing to themselves (SEO-064)
- 18.2 Paginated category pages canonicalizing to page 1 (SEO-065)
- 18.3 `Offer.availability` disagreeing with real stock (SEO-066)
- 18.4 Sitemap listing a noindexed URL (SEO-067)
- 18.5 Post-migration reminder: reviews and the 301 map (SEO-068)

## 18. E-commerce SEO nuances (WooCommerce)

Read this section only when `/wp-audit` Step 2.3 sets `site.commerce` to `woocommerce`; every
check below is `N/A ("no WooCommerce")` and out of the denominator otherwise — never
re-detect commerce here, Step 2.3 already did it. These are failure modes that only exist
because the site is a store rather than a blog: faceted navigation multiplies category URLs,
paginated archives can hide inventory instead of content, and stock is a fact the page can
contradict itself about. They complement SEO-038 (canonical self-reference) and SEO-039
(duplicate schema source), which already cover the generic cases.

All four checks that read a live page target the production host, never the local clone —
same rule as the rendered-head snapshot: per `/wp-audit` Step 2.3, when the project is a local
clone (`local_clone = true`), use `--host` if given, otherwise ask the user for
`production_url` (defaulting to `wordpress.url_origin`) and fire no request until it is
confirmed. With no public URL, report `UNMEASURED`, never `PASS` — a local Apache honors a
`.htaccess` rule a production Nginx ignores, which would turn a real defect into a false pass.

### 18.1 Faceted/filtered URLs canonicalizing to themselves (SEO-064)

Attribute and sort filters (`?filter_color=red`, `?orderby=price`, `?min_price=`) generate
near-infinite variants of one category page. Each variant should declare a canonical back at
the clean category URL. A filtered URL canonicalizing to itself tells Google every filter
combination is a distinct page worth crawling and indexing — the opposite of the intent.

```bash
# -L (bounded) follows a redirect instead of returning an empty body for it; a redirect is not
# the same fact as a canonical tag, so it must not be silently mistaken for either a match or
# a miss.
curl -sL --max-redirs 3 --max-time 15 "https://<production-host>/product-category/<slug>/" \
  | grep -o '<link rel="canonical"[^>]*>'
curl -sL --max-redirs 3 --max-time 15 "https://<production-host>/product-category/<slug>/?orderby=price" \
  | grep -o '<link rel="canonical"[^>]*>'
```

Both must print the same clean URL. If the filtered fetch prints its own `?orderby=price` URL,
that is the defect. A `noindex` on the filtered variant is an acceptable alternative to a
canonical redirect — but the store needs **one** strategy applied consistently, not a
canonical on some filters and a bare noindex on others.

No output from either fetch — a redirect loop, a timeout, or a page with no canonical tag at
all — is `UNMEASURED`, never a match and never a pass. An absent canonical is a different
finding from a self-referencing one, and both require the fetch to have actually returned a
page to say anything at all.

### 18.2 Paginated category pages canonicalizing to page 1 (SEO-065)

The opposite mistake from 18.1. Category pagination (`/product-category/<slug>/page/2/`) must
be **self-referencing** — canonical to page 1 is the classic error and, unlike a paginated
single post, is never the correct default here: it tells Google the products listed only on
page 2+ do not exist, and they drop out of the index entirely. Self-canonicalizing page 2+ is
the required, not merely tolerated, behavior for a WooCommerce category archive.

```bash
curl -sL --max-redirs 3 --max-time 15 "https://<production-host>/product-category/<slug>/page/2/" \
  | grep -o '<link rel="canonical"[^>]*>'
# Must contain .../page/2/ — a bare category URL here is the SEO-065 defect.
```

No output — the same UNMEASURED rule as 18.1 — is not the same finding as a bare category URL:
a page that returned nothing said nothing about its canonical, defect or otherwise.

### 18.3 `Offer.availability` disagreeing with real stock (SEO-066)

```bash
curl -sL --max-redirs 3 --max-time 15 "https://<production-host>/product/<slug>/" \
  | tr '\n' ' ' > /tmp/product.html
grep -o '"@type":"Product".*"availability":"[^"]*"' /tmp/product.html
# Scope to the MAIN product's own wrapper, not the whole page: related products and up-sells
# (rendered after the summary via `woocommerce_after_single_product_summary`) go through the
# same wc_get_product_class() and carry their own in/out-of-stock class, so an unscoped grep
# picks up whichever product in those sections happens to match first. The main wrapper's id
# is `product-<post ID>`, and the post ID is on <body class="... postid-<ID> ...">.
pid=$(grep -oE 'postid-[0-9]+' /tmp/product.html | head -1 | grep -oE '[0-9]+')
grep -oE "<div[^>]*id=\"product-$pid\"[^>]*>" /tmp/product.html | head -1 \
  | grep -oE '\b(instock|outofstock|onbackorder)\b'
```

No output from either grep — an empty body, a schema block that never rendered, or a wrapper
markup this pattern does not recognize — is `UNMEASURED`, never read as "no mismatch found."
A missing signal and a confirmed non-mismatch are different findings; only the second one is
a pass.

`https://schema.org/InStock` next to an `outofstock` class from the same fetch is the finding.
Compare against the page's own rendered signal, not a WP-CLI stock query against the local
database — a live availability claim compared with a possibly-stale clone value would flag
stock that already changed in production. This is not cosmetic: Google has taken manual action
against Product-schema spam before, and a stale `InStock` claim on a page the visitor sees
marked "Out of stock" is exactly that shape of mismatch.

### 18.4 Sitemap listing a noindexed URL (SEO-067)

A product can be discontinued and noindexed while the XML sitemap generator has not yet
regenerated and still lists it — indexed in the sitemap, excluded by the tag, two opposite
signals for the same URL. Covers both products (`product-sitemap*.xml`) and product
categories (`product_cat-sitemap.xml`, off by default in Rank Math's sitemap settings —
`tax_product_cat_sitemap`; only present when the store turned it on).

**Primary method: compare locally via WP-CLI, the same way SKILL.md §15 #4 already does for this exact
failure mode.** Fetching every sitemap FILE is cheap — a handful of requests even for a large
catalog, since each file holds hundreds of URLs — but fetching every individual product or
category PAGE to read its own robots signal does not scale: a catalog with a few thousand
products means a few thousand live requests for one check. Read the noindex signal from the
database instead of the rendered page for every URL that resolves locally.

```bash
# Read every product- and product_cat-sitemap entry from the index; -L (bounded) follows the
# 301/302 Rank Math puts on the bare, unnumbered filename once a catalog is large enough to
# split into product-sitemap1.xml, product-sitemap2.xml, ... — a fetch without -L, or one that
# guesses a single filename instead of reading the index, silently checks nothing.
# Cap at 50 sitemap FILES (not URLs): a pathologically large catalog could still produce
# hundreds of sitemap files, and this loop must stay bounded regardless of catalog size.
curl -sL --max-redirs 3 --max-time 15 "https://<production-host>/sitemap_index.xml" \
  | grep -oE '<loc>[^<]*(product|product_cat)-sitemap[^<]*</loc>' | sed 's/<[^>]*>//g' \
  | head -n 50 > /tmp/product-sitemaps.txt
: > /tmp/sitemap-urls.txt
while read -r sm; do
  curl -sL --max-redirs 3 --max-time 15 "$sm" \
    | grep -oE '<loc>[^<]+</loc>' | sed 's/<[^>]*>//g' >> /tmp/sitemap-urls.txt
done < /tmp/product-sitemaps.txt
```

```bash
$WP eval "
\$urls = file('/tmp/sitemap-urls.txt', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
\$tax_meta   = get_option('wpseo_taxonomy_meta', []); // Yoast fallback for term-level robots.
\$unresolved = fopen('/tmp/sitemap-urls-unresolved.txt', 'w');
foreach (\$urls as \$url) {
    \$noindex  = false;
    \$resolved = false;
    \$post_id  = url_to_postid(\$url);
    if (\$post_id) {
        \$resolved = true;
        \$rm = get_post_meta(\$post_id, 'rank_math_robots', true);
        \$noindex = is_array(\$rm) && in_array('noindex', \$rm, true);
        if (!\$noindex) {
            // Yoast stores this as real post meta; confirmed against the Rank Math Yoast
            // importer, which reads the same key when migrating a site off Yoast.
            \$noindex = '1' === get_post_meta(\$post_id, '_yoast_wpseo_meta-robots-noindex', true);
        }
    } else {
        \$path  = trim((string) wp_parse_url(\$url, PHP_URL_PATH), '/');
        \$parts = explode('/', \$path);
        \$slug  = end(\$parts);
        \$term  = get_term_by('slug', \$slug, 'product_cat');
        if (\$term) {
            \$resolved = true;
            \$rm = get_term_meta(\$term->term_id, 'rank_math_robots', true);
            \$noindex = is_array(\$rm) && in_array('noindex', \$rm, true);
            if (!\$noindex) {
                // Yoast never wrote real term meta for this — it lives in the
                // wpseo_taxonomy_meta option, keyed by taxonomy then term ID. Confirmed
                // against the same Rank Math Yoast importer (its termmeta() step).
                \$field = \$tax_meta['product_cat'][\$term->term_id]['wpseo_noindex'] ?? '';
                \$noindex = 'noindex' === \$field;
            }
        }
    }
    if (!\$resolved) {
        fwrite(\$unresolved, \$url . \"\n\");
        continue;
    }
    if (\$noindex) {
        echo \"SITEMAP+NOINDEX (DB): \$url\n\";
    }
}
fclose(\$unresolved);
"
```

A URL that resolves to neither a post nor a `product_cat` term (rare for these two sitemaps,
but possible after a slug change) has nothing to compare and is simply skipped here, not
counted as a pass — note it and fall back to the bounded HTTP method below only for that
handful of unresolved URLs, never for the whole list.

**Fallback, and only for URLs the WP-CLI pass could not resolve:** the same signals as before
— `X-Robots-Tag` header, then the anchored `<meta name="robots">` tag — over an explicitly
capped sample (`head -n 50` of the unresolved list, not the full sitemap), because reading the
live page is exactly the per-URL cost the primary method exists to avoid.

```bash
head -n 50 /tmp/sitemap-urls-unresolved.txt | while read -r u; do
  # A body-text `grep -qi noindex` over the whole page false-positives on the word inside a
  # comment, inline JS or a consent-banner string, and false-negatives a page noindexed only
  # via the `X-Robots-Tag` response header (no meta tag at all). Read headers and body in the
  # same fetch, then check both signals.
  headers=$(curl -sL --max-redirs 3 --max-time 15 -D - -o /tmp/sitemap-url-body.html "$u")
  if printf '%s' "$headers" | grep -qiE '^X-Robots-Tag:.*noindex'; then
    echo "SITEMAP+NOINDEX (X-Robots-Tag): $u"
    continue
  fi
  # Anchor to the actual robots meta tag, not the bare word, and tolerate attribute order and
  # quote style: `<meta name="robots" content="noindex,...">` and
  # `<meta content='noindex,...' name='robots'>` must both match.
  tag=$(grep -oiE '<meta[^>]+>' /tmp/sitemap-url-body.html | grep -i 'name=["'"'"']robots["'"'"']')
  printf '%s' "$tag" | grep -qi 'noindex' && echo "SITEMAP+NOINDEX (meta): $u"
done
```

No output from a fetch that timed out, redirect-looped past the cap, or came back empty is
`UNMEASURED` for that URL, never a silent pass — the same rule as 18.1-18.3.

Reuse the sitemap failure-mode table in SKILL.md §15 (#4, "Noindex pages in sitemap") for the same
comparison against Rank Math's own exclusion logic — §15 asks whether Rank Math is configured
to exclude noindex URLs at generation time; this check confirms it actually did, against the
sitemap as currently served.

### 18.5 Post-migration reminder: reviews and the 301 map (SEO-068)

Two losses a URL or platform migration causes, and that nothing recovers afterward:

- **Reviews and `AggregateRating`** disappear from the schema if review rows are not migrated
  under the same product IDs — the SERP stars go with them.
- **Old indexed URLs** lose their ranking authority unless mapped one-to-one (301) to their new
  equivalent. A blanket redirect of everything to the home page is treated by Google as a soft
  404, not a redirect, and none of the old authority carries over.

This is a reminder to raise, not a code scan or a live fetch: fire it once when a migration
signal is present (`.wp-create.json` `project.source: restore` or a `migration` note, or the
operator naming a recent platform/URL-structure change) and name the two losses above. It is never
auto-fixed — the redirect map and the review migration are decisions for the team doing the
move, not something an audit can generate from the running site.
