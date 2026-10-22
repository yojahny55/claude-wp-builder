# Performance procedures — currency cache and the render path

Part of the `wp-audit-standards` skill. Moved verbatim out of `agents/wp-audit-performance.md` so the agent does not carry it on every dispatch; the agent's index names when to read it. Read before running PERF-065 to PERF-067, or any of PERF-047 to PERF-055, PERF-068, PERF-069, PERF-010, PERF-016, PERF-049, PERF-051 to PERF-053 beyond the table row.

## Contents

- Procedure — multi-currency and full-page cache (PERF-065 to PERF-067)
- PERF-066 is a detection code, not a pass/fail
- PERF-067 is the proof, not the guess
- Procedure — render path checks (PERF-047 to PERF-053)
- PERF-047 — render-blocking third-party CSS
- PERF-048 — `fetchpriority` must point at the real LCP
- PERF-054/PERF-055 — finding the real LCP element, per template
- PERF-068/PERF-069 — CLS and INP in the browser, per template
- PERF-049 — dead assets
- PERF-051 — dead references
- PERF-053 — oversized image assets
- PERF-010 — moving everything to the footer has three follow-ups
- PERF-010 — where the group actually comes from
- PERF-052 — site-wide libraries

### Procedure — multi-currency and full-page cache (PERF-065 to PERF-067)

A multi-currency plugin (CURCY/`woocommerce-multi-currency` is one shape of this; any plugin
that computes a per-currency price at request time from `_regular_price_wmcp`-style per-currency
meta has the same problem) decides the price to show **per request**, usually from a cookie,
a session, or a query parameter. A full-page or edge cache decides what to show **per cache
key**. When the cache key does not include the currency signal, the two disagree: the first
visitor in a currency sets the cached HTML, and every other visitor — in any currency — gets
served that one, wrong prices and all, until the entry expires.

**Detecting the multi-currency plugin.** Flag one of these confirmed slugs when active: CURCY
(`woocommerce-multi-currency`), WOOCS / WooCommerce Currency Switcher
(`woocommerce-currency-switcher`), Aelia Currency Switcher for WooCommerce
(`woocommerce-aelia-currencyswitcher`), WPML's WooCommerce Multilingual
(`woocommerce-multilingual`) when its own multi-currency setting is enabled, and WooCommerce
Payments (`woocommerce-payments`) when its own Multi-Currency feature is enabled — check each
plugin's own settings before crediting it, since WCML and WooCommerce Payments both ship with
multi-currency off by default, and an active install of either is not by itself evidence of the
defect. Any other active plugin whose slug or name merely contains `currency` is reported
`UNCONFIRMED`, never flagged as the multi-currency plugin outright: a currency-conversion
display widget matches that substring while never changing what WooCommerce actually charges,
so name the plugin and confirm before treating it as the one in play. This list is not
exhaustive in the other direction either — a plugin that varies price by country or geography
without the word "currency" in its slug (a price-by-country plugin is one shape of this)
produces the same cache-bleed defect, and neither the slug list nor the substring fallback
catches it; note that gap in the report rather than reading a clean PERF-065 as proof the store
has no per-visitor pricing.

