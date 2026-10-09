# Performance — measured lessons (Tier 3 / Lighthouse)

Part of the `wp-audit-standards` skill. Interpretation traps and fixes that moved production
bytes on real builds. Read before filing or fixing a `PERF-xxx` finding from a Lighthouse run.
Facts about Lighthouse scoring hold for Lighthouse 10 and later.

## Contents

- Read *observed* metrics before chasing a bad *simulated* score
- A Lighthouse run needs an idle machine, and a contended one is not a slow page
- Inline critical CSS: measured on a real site, and rejected
- Per-template used CSS: what worked on a store, and what broke
- WebP: `image_editor_output_format` only covers new, attachment-pipeline images
- Right-size: never print `$field['url']` for a fixed slot
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

## Inline critical CSS: measured on a real site, and rejected

Inlining the critical CSS is the standard advice for a render-blocking stylesheet, and on a
real build it made the metric it was meant to fix **worse**. Recorded here so the experiment is
not repeated blind:

| Variant | FCP | LCP | CLS |
|---|---|---|---|
| Baseline | 990 ms | 2950 ms | baseline |
| 43KB critical CSS inlined | **570 ms** | **3150 ms** | improved |
| 13KB (above-the-fold only) | improved | not measured | **0.139** |
| Preloading jQuery + carousel + page JS | **1340 ms** | not measured | not measured |

The inline block sits *ahead of the hero image on the same connection*, so the paint that
counts starts later even though the first paint starts sooner. The trimmed variant is smaller
than the styles the first viewport actually needs, which is what moved CLS to 0.139. All of it
was reverted with zero pixels of difference.

**The lesson is not "never inline".** It is that FCP and LCP move in opposite directions here,
so a change justified by FCP alone is unmeasured, and the LCP number decides. On that site the
real cause was elsewhere and only the Lighthouse breakdown showed it: 276 ms of *element
render delay*, because the carousel re-built the first slide inside its own track and the
second paint was the one being measured. A background the theme already painted without
JavaScript was not the problem.

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
