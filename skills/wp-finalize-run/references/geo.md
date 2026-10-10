# /wp-finalize — Check 8: GEO & agent-readiness (report only)

`commands/wp-finalize.md` sends the run here at Check 8: GEO & agent-readiness. Follow it in order; nothing in it is optional background.

## Contents

- GEO-A01 / GEO-U01 — raw-HTML content and heading order
- GEO-A06 — metadata completeness
- GEO-A07 / GEO-A08 / GEO-A09 / GEO-A10 — JSON-LD identity and entity graph
- GEO-A02 — robots AI policy
- GEO-A12 — sitemap lastmod
- GEO-A11 — trust anchors
- GEO-A04 — real 404 status
- GEO-A21 — /.well-known/* discovery files
- GEO-A13 — /llms.txt

Static subset of the GEO checks in `skills/wp-audit-geo-standards/references/check-catalog.md`,
reported here so a delivery reflects agent-readiness even when `/wp-audit --geo`
was never run. Like every check in this command it **reports and never fixes** —
run `/wp-audit --geo` to fix a finding, then re-run this check.

1. **GEO-A01 / GEO-U01 — raw-HTML content and heading order.** Fetch with no JS
   execution — this is what an agent that does not run JavaScript sees:
   ```bash
   curl -s "$SITE/" > /tmp/geo-home.html
   perl -0777 -pe 's/<(script|style)\b[^>]*>.*?<\/\1>//gis' /tmp/geo-home.html \
     | sed -e 's/<[^>]*>/ /g' | tr -s ' \n' ' ' | wc -c   # visible text, must be >= 500
   grep -o '<h1' /tmp/geo-home.html | wc -l                               # must be exactly 1
   grep -o '<main' /tmp/geo-home.html | wc -l                             # must be >= 1
   grep -oE '<h[1-6]' /tmp/geo-home.html                                  # must be sequential, no skipped level
   ```
   `<script>` and `<style>` are stripped before counting — otherwise inline JS/CSS
   inflates the character count and a JS-only page false-passes.
   **PASS** if the raw HTML carries ≥500 characters of content, exactly one
   `<h1>`, at least one `<main>` landmark, and a sequential heading order.
   **FAIL** naming the missing item.

2. **GEO-A06 — metadata completeness.** All four travel together; one missing
   leaves the crawler an incomplete card:
   ```bash
   curl -s "$SITE/" | grep -oE "rel=[\"']canonical[\"']" | wc -l        # must be 1
   curl -s "$SITE/" | grep -oE '<html[^>]*lang=' | wc -l                # must be 1
   curl -s "$SITE/" | grep -oE "property=[\"']og:image[\"']" | wc -l    # must be 1
   curl -s "$SITE/" | grep -oE "property=[\"']og:type[\"']" | wc -l     # must be 1
   ```
   Attribute quoting is not fixed — single-quoted `rel='canonical'` is valid — so the
   pattern accepts either quote rather than assuming double quotes and false-failing.
   **PASS** if canonical, `lang`, `og:image` and `og:type` are all present.
   **FAIL** listing the missing tags.

3. **GEO-A07 / GEO-A08 / GEO-A09 / GEO-A10 — JSON-LD identity and entity graph.**
   ```bash
   curl -s "$SITE/" > /tmp/geo-home.html
   grep -o 'application/ld+json' /tmp/geo-home.html | wc -l                   # GEO-A07, must be >= 1
   grep -o '"sameAs"' /tmp/geo-home.html | wc -l                              # GEO-A08, must be >= 1
   grep -q 'contactPoint' /tmp/geo-home.html                    # GEO-A09, must be present
   grep -q '"address"' /tmp/geo-home.html                       # GEO-A09, must be present
   grep -oE '"FAQPage"|"Service"|"Product"|"AggregateRating"|"BreadcrumbList"' /tmp/geo-home.html | wc -l   # GEO-A10, must be >= 1
   ```
   **PASS** if an identity JSON-LD block is present, links the entity via
   `sameAs`, carries `contactPoint` and `address`, and declares at least one of
   FAQPage / Service / Product / AggregateRating / BreadcrumbList. **FAIL**
   listing which identity signal is missing.

4. **GEO-A02 — robots AI policy.** The site must not shut out the answer engines. Grepping
   for names is not enough — a bot can be named and still be `Disallow`ed, so track the
   current `User-agent` and fail on a site-wide `Disallow: /`:
   ```bash
   curl -s "$SITE/robots.txt" | awk '
     /^User-agent:/ { sub(/^User-agent:[[:space:]]*/, ""); ua = tolower($0); next }
     ua ~ /^(gptbot|oai-searchbot|chatgpt-user|claudebot|perplexitybot|google-extended|applebot-extended|amazonbot|facebookbot)$/ &&
     $0 ~ /^Disallow:[[:space:]]*\/[[:space:]]*$/ { print "BLOCKED " toupper(ua); bad = 1 }
     END { exit bad }
   '
   ```
   **PASS** if the parser exits 0 (no allowlisted crawler has a site-wide `Disallow: /`).
   **FAIL** printing each blocked crawler.

5. **GEO-A12 — sitemap `lastmod`.** A sitemap without `lastmod` gives an agent no
   freshness signal. A sitemap **index** lists child sitemaps, not URLs — the dates live
   in the children (Rank Math may also date the index itself), so follow the index before
   judging:
   ```bash
   index=$(curl -s "$SITE/sitemap_index.xml")
   if grep -q '<lastmod>' <<<"$index"; then
     grep -o '<lastmod>' <<<"$index" | wc -l
   else
     grep -oE '<loc>[^<]+</loc>' <<<"$index" | sed -E 's#</?loc>##g' \
       | while read -r u; do curl -s "$u"; done | grep -o '<lastmod>' | wc -l
   fi   # must be >= 1
   ```
   **PASS** if the index or its child sitemaps carry `lastmod`. **FAIL** if the sitemap
   resolves but nothing is dated (Rank Math: enable `lastmod`).

6. **GEO-A11 — trust anchors.** `/about`, `/contact` and `/privacy` must each
   render ≥500 characters of real content:
   ```bash
   for p in about contact privacy; do
     echo -n "/$p: "; curl -s "$SITE/$p/" | sed -e 's/<[^>]*>/ /g' | tr -s ' \n' ' ' | wc -c
   done
   ```
   **PASS** if all three pages return ≥500 characters. **FAIL** listing the short
   or missing page — a stub privacy page is a trust gap, not a placeholder.

7. **GEO-A04 — real 404 status.** A "not found" page that returns `200` is indexed
   as real content:
   ```bash
   curl -s -o /dev/null -w '%{http_code}\n' "$SITE/this-page-does-not-exist-$RANDOM/"
   ```
   **PASS** if the status is exactly `404`. **FAIL** on `200` or a redirect — the
   page must carry the site's 404 template, not a soft-404 home page.

8. **GEO-A21 — `/.well-known/*` discovery files.** Agent and auth metadata lives
   at fixed well-known paths:
   ```bash
   for p in agent-skills/index.json security.txt; do
     echo -n "/.well-known/$p: "; curl -s -o /dev/null -w '%{http_code}\n' "$SITE/.well-known/$p"
   done
   ```
   **PASS** if the discovery files the site intends to expose resolve (not `404`).
   **FAIL** listing the missing file — an intentional absence is noted, not fixed.

9. **GEO-A13 — `/llms.txt`.** The agent-readable site index:
   ```bash
   curl -s -o /dev/null -w '%{http_code}\n' "$SITE/llms.txt"   # must be 200
   curl -s "$SITE/llms.txt" | head -20
   ```
   **PASS** if `/llms.txt` returns `200` with a non-empty body. **FAIL** if
   missing — the `wp-agentic-surfaces` fix run by `/wp-audit --geo` generates it.

**PASS** if every item above passes. **FAIL** listing each failing item with its
GEO code. Report only — never edit the site from `/wp-finalize`.