**Gate first, exactly as `/wp-audit` Step 2.3 gates every commerce check:** `N/A` ("no
WooCommerce") when `site.commerce` is `none`, out of the denominator; `N/A` ("no multi-currency
plugin") when `site.commerce` is `woocommerce` but no multi-currency plugin is active. All three
codes carry this gate — PERF-066 included, even though it is a detection-only INFO code: running
its live requests when PERF-065 and PERF-067 are already `N/A` would probe a layer nothing in
this audit needs an answer for. Neither gate is optional — reporting this on a single-currency
store scores it for a cart it never had.

**Severity split for PERF-065.** A cookie- or session-selected currency is invisible to almost
every cache layer by design (a URL-keyed cache never sees the cookie at all), so that
combination is the CRITICAL case: the collision is not a possibility, it is the plugin's normal
mode of operation meeting a cache that cannot see it. A currency chosen by a `?currency=` query
parameter is comparatively safer — a cache that varies its key on the full URL (the common
default) naturally separates the two — so that shape is WARNING, and the finding should say
which mechanism was found and why the split.

**PERF-066 is a detection code, not a pass/fail** — it exists so PERF-065 and PERF-067 have a
name for the layer they are reasoning about (Cloudflare or another CDN/proxy cache, a caching
plugin, or "none detected"), and so the report can say *which* edge is doing this rather than
"a cache, somewhere." Detection needs a second request to the same URL and a header that reads
as a confirmed hit, not merely present: `cf-cache-status` is set on every Cloudflare response
regardless of whether that response was cached, so `DYNAMIC`/`BYPASS` on the second request mean
Cloudflare is in front of the origin but is *not* caching the page, and PERF-065/PERF-067 must
not treat that as a caching layer. Off Cloudflare, fall back to the generic heuristics — `age:`
greater than zero, `x-cache: HIT`, a `via:`/`server:` naming Varnish, or a present
`x-proxy-cache`/`x-fastcgi-cache` header — since most CDNs and reverse-proxy caches use one of
these instead of `cf-cache-status`. Follow the exact production-host contract
`wp-audit-security.md` Step 3 uses for its own response-header checks: ask for the production
URL when the manifest does not resolve one, default to `wordpress.url_origin`, and never fire
this at the local clone — a clone has no CDN in front of it (Step 2.3 suppresses that absence as a
clone artifact, not a finding), so probing it here would read as "no cache detected" and hide a
defect that is live in production. Without a confirmed production URL, PERF-065, PERF-066 and
PERF-067 are all `UNMEASURED` ("needs the public URL"), never `PASS` — a cache with no
currency-aware key does not become safe because nobody could reach it to check, and PERF-065's
own "no cache detected" PASS depends on this same production reading: a clean local plugin list
is not proof there is no edge cache in front of production.

**PERF-067 is the proof, not the guess.** PERF-065 reasons from configuration; PERF-067 reasons
from what the cache actually served. Selecting each of the store's currencies in turn against
the same URL and reading back the header PERF-066 detected — `cf-cache-status` on Cloudflare, or
the equivalent generic header otherwise — tells you whether the second request got its own price
(the cache varied correctly, or bypassed) or the first visitor's (the cache did not — a
confirmed HIT plus the wrong price is the confirmed defect). Report the two prices, the two
currency codes, and the cache-status header value for each request as the evidence line.

### Procedure — render path checks (PERF-047 to PERF-053)

**PERF-047 — render-blocking third-party CSS.**
List every `wp_enqueue_style` in `functions.php` and `inc/`. A library is deferred when it is
enqueued with the `print` media type and switched to `all` on load, with a `<noscript>` fallback:

Defer per link, via `onload` on the tag itself. Do **not** sweep the document for
`link[media="print"]` and flip them all to `all`: a theme's real print stylesheet is a
`media="print"` link too, and that sweep would load it on screen.

```php
wp_enqueue_style( 'aos', get_template_directory_uri() . '/assets/css/aos.css', array(), '3.4.0', 'print' );

add_filter( 'style_loader_tag', function ( $tag, $handle ) {
    if ( ! in_array( $handle, array( 'aos' ), true ) ) {
        return $tag;
    }
    $tag = str_replace( "media='print'", "media='print' onload=\"this.media='all';this.onload=null\" data-no-optimize='1'", $tag );
    return $tag . "<noscript>" . str_replace( "media='print'", "media='all'", $tag ) . "</noscript>";
}, 10, 2 );
```

`data-no-optimize="1"` keeps a page cache that combines CSS (LiteSpeed, WP Rocket) from
merging the link straight back into a synchronous bundle.

**PERF-048 — `fetchpriority` must point at the real LCP.** This needs lab data; there is no
code-only version. Read the LCP element from the Lighthouse/PSI report:

- LCP is an `<img>` → `fetchpriority="high"` on that image is correct (this is PERF-016).
- LCP is text (`<p>`, `<h1>`, `<div>`) → `fetchpriority="high"` on any image is **wrong**: it
  makes the browser spend bandwidth ahead of the element that actually decides the score, and
  the run-to-run variance shows up as a swinging performance number. Keep the hero preload,
  drop the priority hint, and report the actual LCP element in the finding.

PERF-016 and PERF-048 are two halves of one decision — never report them in isolation.

