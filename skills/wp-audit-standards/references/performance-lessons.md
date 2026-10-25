# Performance — measured lessons (Tier 3 / Lighthouse)

Part of the `wp-audit-standards` skill. Interpretation traps and fixes that moved production
bytes on real builds. Read before filing or fixing a `PERF-xxx` finding from a Lighthouse run.
Facts about Lighthouse scoring hold for Lighthouse 10 and later.

## Contents

- Read *observed* metrics before chasing a bad *simulated* score
- A Lighthouse run needs an idle machine, and a contended one is not a slow page
- A local lab that resembles production: HTTP/2, compression, medians
- Inline critical CSS: conditional, and rejected without its five conditions
- Per-template used CSS: what worked on a store, and what broke
- WebP: `image_editor_output_format` only covers new, attachment-pipeline images
- Right-size: never print `$field['url']` for a fixed slot
- Used-CSS subset of a huge parent stylesheet, and the carousel regression
- Deferring stylesheets that touch nothing above the fold
- JavaScript: footer, DOMContentLoaded, jquery-migrate, tag managers, duplicate AJAX, idle CPU
- Images that still double-download or ignore WebP, and layout shift from hidden widgets
- AIOS × Lighthouse: the CF7 REST gotcha

## Read *observed* metrics before chasing a bad *simulated* score

Lighthouse's default (`throttlingMethod: "simulate"`) reports **Lantern-simulated** LCP and
FCP on a modeled slow-4G and 4× CPU. On a **development host** this is dominated by local
TTFB and the throttle model, and can read 6–7 s while the page is actually instant. Before
treating a high LCP as real, open the full JSON and compare:

- `audits.metrics.details.items[0].largestContentfulPaint` (simulated) **vs**
  `...observedLargestContentfulPaint` (real paint).
- If observed is ~200–900 ms and simulated is multi-second, the number is a
  **simulation/dev-host artifact**: the score barely moves whatever the theme does, and
  production (page cache, real CDN and TTFB) differs. Say so in the finding instead of
  chasing it. **Real byte reductions (WebP, right-sizing) still help production** and still
  shrink the *LCP resource*, so do those — and set score expectations.
- `image-delivery-insight`, `render-blocking-insight`, `lcp-discovery-insight` and the other
  insights are **weight 0** in the Performance score. Only the five metric audits (FCP, LCP,
  TBT, CLS, Speed Index) carry weight. Fixing a weight-0 insight is a production win, not a
  score win — label it that way.

## A Lighthouse run needs an idle machine, and a contended one is not a slow page

A Lighthouse score is a measurement of the machine as much as of the page. The same page, same
URL and same flags, measured on a busy laptop and then on an idle one, read **performance 62
with LCP 10,170 ms** and **performance 94 with LCP 1,580 ms**. Nothing in the theme changed
between the two runs. The first number is the kind that gets a morning spent on a
non-existent regression, and it is indistinguishable from a real one by inspection.

- **Never run Lighthouse next to anything else** — not a second Lighthouse, not the DOM/axe
  suite, not a watch build, not a video call. Run it alone, and run the categories serially.
- **A page that "hangs" under contention is usually not hanging.** An internal search spec
  that looked stuck, and was left out of the suite for it, completed in 4–7 s once Lighthouse
  stopped competing with it; the whole suite went from 4.3 minutes to 1.0 minute.
- **Re-measure before filing a metric regression, on the idle machine, twice.** A single run
  is not evidence. Where the two runs disagree by more than a few points, say so in the
  finding rather than reporting the worse one.
- The same applies to a *before/after* pair for a fix: both halves must be measured under the
  same conditions, or the fix's number is the machine's number.

## A local lab that resembles production: HTTP/2, compression, medians

A clone served by a stock local Apache or nginx (HTTP/1.1, no compression) turns "Modern HTTP",
"Minify", "Enable text compression" and most "render-blocking" findings into environment
artifacts, and the simulated LCP comes out about twice what production shows. Fix the lab
before reading the score, not the theme:

1. Enable compression on the vhost (Apache: `a2enmod deflate` or the distro's equivalent, then
   `AddOutputFilterByType DEFLATE text/html text/css application/javascript application/json image/svg+xml`).
2. Put an HTTP/2 + TLS proxy in front for Lighthouse runs only. `bin/h2-proxy.mjs` is one:
   `node bin/h2-proxy.mjs --target http://<site-host> --port 8443 &` serves
   `https://<site-host>:8443/` with HTTP/2, brotli/gzip for text, and an in-memory HTML cache for
   anonymous requests (what a page cache or CDN would do; `--no-cache` for real PHP TTFB,
   `/__purge` to empty it). The certificate is self-signed and generated at runtime with
   `openssl` into a temp dir, so no key is ever committed; `--cert`/`--key` bring your own.
   Stop it with `kill <pid>`, not `pkill -f`.
3. Run Lighthouse against the proxy, mobile, **5 runs, take the median**. The spread between
   runs on one URL is large enough to flip a decision, so never decide on a single run:

   ```bash
   for i in 1 2 3 4 5; do
     CHROME_PATH=/usr/bin/chromium lighthouse "https://<site-host>:8443/<path>" \
       --only-categories=performance --output=json --output-path="lh-$i.json" --quiet \
       --chrome-flags="--headless=new --ignore-certificate-errors"
   done
   # median of categories.performance.score and audits[first-contentful-paint|largest-contentful-paint|
   # total-blocking-time|cumulative-layout-shift].numericValue across lh-*.json
   ```

   Lighthouse's default is already the mobile profile. Purge the proxy cache and warm each URL
   once before the runs. Lighthouse needs the idle machine described above.

On the store this came from, the same code scored home 41-55 / category 75 against plain
Apache and 93 / 95 behind the proxy, with all the gains below applied. Say which serving layer a
number was measured on; the proxy narrows the gap to production, it does not close it (see the
clone caveat in `wp-audit-run/references/site-context.md`).

## Inline critical CSS: conditional, and rejected without its five conditions

Inlining the critical CSS is the standard advice for a render-blocking stylesheet. Done as one
blob ahead of the hero, on a first experiment, it made the metric it was meant to fix
**worse**; done per template group with the conditions below, it held up on a real news build
(a bundled sheet set, content-hash build, cuts per template group). Both results are recorded
so the experiment is neither repeated blind nor ruled out.

The failed first experiment:

| Variant | FCP | LCP | CLS |
|---|---|---|---|
| Baseline | 990 ms | 2950 ms | baseline |
| 43KB critical CSS inlined | **570 ms** | **3150 ms** | improved |
| 13KB (above-the-fold only) | improved | not measured | **0.139** |
| Preloading jQuery + carousel + page JS | **1340 ms** | not measured | not measured |

The inline block sat *ahead of the hero image on the same connection*, so the paint that
counts started later even though the first paint started sooner. The trimmed variant was
smaller than the styles the first viewport actually needs, which is what moved CLS to 0.139.

**Propose inline critical CSS only when all five conditions hold; with any one missing it is
not a fix, report it as rejected:**

1. **A cut per template group**, not one for the site (for example `single`, `elementor` and
   `listing`), generated from sample URLs of that group at 412, 768 and 1440 px. Templates
   with no group get no cut and keep the normal blocking tag.
