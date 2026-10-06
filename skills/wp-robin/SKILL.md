---
name: wp-robin
description: Installs, configures and unsticks the Robin Image Optimizer plugin (robin-image-optimizer) through the bundled robin-fix.sh — writes Robin's wbcr_io_* settings (WebP on, AVIF off, every registered size), clears webp queue rows stuck in processing in wp_rio_process_queue, writes the missing .webp sibling files and the queue rows Robin expects, so its bulk run stops at "X remaining" no more; also covers why a CSS background-image still serves the JPEG or PNG under Robin's webp_delivery_mode=picture. Run through /wp-robin. Use when Robin Image Optimizer is stuck, looping or never finishes its bulk optimization, keeps showing "X remaining", is missing .webp files, needs installing and configuring on a site, or when a Robin site's CSS background-image still serves the original although the .webp sibling exists. Not for ShortPixel, Imagify or EWWW, moving media to S3 (wp-s3), or uploads and thumbnails that fail to generate (/wp-debug media).
user-invocable: false
---

# wp-robin: Install, configure and unstick Robin Image Optimizer

Robin counts an attachment as done only when `wp_rio_process_queue` holds a webp queue row
for each of its sizes. When those rows are missing, or stuck in `processing`, its bulk run
shows "X remaining" forever, however often it is restarted. `robin-fix.sh` writes the `.webp`
files locally and inserts the queue rows Robin would have written, after installing and
activating the plugin if needed and writing the settings below. It compares each
attachment's files on disk with its queue rows, so a size added later (a new
`add_image_size()` plus `wp media regenerate`) is picked up too.

## Run it

1. Back up the database first — the script writes straight into it, and overwrites every
   setting in the table below on each run, `webp_delivery_mode` included (a site set to
   `url` is put back to `picture`):

   ```bash
   wp db export --path=<wp-root>
   ```

2. Run exactly this. Without `WP_ROOT` it walks up from the current directory to the first
   `wp-config.php`:

   ```bash
   WP_ROOT=<wp-root> bash "${CLAUDE_PLUGIN_ROOT}/skills/wp-robin/scripts/robin-fix.sh"
   ```

3. Read the final block. **Done when `error`, `processing` and `remaining` are all 0.**

   ```
   [+] ━━━ Final Status ━━━
     webp success:    1284
     webp error:      0
     webp processing: 0
     remaining:       0
   ```

   | Count | Means |
   |---|---|
   | `webp success` | webp queue rows Robin counts as done |
   | `webp error` | queue rows whose `.webp` file is missing: a stuck row with no file, or a conversion that failed |
   | `webp processing` | queue rows Robin still holds. The script moves every one to success or error, so a non-zero count means Robin started a batch during the run |
   | `remaining` | attachments with more files on disk than webp queue rows — Robin's "X remaining" |

4. Otherwise find the symptom under Troubleshooting, apply its fix, and run the script again.
   A second run is safe: a queue row whose hash already exists is skipped. If `error` has not
   fallen after two runs, stop and report the script's warning lines.

`scripts/webp-gd.php` is the PHP GD converter `robin-fix.sh` calls when neither ImageMagick
nor cwebp is installed, and for GIFs when cwebp is installed without `gif2webp`. Never run it by hand.

The script reads the DB credentials and table prefix from `wp-config.php` (single- or
double-quoted defines, a `DB_HOST` with a port or socket) and the site URL from the
database. The uploads directory is not discovered: it is always `<root>/wp-content/uploads`,
so a site that moved uploads elsewhere is not supported. The queue rows follow the schema of
Robin's own table; if Robin changes its columns, the inserts fail and the script reports
`queue insert failed` instead of writing anything.

## Settings it writes

Each run writes these as `wbcr_io_<setting>` rows in the options table, replacing what is
there. The spellings are Robin's own.

