# Converting PNG attachments to WebP in place

Robin adds a `.webp` sibling next to each file (`foto.png` → `foto.png.webp`). The PNG stays,
so storage grows. On a store whose uploads are mostly PNG product photos, that is the wrong
fix. This reference covers the other one: replace each PNG attachment with a WebP original,
regenerate its sizes, and point the database at the new files.

## Contents

- When to convert instead of adding siblings
- Measured on a real store
- Procedure
- Traps
- Production order

## When to convert instead of adding siblings

Convert when all of these are true:

- PNG originals are most of the uploads size. Count `post_mime_type = 'image/png'`
  attachments and `du` the uploads directory. Each attachment has about 10 sizes, all PNG.
- Few PNGs have real transparency. WebP keeps alpha, so transparency does not block the
  conversion. It only rules out JPEG as the target.
- The site owner accepts a lossy format for product photos.

Do not convert for a few large PNGs. Siblings, or a resize of those files, are enough.

## Measured on a real store

Uploads were 3.5 GB, 86% PNG: 1 449 PNG attachments, originals about 0.9 MB each.

| Option | Result on a 60-file sample |
|---|---|
| WebP q90 | 93% smaller, PSNR median 40 dB, 1 of 60 with real alpha (kept) |
| Lossless PNG recompression | 3% smaller, rejected |
| Delete unused sizes | about 50 MB: every registered size was referenced on the front end |

After the full conversion the uploads directory went from 3.5 GB to 509 MB, with 0 broken
images on the sampled templates at 1440 and 390 px.

## Procedure

1. **Back up the database.** Back up again before the URL replacement in step 4. On production
   (the direct path in *Production order*), also back up the uploads directory.
2. **Turn off Robin's auto-optimisation for the run** (`wbcr_io_auto_optimize_when_upload`
   = `0`), and restore the old value in a `finally` block. Otherwise Robin queues every
   regenerated size while the run writes them.
3. **Convert each attachment, one at a time:**
   - Read the source with `wp_get_original_image_path( $id )`. That is the unscaled original
     when a `-scaled` copy exists.
   - Write `<name>.webp` with the image editor (`$editor->save( $path, 'image/webp' )`,
     quality 90). When `<name>.webp` already exists, use `<name>-png.webp` and never
     overwrite it.
   - Update `_wp_attached_file`, `post_mime_type`, and regenerate the sizes
     (`wp_create_image_subsizes()`, which deletes nothing, or
     `wp media regenerate <id> --skip-delete`: without the flag WP-CLI removes the old size
     files before the map and the move-aside in step 7 can use them).
   - Write a **map** of every old file to its new file, relative to uploads: the original,
     the `-scaled` copy and every old size. Read the old names from the metadata before
     changing it.
   - Make the run idempotent: select only `image/png` attachments, so a second run resumes.
4. **Replace references from the map, not with a generic `.png` → `.webp` rule.** Some old
   sizes were made from the `-scaled` copy and change name: `X-scaled-130x36.png` becomes
   `X-130x36.webp`. Search every text column of the prefixed tables for `uploads/<old>`,
   plain and with JSON-escaped slashes (`uploads\/<old>`, Elementor data). Unserialize,
   replace and serialize again, so string lengths stay right. Skip `guid` and Robin's
   `rio_process_queue`: those rows describe the old PNGs. On a live site, put it in
   maintenance mode for this step and skip transients and sessions, so a write between the
   read and the replace cannot restore an old value.
5. **Flush generated CSS** (`wp elementor flush-css` on an Elementor site), then check the
   served HTML of each template. Every `uploads/` URL must exist on disk, and no `.png`
   from uploads may remain. On production, purge the page cache and the CDN first and
   check the served HTML again: a cached page still names the PNGs, and step 7 would turn
   those URLs into 404s.
6. **Redirect old URLs, only for PNGs that are gone.** A server rule runs before the file
   check, so without a condition it also redirects PNGs that still exist — non-attachment
   files, and every converted PNG until step 7 moves it — to a `.webp` that may not exist.
   Apache, above the WordPress block:

   ```apache
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{DOCUMENT_ROOT}/wp-content/uploads/$1.webp -f
   RewriteRule ^wp-content/uploads/(.+)\.png$ /wp-content/uploads/$1.webp [R=301,L]
   ```

   nginx, before any generic static-file `location` that also matches `.png`:

   ```nginx
   location ~ ^/wp-content/uploads/(?<png_base>.+)\.png$ {
       if (!-f $request_filename) { return 301 /wp-content/uploads/$png_base.webp; }
   }
   ```

   Apply it in production's own server config: the clone's does not sync. A redirect plugin
   (Rank Math, Redirection) needs no condition, since WordPress never sees a file that exists.
7. **Move the old files aside, do not delete them.** Move each old path from the map, plus
   its Robin `<file>.png.webp` sibling, to a backup folder outside uploads. Check the site
   again, then report the new uploads size.

## Traps

- **An interrupted run leaves one attachment half done.** Its mime type and file already
  say WebP, but its metadata has one size and the map has no rows for it. Before you resume,
  take its old metadata from the backup, add its map rows by hand, and regenerate its sizes.
- **Image-editor backups keep PNG names.** The `-e<timestamp>` files and
  `_wp_attachment_backup_sizes` are not converted. "Restore original image" in the media
  editor breaks for those attachments once the PNGs are moved.
- **The generic redirect misses renamed files.** A file renamed to `<name>-png.webp` because
  of a name clash, and a `-scaled` size that changed name, answer 404 at the old URL. Add an
  exact redirect when those URLs matter.
- **Theme demo URLs stay `.png`.** References to the theme vendor's demo content on another
  host are not in the map, and they do not need to be.

## Production order

Run the conversion on a local clone first, as a rehearsal. Then pick one path for production.

- **Production takes no writes between the clone and the push** (a brochure site, or a
  freeze you control). Re-clone, convert, check step 5, then push the database and uploads.
  There are no images uploaded after the clone to handle. Back up production's database and
  uploads first, and keep writes frozen until the push finishes.
- **Production keeps taking writes** (a store with orders, a site with editors). Do not push
  the clone's database: it overwrites orders, customers and attachment rows created since the
  clone. Run this procedure directly on production instead: back up the database and the
  uploads directory, then follow step 3 onwards with the map built there. The clone stays a
  rehearsal.

In both paths, old PNGs are moved to a backup folder outside uploads, as in step 7. Deleting
them is a separate decision for the operator, made after the production site is verified.
When the sync tool deletes remote files that are missing locally, check what it removes
before it runs.