2. **The full sheet stays and loads without blocking** (`media="print"` plus the `onload`
   swap and a `<noscript>` fallback, in the sheet's own position so the cascade is unchanged).
   The cut is a first-paint aid, never a replacement. Check the CSP allows the inline `onload`.
3. **A hash of the origin sheet's CONTENT (never mtime) invalidates the cut by itself.** The
   inline helper compares the hash recorded at cut time with the sheet it is about to defer
   and drops the cut on a mismatch. Without it, a rebuilt bundle or a WordPress, plugin or
   builder update leaves the cut stale in silence. `bin/assets-fresh.mjs` recomputes the
   hashes and fails with "regenerate critical cuts"; `/wp-update` runs it after an update.
4. **Verified on the SAME DOM.** With JavaScript, disable the full `<link>` sheets, then
   compare computed styles and bounding rectangles of every element before and after, at 412,
   768 and 1440 px. Never compare two page loads: the front page rotates its content and
   posts load more on scroll, so two loads differ for reasons that have nothing to do with CSS.
5. **Decided on observed LCP**, from real or throttled-browser runs, not on FCP and not on
   simulated (Lighthouse-modelled) LCP. FCP and LCP moved in opposite directions in the table
   above; a change justified by FCP alone is unmeasured, and the LCP number decides.

The build is two steps in a fixed order, and forgetting the second is the failure that
shipped: rebuild the `.min` files and bundle (which rewrites the manifest), **then** regenerate
the cuts. Commit sources, `.min`, bundle, cuts and the hash manifest in the same commit.

On the failed experiment the real cause was elsewhere and only the Lighthouse breakdown showed
it: 276 ms of *element render delay*, because the carousel re-built the first slide inside its
own track and the second paint was the one being measured. A background the theme already
painted without JavaScript was not the problem.

## Per-template used CSS: what worked on a store, and what broke

On a WooCommerce store with a vendor theme and Elementor, five stylesheets blocked the first
paint: the theme sheet, its WooCommerce sheet, `elementor-frontend`, `wp-block-library` and a
swatches plugin. Together they were 1.2-1.4 MB per page.

**Dropping a sheet on pages that "do not need it" broke the site.** Removing the theme's
WooCommerce sheet (335 KB) on content pages broke the cart panel and the mobile search modal
on every page. Those panels are in the header and footer of every template, and they are
styled by the WooCommerce sheet. Do not dequeue a vendor sheet by page type.

**What worked:** keep every sheet, and change how it loads.

1. Per template group (front page, archive, product, page, 404), extract the rules the
   rendered page uses, with the panels and modals open. Save one used-CSS file per group.
2. Print that file as the blocking stylesheet, and load the full sheet asynchronously:
   `media="print" onload="this.media='all'"`, plus a `<noscript>` fallback.
3. Keep cart, checkout and account on the normal blocking tags. Their states (errors,
   shipping options, saved cards) are too many to capture.

Blocking CSS went from 1.2-1.4 MB to 0.33-0.44 MB. The final render had 0 differences on
8 URLs at 1440 and 390 px. With the full sheets blocked on purpose, the first paint still had
0 differences, so the used CSS alone is complete.

Three conditions travel with this fix:

- **Regenerate the used CSS after every theme or plugin update.** A stale file does not break
  the page, because the full sheet arrives later, but the first paint can be wrong.
- **The Content-Security-Policy must allow the inline `onload`.** Without
  `'unsafe-hashes'` plus the hash of `this.media='all'` (or `'unsafe-inline'`) in
  `script-src`, the full sheets stay `media="print"` and only the used CSS applies.
- **Measure with every panel open.** A used-CSS pass that loads the page and nothing else
  misses the cart panel, the search modal and the mobile menu.

## Used-CSS subset of a huge parent stylesheet, and the carousel regression

A commercial parent theme shipped one 1.3 MB stylesheet of which 2-5 % applied to any page.
Dropping it per page type breaks panels (above); blocking on it costs seconds on mobile. What
held up is a generated subset that keeps the final cascade identical:

1. **Collect used rules across a URL sample.** Per template group, load a sample of real URLs
   at 1366 and 390 px (add a tablet width), **with and without JavaScript**, and keep every rule
   whose selector matches an element that is rendered above the fold plus a margin (about
   200 px). Open panels and modals before collecting. Rules in `@media`/`@supports` keep their
   wrapper; `@font-face` and `@keyframes` are always kept; hover/focus/pseudo-element states
   count as their element; an element hidden by `display:none` or opacity 0 still counts when
   it precedes the first below-the-fold element, but only for the rules that hide or position
   it (otherwise closed popups open). Rewrite relative `url()` to root-relative.
2. **Write `<stylesheet>-used.css`** and print it as the blocking stylesheet **in the full
   sheet's own position** in `<head>`. Load the full sheet in the same position with the
   `media="print"` swap (see above), so when it arrives the cascade order is what it always
   was. Never move the full sheet to a different position: that changes which rule wins.
3. **Group by template**, not one file for the site: product, archive, post, commerce (cart,
   checkout, account, wishlist), front page, generic page. Finer groups cut the inline CSS of
   posts and pages by about a third compared with one shared block. A page built in a page
   builder belongs to the builder's group, not to the blog's.
4. **Keep a kill switch** (a request header or query arg that serves the full sheets) so
   before/after screenshots and computed-style diffs can be taken on the same build. The
   acceptance test is a first-paint comparison against the full sheets over the whole sample at
   two widths, not a visual impression.
5. **Regenerate after every theme, plugin or page-builder header/footer change.** The generator
   is site-specific (stylesheet ids, group URLs, how the theme prints the block), so it is not
   shipped here; keep it in the theme's own `tools/`.

**Applying the full sheets at load raised TBT.** Each full-sheet application forces a style
recalculation over a big DOM, and Lighthouse counts it as main-thread work. Apply the deferred
sheets on the first interaction (pointer, scroll, touch, key, focus) in one batch, with a
`load`-time fallback only for sheets the used-CSS file could not cover.

**Regression to test for:** the used-CSS file for a carousel library omitted the library's base
rules because the sampled first screens had none visible. Carousels below the fold then
initialised against unstyled markup and looped (`RangeError: Maximum call stack size
exceeded` on scroll, mobile only). Include the carousel library's base stylesheet **whole** in
every group's critical CSS, and let the functional suite scroll every sampled page on mobile
and fail on any console error.

## Deferring stylesheets that touch nothing above the fold

The other half of the same idea needs no generator. For each blocking stylesheet, measure
whether any of its selectors matches an element above the fold **in all sampled views**
(templates × widths). A sheet that touches none (wishlist, icon fonts used in pseudo-elements
below the fold, newsletter, ajax-filter, select2, block-library styles on pages without blocks
and similar; 17 on one store) loads without blocking. Three rules:

- A sheet that carries `@font-face` stays blocking: deferring it swaps fonts late and shifts
  layout.
- Defer by moving the `href` to `data-href` and applying it on first interaction, not with
  `media="print"` alone, when the point is to keep the request out of the load window.
- Verify with the same first-paint comparison as above. Blocking sheets on the home page went
  36 to 26 and on product and category pages 20 to 13; mobile FCP improved 0.1-0.3 s while the
  simulated LCP stayed 7-8 s, because the LCP there was set by something else (an image, a
  CSS background). Report what moved, not what was hoped for.

## JavaScript: footer, DOMContentLoaded, jquery-migrate, tag managers, duplicate AJAX, idle CPU

- **All front scripts to the footer.** A late `script_loader_tag`/`wp_default_scripts`-style pass
  at `PHP_INT_MAX` priority moves every handle to the footer, excluding the admin, the
  Customizer and the page-builder preview. A default WooCommerce store went from 8-9 blocking
  `<head>` scripts to 0 and from 44 to 36 blocking requests on the home page; FCP improved
  0.3-0.5 s, **LCP did not move** (CSS set it). Inline scripts that widgets print in the
  middle of the page and that call `jQuery(...)` must be wrapped in `DOMContentLoaded`, or they
  run before jQuery exists.
- **`jquery-migrate`: remove it only after checking `jQuery.migrateWarnings`.** Load the
  sampled pages with migrate present and read the array. `$(window).load(fn)` was removed in
  jQuery 3 and a parent theme plus a widget plugin still used it: ship a three-line shim
  (`$.fn.load` for `window` delegating to `on('load', fn)`) or those scripts silently stop.
- **A tag manager can cost seconds of CPU on mobile.** gtag.js printed by an SEO plugin (GA4)
  was 1.5 s of main-thread time. Print it as `data-src` and load it on the first pointer
  move, touch, key or scroll **or 5 s after `load`**, whichever comes first. The timer keeps
  counting visits that touch nothing; without it analytics undercounts and the change is not
  shippable. It is a decision for the site owner, not an auto-fix.
- **Duplicate AJAX POSTs on every page.** A multi-currency plugin and a wishlist plugin each
  POSTed on every view, bypassing the page cache. A `$.ajaxPrefilter` that aborts the call when
  its answer is already known (the currency cookie equals the currency printed in the HTML; a
  logged-out visitor's wishlist is known to be empty from a cookie set only by a real empty
  response) turned 2 uncached PHP requests per view into 0. Clear the shortcut cookie on any
  action that could change the answer.
- **Idle CPU.** Measure CPU with the page left alone for 10 s. Infinite CSS animations on the
  home page (34 % CPU), a hidden gallery shimmer animating `left`, and a `requestAnimationFrame`
  loop from a countdown library loaded on every page were the sources. Limit animations to a
  few iterations and pause them off-screen; load the countdown library only when a scheduled
  sale exists. Idle CPU went 34 to 6.5 % (home) and 3.3 to 0.3 % (product).
- **Main-thread cost hides in third-party observers.** A page-builder anchor-scroll helper that
  walked the whole document on every mutation (about 1 s of mobile CPU) and a lazy-loading
  library that forced a full layout on each `load` event were each replaced by a small
  `IntersectionObserver`/guard. Check the Lighthouse main-thread breakdown before assuming it
  is your code.

## Images that still double-download or ignore WebP, and layout shift from hidden widgets

- **`imagesLoaded` plus lazy `<picture>`.** `imagesLoaded` reads `img.src`, which for a lazy
  image inside `<picture>` is the fallback JPEG until `currentSrc` exists, so each thumbnail was
  fetched twice (fallback plus WebP). Make it read `currentSrc` or skip images that are still
  lazy. Fallback requests went 1-3 to 0 and a blog page lost about 190 KB.
- **Zoom plugins read `img.src` too** and so request the JPEG/PNG fallback on every product
  page (about 100 KB). Point them at the WebP `data-` attribute or the `currentSrc`.
- **CSS background banners are not rewritten by most WebP plugins** (they rewrite `<img>` and
  `srcset`). The WebP buffer above handles them; otherwise convert and reference the sibling
  by hand. Confirm with the network panel that the fallback format is requested 0 times.
- **A colour profile larger than the picture.** A CMYK ICC profile of 0.5-1.8 MB was embedded in
  thumbnails; Chrome ignores it. Stripping without recompressing (`jpegtran -copy none`,
  `webpmux -strip icc`) cut 123 MB to 3.8 MB with identical pixels. Back up first.
- **`fetchpriority="high"` on the wrong image.** When the LCP is a CSS background already
  preloaded, a page builder's high priority on the first thumbnail competes with it: removing
  it moved one page from 89 to 94. Preload the real LCP resource and give priority to that one only.
- **CLS from sticky bars and hidden carousels.** A sticky announcement bar inserted by JS
  pushed the page 78 px (desktop) and 138 px (mobile): reserve its height in CSS before it
  renders (CLS 0.17-0.66 to 0.00-0.03). A parent theme hid every uninitialised slick carousel
  and the product gallery then pushed the summary on init (CLS 0.42): reserve the first image
  and the thumbnail row's box before JS (CLS 0.002; remaining jump when slides differ in
  height is slick's own). A fixed header that leaves the flow on scroll needs a spacer of its
  height (CLS on scroll 0.15 to 0).

## WebP: `image_editor_output_format` only covers new, attachment-pipeline images

`add_filter('image_editor_output_format', ...)` converts uploads to WebP **only on new
uploads**, and **only for images that flow through WordPress's attachment functions**
(`wp_get_attachment_image`, `the_post_thumbnail`). A theme that prints **raw SCF/ACF field
URLs** (`echo $field['url']`) or a CSS `background-image: url(<field>)` bypasses it entirely,
so every existing image those templates print stays JPEG or PNG.

To serve WebP for existing and field-driven images without touching every template:

1. Generate `.webp` siblings for the existing uploads, once. Run exactly this from the
   WordPress root; it needs ImageMagick 7 (`magick`) and skips any sibling that exists:

   ```bash
   find wp-content/uploads -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0 |
     while IFS= read -r -d '' f; do
       w="${f%.*}.webp"
       [ -e "$w" ] || magick "$f" -quality 82 "$w"
     done
   ```

   An LCP image that sits behind a scrim or is replaced by a video tolerates `-quality 68`.
2. Add a front-end output buffer that rewrites the finished HTML — `src`, `srcset` and inline
   `background-image` in one pass — to the sibling, only where the sibling exists:

```php
add_action( 'template_redirect', function () {
    if ( is_admin() || is_feed() || is_robots() ) return;
    $u = wp_get_upload_dir(); $base = $u['baseurl']; $dir = $u['basedir'];
    ob_start( function ( $html ) use ( $base, $dir ) {
        $pat = '#' . preg_quote( $base, '#' ) . '/[^"\'\)\s]+?\.(?:jpe?g|png)#i';
        return preg_replace_callback( $pat, function ( $m ) use ( $base, $dir ) {
            $webp = preg_replace( '/\.(?:jpe?g|png)$/i', '.webp', $m[0] );
            return file_exists( $dir . substr( $webp, strlen( $base ) ) ) ? $webp : $m[0];
        }, $html );
    } );
} );
```

`template_redirect` is front-end only, and with a page cache the buffer runs once per cache
build. Every browser the theme targets supports WebP, matching an unconditional
`image_editor_output_format` policy, so no `Accept`-header branching is needed.

## Right-size: never print `$field['url']` for a fixed slot

Lighthouse's "properly size images" waste is a 2200px original served into a 400px slot, and
a raw field URL (`$image['url']`) always emits the full original. Print the attachment ID
instead, so the browser gets a `srcset`, with `sizes` taken from the element's real rendered
width:

```php
echo wp_get_attachment_image( (int) $image['id'], 'large', false, array(
    'class'   => 'prefix__bg',
    'alt'     => $heading,
    'loading' => 'lazy',
    'sizes'   => '(max-width: 899px) 100vw, 136vw', // a background drawn at 136% of the viewport
) );
```

This composes with the WebP buffer above: the `srcset` `.jpg` URLs are rewritten to `.webp`.

## AIOS × Lighthouse: the CF7 REST gotcha

AIOS's `aiowps_disallow_unauthorized_rest_requests = 1` answers **403** on Contact Form 7's
REST endpoints (`/wp-json/contact-form-7/v1/...`). Lighthouse then **waits up to 45 s** on
those pending requests and logs console errors, so Best Practices drops (often 100 → 96) and
the metrics inflate. The symptom in the JSON: `errors-in-console`, or pending `Fetch`
requests to `contact-form-7` with `statusCode: 403`.

When a CF7 form is on the site, turn the setting off — run exactly:

```bash
$WP option patch update aio_wp_security_configs aiowps_disallow_unauthorized_rest_requests 0
```

That is the AIOS agent's own write path (`agents/wp-audit-aios.md`). The setting refuses
REST requests from visitors who are not logged in, and a CF7 submission is one.