Two cases this check gets wrong when read from the markup alone:

- **Elementor's "Optimized Image Loading"** (option `elementor_optimized_image_loading`, on
  by default) buffers the whole page and rewrites `<img>` tags after the theme has printed
  them. It gives `fetchpriority="high"` to the first image of at least 50 000 px it meets,
  which on most headers is the logo, and it sets `loading="lazy"` on every image after the
  third, which can be the real LCP. A template filter that adds `loading="eager"` to the
  LCP proves nothing until the served HTML is read: Elementor only keeps attributes that
  are already in the markup, and a widget that prints its `<img>` with no `loading` attribute
  gets one from the buffer. Read the logo and the LCP element in the served HTML. When the
  logo carries the priority, the fix is
  `add_filter( 'elementor/image-loading-optimization/min_priority_img_pixels', fn() => PHP_INT_MAX )`
  plus explicit `loading="eager" fetchpriority="high"` on the LCP of each template.
- **One LCP per viewport.** When the desktop and mobile LCP are different elements (a wide
  banner that collapses on mobile, so the first card below it becomes the LCP), each may
  carry `fetchpriority="high"`. Two high-priority images are a PERF-048 finding only when
  both are LCP candidates at the same viewport. Name the viewport of each in the finding.

**PERF-054/PERF-055 — finding the real LCP element, per template.** "The hero image is the
LCP" is a guess, and guessing it produces the opposite of the intended fix: a card grid
(a directory archive, a team/news strip) can put its LCP on the first row of CARDS, not on
the hero — a blanket `loading="lazy"` below the fold then defers exactly the element the page
is judged on, on the one template where that rule was wrong. Measure instead of assuming, and
measure every template the theme has, not only the front page:

```js
// Runs in the page (Playwright `page.evaluate`, or paste into a console).
// PerformanceObserver on 'largest-contentful-paint' fires once per candidate as the
// page loads and keeps replacing its report with a later, bigger one — the LAST
// entry when the load settles is the one Lighthouse/PSI would report too.
new PerformanceObserver((list) => {
  const last = list.getEntries().at(-1);
  window.__lcp = {
    tag: last.element?.tagName,
    src: last.element?.currentSrc || last.element?.src || null,
    loading: last.element?.getAttribute?.('loading'),
    text: last.element?.textContent?.slice(0, 60),
    fontWeight: last.element && getComputedStyle(last.element).fontWeight,
  };
}).observe({ type: 'largest-contentful-paint', buffered: true });
```

Run it per template at both the mobile and desktop viewports the audit already screenshots
at — the LCP element is not guaranteed to be the same element at both: a hero image can beat
a heading on desktop and lose to it on a phone once the layout stacks. PERF-054 fails when
`window.__lcp.loading === 'lazy'`. PERF-055 fails when `window.__lcp.tag` is text (not an
`<img>`) and `window.__lcp.fontWeight` names a weight whose `assets/fonts/<family>-<weight>.woff2`
is not one of the files `wp_head` preloads — report the actual rendered weight in the finding
so the fix preloads that file instead of guessing 400.

Report PERF-054/PERF-055 per template, not once for the site: the fix in Step 5 is "eager the
elements in the real LCP's row, lazy the rest, preload the weight that row renders in" — the
same shape as the demo's own card grids, never a single sitewide `loading="lazy"` removal.

**PERF-068/PERF-069 — CLS and INP in the browser, per template.** Neither value exists in
WP-CLI, so both are measured in the page, like PERF-054, and recorded per template at both
viewports rather than once for the site. Everything here only observes; it submits nothing
and writes nothing, which is why it is safe on a local clone.

```js
// Runs in the page (Playwright `page.evaluate`, or paste into a console).
window.__cls = 0;
new PerformanceObserver((list) => {
  for (const e of list.getEntries()) if (!e.hadRecentInput) window.__cls += e.value;
}).observe({ type: 'layout-shift', buffered: true });

window.__inp = 0;
new PerformanceObserver((list) => {
  for (const e of list.getEntries()) if (e.interactionId) window.__inp = Math.max(window.__inp, e.duration);
}).observe({ type: 'event', durationThreshold: 16, buffered: true });
```

