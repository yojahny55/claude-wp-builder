# /wp-seed — Phase 3

`commands/wp-seed.md` sends the run here at Phase 3 (Import Media). Follow it in order; nothing in it is optional background.

## Contents

- Seed assets by role

**Resolve by source identity** (Phase 1.5). An attachment has no slug worth matching and its
filename is rewritten on collision — `photo.jpg`, `photo-1.jpg`, `photo-2.jpg` — which is
exactly what a duplicate import looks like. So record where each attachment came from, in
the same command that imports it, and look that up before importing:

```bash
# Already imported from this source?
bash -c "$WP post list --post_type=attachment --meta_key=_<prefix>_seeded_source --meta_value='https://images.unsplash.com/photo-xxx' --format=ids"

# Not found: import, and record both the marker and the source
bash -c "HERO_IMG_ID=\$($WP media import 'https://images.unsplash.com/photo-xxx' --title='Hero Background' --post_author=$AUTHOR --porcelain) && $WP post meta add \$HERO_IMG_ID _<prefix>_seeded_content 1 && $WP post meta add \$HERO_IMG_ID _<prefix>_seeded_source 'https://images.unsplash.com/photo-xxx' && echo \$HERO_IMG_ID"
```

The source value is the URL for a remote image and the repository-relative path for a local
one (`assets/img/gen-<hash>.jpg`). Those paths already carry a content hash, so a regenerated
plate is a different source and correctly imports again.

This deduplicates by **where the bytes came from, not by the bytes**. The same image served
from two different URLs imports twice, and that is a deliberate ceiling: hashing every import
on every run costs more than the case is worth, and a duplicate attachment is a tidiness
problem rather than a correctness one — unlike a duplicate page, which splits a site's
navigation.

**Failure handling:** If a media import fails for any URL (403, redirect loop, CDN block, timeout), do NOT abort. Instead:

1. Log a warning. For a remote URL: `"WARNING: Failed to import <url> for field <field_name>.
   Skipping."` For a local file under `assets/img/gen-` — a plate this build generated and paid
   for — log a distinct line instead, so a spend that produced nothing stays visible in the seed
   report rather than folding in with a stock photo that merely 403'd:
   `"GENERATED PLATE FAILED: <path> for field <field_name>. It was generated and billed but did
   not reach the media library."`
2. Leave the ACF field empty for that image.
3. Continue with remaining imports.
4. Track all failed imports for the final seed report.

Store all successful attachment IDs mapped to their target ACF field names.

### Seed assets by role

If the manifest (produced by `wp-normalize`) has a top-level `assets[]` array, each entry carries a `role` (`logo|nav-graphic|hero|content`) plus optional `page`/`field`. After importing, route each asset by role — do not fall back to the generic field-mapping table for these:

- **`logo`** → sideload the file, then set the site logo option:
  ```bash
  bash -c "LOGO_ID=\$($WP media import '<file>' --title='Site Logo' --post_author=$AUTHOR --porcelain) && $WP eval \"update_field('site_logo', \$LOGO_ID, 'option');\""
  ```
- **`hero`** (per page) → sideload, then set that page's `inner_hero_image` field on the page identified by `asset.page`:
  ```bash
  bash -c "HERO_ID=\$($WP media import '<file>' --title='<Page> Hero' --post_author=$AUTHOR --porcelain) && $WP eval \"update_field('inner_hero_image', \$HERO_ID, <page_id>);\""
  ```
- **`content`** → sideload, then set the ACF field named in `asset.field` using the normal Phase 4 flow (options page or page-specific, per the field mapping table).
- **`nav-graphic`** → sideload and register as a theme asset only (e.g. an `nav_graphic` field or enqueued static asset). **Never** assign a `nav-graphic` to `site_logo` or any content field — a mis-tagged nav graphic must not become the seeded logo.
