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

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| No webp converter found | Missing ImageMagick/cwebp/PHP GD | `pacman -S imagemagick` or `apt install imagemagick` |
| DB connection fails | Credentials use non-standard wp-config format | Check `define('DB_*'` lines in wp-config |
| Hash collisions persist | Same file shared by 3+ duplicate posts | Manual cleanup of duplicate attachment posts recommended |
| Plugin not recognized after install | wp-cron hasn't run activation hooks | Visit WP admin → Plugins → activate manually |
