# Shipped scripts — what each one measures

Detail for the scripts in `wp-cli-patterns/scripts/`: why each check is shaped the way it is and
how to read what it prints. How to run each one, and what its exit code means, is in
`wp-cli-patterns` itself.

## Contents

- `check-dev-host.php` — the development host, in four tables
- `find-orphan-acf-ids.php` — IDs that outlive the post
- `audit-menu-links.php` — menu items that go nowhere
- `find-redeclared-functions.php` — one global function, two sources (SEC-043)
- `find-missing-media-files.php` — attachments whose file is gone (WP-060/061/062)

---

## `check-dev-host.php` — the development host, in four tables

Sweep `postmeta`, `posts` and `termmeta`, never `options` alone. `options` holds the least of
this and is the only table people check. The rows that actually reach the page are elsewhere:
a `custom` menu item stores its target verbatim in `postmeta._menu_item_url`, so after a push
it is a navigation link that leaves the live site, and an absolute URL pasted into
`post_content` is the same defect inside an article body. On one audited site `options` alone
reported 7 occurrences and the full sweep reported 25.

`home` and `siteurl` are excluded — they are what makes the local install work. A `guid` match
is counted separately and never rewritten: WordPress treats a `guid` as a historical
identifier, not a URL, and changing it breaks the key feed readers use.

## `find-orphan-acf-ids.php` — IDs that outlive the post

Deleting a post from wp-admin does not clear its ID out of the relationship and post-object
fields that point at it. A template that iterates such a field prints one card with no title,
no terms and an empty `href` — a visible defect produced by a record that no longer exists.

Two things the script does that a hand-written sweep usually does not:

- **It resolves the field's type before treating a value as an ID.** A date field holds
  `20250910` and a number field holds `142`; both are numeric, neither is a post ID, and
  `get_post_status()` answers `false` for both. Skipping the type lookup turned 70 real
  orphans into 248 reported ones, every extra a false positive.
- **It splits by whether a template reads the field.** Pass the theme path and each finding is
  `REACHES-TEMPLATE` or `DEAD-DATA`. On the audited site 70 orphans existed and exactly 1
  reached the HTML — a flat list of 70 buries the one that is visible.

A non-`publish` status is the same defect with a different cause and is reported too:
`get_post_status()` returns `draft` or `trash` rather than `false`, and a trashed post still
has a permalink the template will print.

## `audit-menu-links.php` — menu items that go nowhere

A `custom` menu item stores its target in `postmeta._menu_item_url`, verbatim, so a broken menu
link is invisible to anything that reads the theme. It reports `#` and empty URLs, and absolute
URLs on the development host.

It walks **every** menu, not only the ones assigned to a registered location: a menu assigned
through a nav-menu widget has no location, and on the audited site that is exactly where the
broken items were.

**Items with children are excluded, and that exclusion is not optional.** A `custom` item with
`#` that has children is a submenu header — it is not supposed to navigate. Without the
exclusion the check fires on almost every menu that has a submenu, and the real findings are
lost in the noise.

Fix by converting the item to a `post_type` item rather than by editing its URL. A `post_type`
item derives its URL from `siteurl` at render time and survives a migration; a `custom` item
carries whatever host was typed into it, which is how `check-dev-host.php` findings are created.

## `find-redeclared-functions.php` — one global function, two sources (SEC-043)

It tokenizes instead of grepping. A `function <name>(` grep over one real `wp-content` matched
about 160,000 lines; the tokenizer found about 4,000 global declarations in ~15,600 files, in
under 2 seconds. It knows which braces belong to a class, a function or an
`if` / `elseif` guard that negates `function_exists`, `class_exists`, `interface_exists`,
`trait_exists`, `enum_exists` or `defined` (braced, `:`/`endif;` or braceless), qualifies
names by namespace, ignores `use function` imports, recognises `enum` bodies on runtimes
older than 8.1, and treats a top-level `if ( function_exists() ) return;` (or any of those
tests) as guarding the rest of the file. The whole condition is read, not its first test: a
negated test guards from any operand of an `&&` chain, but not next to an `||`, where the
body also runs when the other operand holds; an early return guards only when the test sits
in an `||` chain (or alone).

Skipped: `vendor/`, `node_modules/`, `tests/`, `examples/`, and — inside a plugin or theme
directory — `object-cache.php` and `advanced-cache.php`. Those are the drop-in templates a
cache plugin copies into `wp-content/`; on the audited site they produced 56 of 57
collisions, each plugin against its own installed drop-in. Other drop-in names (`db.php`,
…) are scanned: a plugin's own `includes/db.php` is ordinary code. A drop-in passed as a
single file, parked `*.bak` included, is always scanned.

## `find-missing-media-files.php` — attachments whose file is gone (WP-060/061/062)

An attachment post survives the deletion of its own file, so nothing in core notices a broken
`<img>` or a 404 download. The script walks every attachment in batches and resolves its main
file, each registered image sub-size and the pre-scale `original_image` against the uploads
directory, joining the bare sub-size filenames to the attachment's own `YYYY/MM` folder. It
counts every miss and prints a sample per bucket (20 by default), never the whole list. A
stored value that is not a local path (a remote or CDN URL, an empty or corrupt entry) is
never checked against disk: it is counted and reported as skipped, not as missing.

`archive-date` is `Y-m-d` or `Y-m-d H:i:s`, in the site's timezone, and is only for a local
clone whose file archive predates its database (`/wp-audit` Step 2.3). A miss whose attachment
was uploaded after that moment is `AFTER-ARCHIVE`: it exists in production, not in this copy's
archive. A bare date is pushed to 23:59:59, so an upload on the archive day itself is never
waved through. With no argument every miss is `UNDATED`.
