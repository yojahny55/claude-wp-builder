# Performance procedures — cache drop-in, ICC profiles, Elementor

Part of the `wp-audit-standards` skill. Moved verbatim out of `agents/wp-audit-performance.md` so the agent does not carry it on every dispatch; the agent's index names when to read it. Read before running PERF-070, PERF-075, PERF-076 or PERF-077.

## Contents

- Procedure — page-cache drop-in without its plugin (PERF-070)
- Procedure — embedded ICC profiles on images (PERF-075)
- Procedure — Elementor widget controls queried on the front end (PERF-076)
- Procedure — missing Elementor generated CSS (PERF-077)
- Procedure — AJAX-returned images and WebP (PERF-078)

### Procedure — page-cache drop-in without its plugin (PERF-070)

A page-cache plugin writes `wp-content/advanced-cache.php` and sets `WP_CACHE` to true in
`wp-config.php`. Deactivating the plugin from wp-admin does not always undo both, and
WordPress loads the drop-in on every request for as long as `WP_CACHE` is true, before any
plugin. The drop-in can then keep serving pages from the old cache with nothing left to purge
it, so an edit does not show up, or it runs code for a plugin that is gone.

**On a local clone this is usually not a defect.** `/wp-audit` Step 2.3 deactivates the
page-cache plugin on purpose and lists it under `Clone-suppressed plugins`. The drop-in and
`WP_CACHE` came with the copy from production, where the same plugin is active and the drop-in
belongs. Read the clone context lines from the dispatch, by the names the security agent uses
(`Local clone`, `Clone-suppressed plugins`). Never guess them from which plugins are inactive.

Read the drop-in and the constant once:

```bash
$WP eval 'echo defined("WP_CACHE") && WP_CACHE ? "WP_CACHE=on" : "WP_CACHE=off", PHP_EOL;'
head -c 2000 wp-content/advanced-cache.php
$WP plugin list --fields=name,status --format=csv
```

Find the owner from markers in the file. Examples: `SWCFPC_ADVANCED_CACHE` is Super Page
Cache (`wp-cloudflare-page-cache`), `WPCACHEHOME` is WP Super Cache (`wp-super-cache`),
`WP_ROCKET_ADVANCED_CACHE` is WP Rocket (`wp-rocket`), `W3TC` is W3 Total Cache
(`w3-total-cache`), `LSCACHE_ADV_CACHE` is LiteSpeed Cache (`litespeed-cache`). When no marker
matches, look for an installed plugin's slug written in the file (most drop-ins include a path
under `wp-content/plugins/<slug>/`).

| State | Result |
|---|---|
| No `advanced-cache.php` | pass |
| Owner found and active | pass |
| `WP_CACHE` off | `INFO`: the file is not loaded; it is a leftover to delete or a cache to turn back on |
| `WP_CACHE` on, owner inactive or not installed, `Local clone: yes`, owner on `Clone-suppressed plugins` | no finding; print `PERF-070: clone artifact — <slug> is clone-suppressed (active on production)` |
| `WP_CACHE` on, owner inactive or not installed, any other case | `WARNING` |
| `WP_CACHE` on, no owner found | `INFO`, with the drop-in's first comment lines as evidence |

The message for the `WARNING` is `advanced-cache.php from <slug> loads on every request, but
<slug> is <inactive|not installed>`. The fix is manual: reactivate the plugin, or remove the
drop-in and set `WP_CACHE` to false. Which one depends on whether the site owner still wants
that cache, so it is never auto-applied. A clone that removed the drop-in or parked it as
`advanced-cache.php.bak` is already covered by Step 2.3 and is not this check.

### Procedure — embedded ICC profiles on images (PERF-075)

Print and photo tools export JPEGs with the full CMYK press profile attached (often
0.5 to 2MB). Image editors and generators copy it into every resized copy and every WebP made
from it, so a 300px thumbnail can weigh more than a full photo. Browsers have to parse the
profile, and CMYK JPEGs render inconsistently.

Skip files that are missing on disk; a file this check cannot read is not a finding, and a
clone whose file archive predates the database is covered by Step 2.3. The result is a property of
the file bytes, so a local clone and production give the same answer and nothing is suppressed.

```bash
$WP eval 'echo wp_get_upload_dir()["basedir"];'
find <basedir> -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
  -not -path '*/woocommerce_uploads/*' -print0 \
  | xargs -0 -n1 magick identify -format '%[colorspace]|%[profile:icc]|%b|%i\n' 2>/dev/null
```

`%[profile:icc]` is a presence test for the profile (it names it); read its byte size with
`magick <file> icc:- 2>/dev/null | wc -c` or `exiftool -s3 -ProfileSize`. Flag a file when the profile is over 100KB or the colorspace is
`CMYK`. Group the files by attachment: resolve each path to its attachment ID with
`$WP db query` on `_wp_attached_file`
(or by stripping the `-<w>x<h>` size suffix) and report IDs, file count, and the total profile
bytes, since one source image usually explains dozens of files (every generated size plus its
WebP).

Report `WARNING` listing attachment IDs, file counts and bytes recoverable. The fix is manual:
back up the originals first, then strip or convert, then regenerate the sizes and WebP copies:

```bash
magick in.jpg -profile sRGB.icc -strip out.jpg   # CMYK source: convert to sRGB first
magick in.jpg -strip out.jpg                      # sRGB or untagged source: drop the profile
$WP media regenerate <ids> --yes                  # rebuild sizes; re-run the WebP optimizer
```

Converting colour changes how an image looks, so this is never auto-applied.

### Procedure — Elementor widget controls queried on the front end (PERF-076)

Elementor registers a widget's controls whenever it builds the widget, and that includes
rendering the page on the front end, not only the editor. A third-party widget that fills a
select control with `WC_Product_Query`, `get_posts` or `get_terms` and no limit therefore runs
that query on every uncached page view. On a catalog of about 1,800 products one such widget
cost about 0.85s and 280MB of peak memory per home render; limiting it to the editor cut the
page's TTFB from 1.50s to 0.83s.

Static half (the same on a clone and on production). Find the functions and look at the
queries inside:

```bash
grep -rnE "function _?register_controls" wp-content/plugins wp-content/themes --include=*.php -l
# then, in those files, the unbounded forms:
grep -nE "posts_per_page'?\"? *=> *-1|'limit' *=> *-1|numberposts'? *=> *-1|get_terms\(" <file>
```

Only active plugins and the active theme count. Confirm the query sits inside the
`register_controls` body (or a helper it calls) and not in an AJAX or editor-only callback. For
the general unbounded-query rule see WP-026 in `agents/wp-audit-practices.md`; this check is
the Elementor-specific case WP-026 cannot see, because the cost is hidden behind a control
dropdown and not in a template.

Runtime half. Time key templates (home, shop, a product, a category) with the cache bypassed,
several runs each, and take the median:

```bash
for i in 1 2 3 4 5; do curl -s -o /dev/null -H 'Cache-Control: no-cache' \
  -w '%{time_starttransfer}\n' "<url>?nocache=$RANDOM"; done
```

On a local clone absolute seconds are not production's (see Step 3), so a clone reports the
static half as the finding and the timing as relative only (compare pages with each other,
never with the threshold). Elsewhere flag a template whose median TTFB is over 0.8s.

Report `WARNING` naming the file, the function and the query. The fix is manual and the
generic pattern is a filter limited to the front end: hook `pre_get_posts` (or the query-args
filter the widget exposes) and return early unless `! is_admin()`, `! wp_doing_ajax()`,
`! defined('REST_REQUEST')` and the request is not an Elementor preview or editor; and only
when a `debug_backtrace()` of limited depth shows the call comes from that widget's
`register_controls`. Then compare the rendered HTML before and after: it must be identical.
Editing the third-party plugin is not an option, since an update erases it.

### Procedure — missing Elementor generated CSS (PERF-077)

Elementor writes each page's CSS to `uploads/elementor/css/post-<id>.css` and references it
with a `?ver=` query. Some updates and plugin activations empty that folder. Pages then
request files that no longer exist. A plain `404` costs a round trip and leaves sections
unstyled, and with a redirect or "404 to home" plugin the request is answered with the home
page's HTML as a `3xx` chain ending in a full page served as CSS: wasted bytes and still
unstyled.

```bash
curl -s <page-url> | grep -oE "[^\"']*uploads/elementor/css/[^\"'?]*\.css[^\"']*" | sort -u
curl -sI -o /dev/null -w '%{http_code} %{content_type} %{redirect_url}\n' <css-url>   # one per file
```

Do this for the key templates (home, shop, a product, a category, a built page). Flag a
file that answers `404`, any `3xx`, or a `200` whose content type is not `text/css`. The
result is the same on production, so nothing is suppressed on a local clone, with one
exception: if the clone's `uploads/elementor` is absent altogether and attachments are also
missing on disk, the file archive left it out and the check is `INFO: inconclusive, uploads not
restored`, not a finding.

Report `WARNING` with the URLs and statuses. The fix is `$WP elementor flush-css` (regenerates
on demand) and, where Elementor's Tools screen offers it, Regenerate CSS & Data. If the folder
keeps emptying, an on-demand regeneration mu-plugin may be proposed, and note the setting
Elementor, Settings, Advanced, CSS Print Method: `Internal Embedding` stops the file requests
altogether, at the cost of inline CSS per page. Neither is auto-applied.

### Procedure — AJAX-returned images and WebP (PERF-078)

Robin wraps `<img>` in `<picture>` on `template_redirect`, which is the full page. HTML built
by `admin-ajax.php` (infinite scroll, tabs, "load more") never passes through it, so those
images keep serving the PNG or JPEG although the `.webp` sibling exists (354 KB against 39 KB
on a real build). The fix and its caveats are in `skills/wp-robin/references/webp-delivery.md`.

```bash
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
grep -rnE "wp_ajax(_nopriv)?_[a-z0-9_]+" <theme-dir> --include=*.php      # actions
curl -s -X POST -d 'action=<action>&<params>' <site>/wp-admin/admin-ajax.php > "$T/ajax.html"
grep -oE '<img[^>]+src="[^"]+\.(png|jpe?g)"' "$T/ajax.html"               # then test each for a .webp sibling and a <picture> parent
```

Read the handler for the parameters and nonce it needs. A nonce or login wall that cannot be
reproduced makes the check `UNMEASURED`, not `PASS`. Report the count and the bytes the
siblings would save (`stat` both files). Do not auto-apply: the recipe couples the theme to
Robin's internal classes and needs the owner's decision.