| Setting | Value | Why |
|---|---|---|
| `convert_webp_format` | `1` | WebP on |
| `convert_avif_format` | `0` | AVIF off |
| `webp_delivery_mode` | `picture` | `<img>` wrapped in `<picture>`, which is cache-safe. It does not reach CSS backgrounds: see below |
| `allowed_formats` | `image/jpeg,image/png,image/gif` | The formats queued. Never `image/webp`: a library that is already WebP would be re-encoded into `<name>.webp.webp` |
| `allowed_sizes_thumbnail` | WordPress's six sizes plus every `add_image_size()` and `set_post_thumbnail_size()` name found in themes and plugins | Every size gets a `.webp` file |
| `auto_optimize_when_upload` | `1` | New uploads are optimized as they arrive |
| `backup_origin_images` | `1` | Originals are kept |
| `error_log` | `1` | Robin's own log on |
| `image_optimization_level` | `normal` | Lossy |
| `image_optimization_level_custom` | `70` | Used only when the level is `custom` |
| `image_optimization_type` | `schedule` | The bulk run proceeds on Robin's cron, not in the browser tab |
| `image_autooptimize_shedule_time` | `wio_5_min` | Every five minutes |
| `image_autooptimize_items_number_per_interation` | `3` | Three attachments per run. With the interval above, the values of the production site the script was built against |
| `image_optimization_order` | `desc` | Newest first |
| `resize_larger` | `0` | Originals are not resized |
| `save_exif_data` | `1` | EXIF kept |

## WebP for CSS backgrounds

`webp_delivery_mode=picture` rewrites `<img>` tags only, so a `background-image` in an inline
style or a stylesheet keeps serving the original JPEG or PNG. The fix is in the theme
(`prefix_background_image()` in the `__tailwind__` starter) and, for stylesheets, in the
server. Read `references/webp-delivery.md` when a CSS background still serves the original
while `<img>` tags get WebP, or before changing `webp_delivery_mode`.

## Requirements

| Binary | Why |
|---|---|
| `bash` 4+, GNU `grep` (`-P`), GNU `stat` (`-c`), `sed`, `awk`, `sha256sum` | The script itself. GNU only: it does not run on macOS's BSD tools |
| `mariadb` or `mysql` client | Every query. `mariadb` is used when both exist |
| `php` CLI | Every run: decodes `_wp_attachment_metadata` and builds the queue rows |
| A converter: ImageMagick (`convert`), else `cwebp` (with `gif2webp` for GIFs; without it GIFs go to GD), else PHP GD with `imagewebp()` | Writing the `.webp` files. ImageMagick is preferred; GD reads PNG, JPEG and GIF. Without one, the queue repair still runs and no `.webp` file is written |
| `wp` (WP-CLI) | Installing and activating the plugin. Optional when the plugin is already installed and active |
| `curl`, `unzip` | Only for the direct download, tried when `wp plugin install` fails |

The script installs the plugin only through wp-cli, and downloads the WordPress.org zip only
as the fallback when `wp plugin install` fails. With no wp-cli and no plugin it stops: install
the plugin from wp-admin → Plugins, or install wp-cli, and run it again. With the plugin
installed it runs without wp-cli, but cannot activate the plugin.

## Exit codes

| Exit | Meaning |
|---|---|
| `0` | Ran to the end. Read the final counts: a `0` exit does not mean nothing failed |
| `1` | Stopped with a message: no WordPress root, unreadable credentials, no database client or `php`, the plugin not installed, the queue table missing or the database unreachable, a failed attachment or webp query, or an uploads directory it cannot write. Settings and stuck-row fixes written before the stop stay written |

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `WebP converter: NONE` | No ImageMagick, cwebp or GD with WebP | Install ImageMagick (`apt install imagemagick`, `dnf install ImageMagick`, `pacman -S imagemagick`), then run again |
| A CSS `background-image` still serves the original PNG/JPG while `<img>` tags get WebP | `webp_delivery_mode=picture` rewrites `<img>` only | Read `references/webp-delivery.md` |
| `Failed to parse DB credentials from wp-config.php` | The `DB_*` values are not literal `define()` strings (built from `getenv()`, for example) | Run with the credentials readable as literals, or fix the queue by hand |
| `settings were NOT written` | The database user cannot write the options table | Grant the privilege, or run as a user that has it |
| Hash collisions persist | The same file is shared by three or more duplicate attachments | Delete the duplicate attachment posts |
| Plugin not recognized after install | WP-CLI's activation did not run Robin's activation hooks | Activate it from wp-admin → Plugins |
| `X attachment(s) skipped — original file missing on disk` | The attachment's original file is not in `<root>/wp-content/uploads` | Restore the file, or delete the attachment. The script never queues an attachment without its original |
| Hundreds of "conversion failed" lines while the converter works | The uploads directory is not writable by the user running the script (it belongs to the web server user). The script stops with this cause before converting | Run the script as the web server user (`sudo -u <web-user> ...`) or give this user write access through the group or an ACL |
| "Queue table wp_rio_process_queue does not exist" while the plugin is active | Activating through WP-CLI did not create Robin's table | Deactivate and activate the plugin from wp-admin → Plugins, then run the script again |
