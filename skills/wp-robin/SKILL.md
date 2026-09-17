---
name: wp-robin
description: Fix Robin Image Optimizer — installs plugin if missing, configures optimal settings, unsticks the bulk optimization loop, generates missing .webp files locally, and syncs the queue database so the plugin recognizes all conversions. Use when the user says Robin Optimizer is stuck, frozen, looping, not finishing, missing webp files, needs setup, or wants to install and configure it properly. Also use for "optimize all images", "configure image optimizer", or when Robin shows "X remaining" but never completes.
user-invocable: false
---

# wp-robin: Install, configure, and fix Robin Image Optimizer

## What this skill does

1. **Installs** Robin Image Optimizer if missing (via wp-cli or direct download)
2. **Configures** the plugin with proven settings — WebP enabled, AVIF off, all thumbnails included, backup enabled, auto-optimize on upload
3. **Detects all registered thumbnail sizes** from the theme/plugins and adds them to the optimization list
4. **Fixes stuck items** — webp queue items frozen in `processing` status
5. **Registers attachments for optimization** if the queue is empty
6. **Generates missing .webp files** locally using ImageMagick, cwebp, or PHP GD
7. **Syncs the database** — inserts correct `wp_rio_process_queue` records with proper sha256 hashes and file sizes
8. **Handles hash collisions** from duplicate posts sharing the same file (uses `$url|webp|$post_id` fallback)

## How to use

Run the bundled script. It auto-detects the WordPress root (walks up from current directory), reads DB credentials from `wp-config.php`, and discovers the site URL and uploads directory.

```bash
bash <path-to-skill>/scripts/robin-fix.sh
```

To target a specific WordPress install:

```bash
WP_ROOT=/srv/http/mysite bash <path-to-skill>/scripts/robin-fix.sh
```

## Settings applied

The script installs these reference settings (optimized for a production site):

| Setting | Value |
|---------|-------|
| WebP conversion | On |
| AVIF conversion | Off |
| Auto-optimize on upload | On |
| Backup originals | On |
| Error log | On |
| Optimization level | Normal (lossy) |
| Thumbnails included | All registered sizes (auto-detected from theme + plugins) |

## Requirements

- **bash** and standard Unix tools (grep, sed, stat, sha256sum)
- **mariadb** or **mysql** client (for DB queries)
- One of: **ImageMagick** (`convert`), **cwebp**, or **PHP GD** (for webp generation)
- **wp-cli** (optional — for installing/activating the plugin)

## When wp-cli is not available

If wp-cli isn't found and the plugin isn't installed, the script falls back to downloading the plugin zip from WordPress.org and extracting it. Activation must be done manually (or install wp-cli).

## What to expect

The script reports each step:
- Plugin installation/activation status
- Settings applied (thumbnails discovered)
- Stuck items fixed (processing → success/error)
- Attachments registered for optimization
- Webp entries synced per attachment
- Final summary: total webp success/error/processing + remaining orphans

## WebP delivery: what `picture` mode does not cover

Robin writes a sibling file per image, `<original>.webp` (`foto.png` → `foto.png.webp`), for the original and every registered size. Delivering it is a separate setting, `webp_delivery_mode`, and its default covers `<img>` tags only:

| Mode | What it does | Cost |
|---|---|---|
| `picture` (default, what this script sets) | Wraps `<img>` in `<picture>` with a WebP `<source>` | A `background-image` in an inline style or a stylesheet still serves the original JPEG/PNG |
| `url` | Rewrites image URLs from the request's `Accept` header | Unsafe behind a full-page cache: the cached HTML then carries one format for every visitor. Only for a site with no page cache, or one that varies its cache key on `Accept` |
| `none` | Serves originals; the `.webp` files sit unused | Nothing is delivered |

So a theme that paints hero and section backgrounds through CSS gets no WebP at all by default. Two ways to close it, and they compose:

1. **In the theme (no server access needed).** The `__tailwind__` starter's `inc/performance.php` carries `prefix_background_image( $url )`, which emits `background-image:url(…)` followed by an `image-set()` that names the `.webp` sibling, and an HTML output-buffer that swaps uploads URLs for their sibling in `<img src>`, `srcset` and inline styles. Both recognize Robin's appended naming (`foto.png.webp`) as well as the replaced-extension naming (`foto.webp`). This is cache-safe, because each browser requests the URL it understands.

2. **In the server (covers a stylesheet too, which no PHP helper can reach).** Serve the sibling by content negotiation, and declare it with `Vary: Accept` so a shared cache keys on it. A CDN that ignores `Vary` will still poison one format for everyone — check yours before choosing this.

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

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| No webp converter found | Missing ImageMagick/cwebp/PHP GD | `pacman -S imagemagick` or `apt install imagemagick` |
| A CSS `background-image` still serves the original PNG/JPG while `<img>` tags get WebP | `webp_delivery_mode=picture` rewrites `<img>` only | Use the theme helper and the output buffer, or add the server rule — see "WebP delivery: what `picture` mode does not cover" above |
| DB connection fails | Credentials use non-standard wp-config format | Check `define('DB_*'` lines in wp-config |
| Hash collisions persist | Same file shared by 3+ duplicate posts | Manual cleanup of duplicate attachment posts recommended |
| Plugin not recognized after install | wp-cron hasn't run activation hooks | Visit WP admin → Plugins → activate manually |
| "X attachment(s) skipped — original file missing on disk" but the files are there | A client that escapes the newlines `TO_BASE64()` wraps its output with, so the metadata decodes to garbage | Fixed in the script — the wrap is stripped server-side. On an older copy, check that the step 4 query wraps `TO_BASE64()` in `REPLACE(..., '\n', '')` |
| `<name>.webp.webp` files appear next to the originals | The media library is already WebP, so there is nothing to convert | Nothing to do — the script only queues the mime types in `allowed_formats`, which does not include `image/webp`. On an older copy the list was hardcoded: delete the duplicates and their `item_type='webp'` rows |
