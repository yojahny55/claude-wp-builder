# WebP delivery: what `picture` mode does not cover

Robin writes a sibling file per image, `<original>.webp` (`foto.png` → `foto.png.webp`), for the original and every registered size. Delivering it is a separate setting, `webp_delivery_mode`, and its default covers `<img>` tags only:

| Mode | What it does | Cost |
|---|---|---|
| `picture` (default, what `robin-fix.sh` sets) | Wraps `<img>` in `<picture>` with a WebP `<source>` | A `background-image` in an inline style or a stylesheet still serves the original JPEG/PNG |
| `url` | Rewrites image URLs from the request's `Accept` header | Unsafe behind a full-page cache: the cached HTML then carries one format for every visitor. Only for a site with no page cache, or one that varies its cache key on `Accept` |
| `picture` or `url`, AJAX/REST responses | Neither covers HTML returned by `admin-ajax.php` or the REST API: Robin hooks `template_redirect`, so only the full page is processed | Infinite scroll, tabs and "load more" keep serving the original PNG/JPEG. See "HTML returned by admin-ajax or REST" below |
| `none` | Serves originals; the `.webp` files sit unused | Nothing is delivered |

So a theme that paints hero and section backgrounds through CSS gets no WebP at all by default. Close it in the theme first; add the server rule when a stylesheet (which no PHP helper reaches) paints backgrounds too. The two compose.

1. **In the theme (no server access needed).** The `__tailwind__` starter's `inc/performance.php` carries `prefix_background_image( $url )`, which emits `background-image:url(…)` followed by an `image-set()` that names the `.webp` sibling, and an HTML output-buffer that swaps uploads URLs for their sibling in `<img src>`, `srcset` and inline styles. Both recognize Robin's appended naming (`foto.png.webp`) as well as the replaced-extension naming (`foto.webp`). This is cache-safe, because each browser requests the URL it understands.

2. **In the server (covers a stylesheet too).** Serve the sibling by content negotiation, and declare it with `Vary: Accept` so a shared cache keys on it. A CDN that ignores `Vary` will still poison one format for everyone — check yours before choosing this.

   ```nginx
   map $http_accept $webp_suffix { default ""; "~*image/webp" ".webp"; }
   location ~* ^/wp-content/uploads/.+\.(png|jpe?g)$ {
       add_header Vary Accept;
       try_files $uri$webp_suffix $uri =404;
   }
   ```

   ```apache
   # wp-content/uploads/.htaccess
   <IfModule mod_rewrite.c>
   RewriteEngine On
   RewriteCond %{HTTP_ACCEPT} image/webp
   RewriteCond %{REQUEST_FILENAME}.webp -f
   RewriteRule ^(.+)\.(png|jpe?g)$ $1.$2.webp [T=image/webp,L]
   </IfModule>
   <IfModule mod_headers.c>
   <FilesMatch "\.(png|jpe?g)$">Header append Vary Accept</FilesMatch>
   </IfModule>
   ```

   Both rules assume Robin's appended naming. Leave `webp_delivery_mode` at `picture`: the server rule and `<picture>` do not conflict.

## HTML returned by admin-ajax or REST does not pass through `template_redirect`

**Symptom.** The first page load gets WebP, but cards added by infinite scroll, a tab or a
"load more" button request the `.png`/`.jpg` although the `.webp` sibling exists. On a real
build the same card image weighed 354 KB against 39 KB.

**Measure.** Request the endpoint and count originals that have a sibling:

```bash
curl -s -X POST -d 'action=<action>&<params>' <site>/wp-admin/admin-ajax.php > ajax.html
grep -oE 'src="[^"]+\.(png|jpe?g)"' ajax.html | sed 's/src="//;s/"$//' | while read -r u; do
  f="<wp-root>/wp-content/uploads/${u#*/wp-content/uploads/}"
  [ -f "$f.webp" ] || [ -f "${f%.*}.webp" ] && echo "has webp, served as original: $u"
done
grep -c '<picture' ajax.html
```

**Recipe.** Add a theme helper that reuses Robin's own processing for a string of HTML, and
run it on the handler's output, so no second WebP implementation exists. Robin's classes are
static, but its HTML processor is loaded only for front-end page requests, so the helper has
to load it itself:

1. Check availability **before** starting any buffer (`class_exists` on Robin's delivery
   class, and the processor file readable). If it is not available, return the HTML untouched.
   A buffer opened first and then abandoned on a missing class swallows the response.
2. Load the processor, then `ob_start()` with a callback that passes the HTML through Robin's
   method, on a hook of **early priority** (for example `wp_ajax_*` at priority 1, or
   `admin_init` for `DOING_AJAX`), so it wraps whatever the handler echoes.
3. Never throw from the callback: on any failure return the input unchanged.

**Warning.** This couples the theme to Robin's internal class and method names, which are not
a public API. Re-check the helper after every Robin update (PERF-078 in `/wp-audit` catches
the regression: the images come back without `<picture>`).

## Do not convert a background whose `.webp` is not smaller

WebP is not always smaller: a flat-colour or already-optimized PNG can come out heavier.
Before serving the sibling for a CSS background, or before adding a `preload` for it, compare
the two sizes with `stat -c %s`. When the `.webp` weighs the same or more than the original
(`>=`), leave the original in place and do not preload the sibling; the swap would add bytes.