For CLS, load the template, wait for it to settle, scroll to the bottom and back, then read
`window.__cls`. Name the largest shifting node (`entry.sources[0].node`) in the finding so the
fix is aimed: the usual causes are images and iframes without `width`/`height`, a late web font
swap, and a banner or embed injected above content. For INP, press the controls the template
actually has (menu toggle, search field, first button or form field) with real input events
and read `window.__inp`; a page with nothing to press is `UNMEASURED`, not `0`. The fixes
(dimensions on media, `font-display`/preload, reserved space, splitting long handlers) belong
to Step 5, and neither check is auto-applied.

**PERF-049 — dead assets.** Glob the theme's `assets/` recursively, match the backup patterns,
sum the sizes. Move findings to an archive directory outside the theme rather than deleting:
the fix is reversible and the deploy stops carrying them.

**PERF-051 — dead references.** Extract the attribute values, resolve relative paths against
`get_template_directory()`, and `file_exists()` each one. Report the missing file, not just
the attribute.

**PERF-053 — oversized image assets.** Theme art exported from a design tool at 2x its CSS slot
is right for photographs and detailed illustration; on FLAT art it costs four times the bytes for
pixels the browser interpolates identically. Standard deviation separates the two: a photo sits
well above 0.12, a gradient far below. Downscale flat art to 1x with
`magick <file> -resize <1x width>x -quality 82 -define webp:alpha-quality=90 <out>`, then confirm
with `magick compare -metric RMSE` that the difference is negligible before replacing the file.
Mobile pays this bill twice, on a slower link, so weigh the mobile variant of an asset first.

Check the frame count before touching any file: `magick identify <file> | wc -l`. Above 1 the
asset is animated (a GIF, or an animated WebP/AVIF), and the commands above would flatten it to
its first frame while the RMSE comparison — which reads that same frame — reported no difference.
Report the weight, mark it `Auto-fix: No`, and leave the remedy to a human: an animated file that
is too heavy wants an animated WebP or a muted looping video, not a still.

**PERF-010 — moving everything to the footer has three follow-ups.** Where the finding is
"blocking scripts in `<head>`", the fix is a late pass (priority `PHP_INT_MAX`, excluding admin,
Customizer and page-builder preview) that sets every handle's group to the footer, and it breaks
three things unless handled: inline scripts printed by widgets that call `jQuery(...)` need a
`DOMContentLoaded` wrapper; removing `jquery-migrate` needs `jQuery.migrateWarnings` read on the
sampled pages first (`$(window).load(fn)` needs a shim); and a tag manager printed by an SEO
plugin can go to `data-src` loaded on first interaction or 5 s after `load`, which is a decision
for the owner. Expect FCP to improve and LCP not to move when CSS sets it. Details and
measurements: `wp-audit-standards/references/performance-lessons.md`, *JavaScript*.

**PERF-010 — where the group actually comes from.** A handle's group is set by whichever call
passes `in_footer => true`, registration or enqueue: `wp_enqueue_script()` forwards its `$args`
to `_wp_scripts_add_args_data()` whenever they are non-empty, so
`wp_register_script($h, $src, [], $v)` followed by `wp_enqueue_script($h, '', [], false, true)`
does load in the footer. Report the handle only when neither call sets it. Two asymmetries worth
knowing: passing `false` at enqueue is a no-op, so it cannot undo a `true` at registration; and a
re-registration with no flag followed by a bare `wp_enqueue_script($h)` — the usual shape when a
theme swaps a bundled library for a core handle — stays in `<head>`, which is the case this check
exists for.

Count blocking scripts from the **served HTML** (`curl` the page, read `<head>` before
`</head>`), never from `document.head` in a loaded browser. Tag managers, chat widgets and
lazy loaders insert `<script>` elements into `<head>` after load. Those scripts do not block
rendering, and counting them reports a theme that defers everything as one that defers
nothing. A head script is blocking only when the served tag has `src` and has no `defer`,
`async` or `type="module"`.

**PERF-052 — site-wide libraries.** For each third-party handle, find the template that uses
it. If exactly one does, either move the enqueue into that template behind a conditional, or
defer it as in PERF-047. Usual offenders: `aos` (scroll sections), `swiper` (carousels),
`animate` (single elements), `lightbox` (gallery pages).
