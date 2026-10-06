# WebP delivery: what `picture` mode does not cover

Robin writes a sibling file per image, `<original>.webp` (`foto.png` → `foto.png.webp`), for the original and every registered size. Delivering it is a separate setting, `webp_delivery_mode`, and its default covers `<img>` tags only:

| Mode | What it does | Cost |
|---|---|---|
| `picture` (default, what `robin-fix.sh` sets) | Wraps `<img>` in `<picture>` with a WebP `<source>` | A `background-image` in an inline style or a stylesheet still serves the original JPEG/PNG |
| `url` | Rewrites image URLs from the request's `Accept` header | Unsafe behind a full-page cache: the cached HTML then carries one format for every visitor. Only for a site with no page cache, or one that varies its cache key on `Accept` |
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
