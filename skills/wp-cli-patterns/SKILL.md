---
name: wp-cli-patterns
description: WP-CLI-first principle — use WP-CLI instead of generating PHP code whenever possible, with command reference, ACF seeding patterns, and environment-aware execution
user-invocable: false
trigger: auto-invoke when .wp-create.json exists in project root
---

# WP-CLI Patterns — Best Practices for All Agents

This skill teaches the **WP-CLI-first principle**: use WP-CLI commands instead of generating PHP code whenever possible. WP-CLI saves tokens, reduces errors, and executes faster than writing throwaway PHP files.

---

## Core Rule: WP-CLI Over PHP Generation

**Always prefer a single WP-CLI command over generating PHP code.**

```
# BAD (costs tokens): Generate PHP file with update_option()
# GOOD (1 line):      $WP option update my_option 'value'

# BAD:  Generate PHP with wp_insert_post()
# GOOD: $WP post create --post_type=page --post_title='About' --post_status=publish

# BAD:  Generate PHP with wp_create_nav_menu()
# GOOD: $WP menu create "Primary EN" && $WP menu item add-post primary-en 5

# BAD:  Generate PHP to activate a plugin
# GOOD: $WP plugin activate secure-custom-fields

# BAD:  Generate PHP to set permalink structure
# GOOD: $WP rewrite structure '/%postname%/'
```

Use `wp eval` only when no dedicated WP-CLI subcommand exists for the operation (e.g., calling ACF's `update_field()` API).

---

## Non-Trivial Seed Logic Lives in `inc/seed/`, Never in a Scratchpad

The rule above is about a single throwaway operation. It does not cover
anything a project needs to **re-run** — content re-seeded after a later pass
recreates records (a translation import that builds new counterparts, a
taxonomy retrofit), a bulk import worth re-checking, or any script whose
inputs are worth keeping. Writing that kind of script into a session's
scratchpad has the same failure shape every time: the records it created land
in the database and survive, the code that reproduces them does not, and a
fresh clone of the repository — or a rollback — has no way to get them back.

- **The script goes in `<theme>/inc/seed/<name>.php`**, any data payload it
  needs in `<theme>/inc/seed/data/`, however small either looks at the time.
  Run it with `wp eval-file <path>`.
- **Every record it writes carries a marker** — post meta or term meta named
  `_<prefix>_seeded_content` — so a later run, or a later script, can tell
  which records are this script's own and which are the client's.
- **A record meant to be found again across runs carries a stable key** —
  `_<prefix>_seed_key` — instead of being re-identified by its numeric post
  ID. An ID is only meaningful on the install that generated it; a fresh
  install, a staging copy or a later environment has no way to match "record
  14" back to anything. Matching by the marker's key lets a second run update
  the same record in place instead of duplicating it.
- **A client's own edit always wins.** Compare before writing: if the target
  no longer carries the marker (or its content diverges from what the script
  last wrote), leave it alone. The point of the marker is exactly this
  comparison — without it, a re-run cannot tell "still ours to update" from
  "the client changed this on purpose," and silently overwrites the client's
  work.

**Whether those scripts are committed is the project's call.** Versioning them
is the default, and it is what the paragraph above is arguing for: a clone, a
fresh environment or a rollback then carries the code that reproduces the
content, not just the content. A project that moves its database by hand
between environments may decide the opposite and gitignore `inc/seed/` — the
content travels in the dump, and nothing in the theme loads a seeder at
runtime, so no deploy misses them. What that trades away is exactly the
reproducibility above: the records survive only as long as somebody still has
a dump, and the script that made them lives on one machine. Either way the
scripts still belong in `inc/seed/` rather than a scratchpad. Decide it once,
write the decision in the project's `CLAUDE.md`, and honour it there instead of
re-opening it file by file.

This is unrelated to the WP-CLI-vs-PHP-generation rule above: a script that
belongs in `inc/seed/` should still prefer `update_field()` / WP-CLI functions
over hand-rolled SQL inside it — the two rules compose, they do not conflict.

---

## The `$WP` Convention

Throughout all commands, agents, and skills, **`$WP`** is shorthand for the value of `wp_cli.wrapper` from `.wp-create.json`. Agents read this value and substitute it into all WP-CLI commands.

For example, if the environment is Docker:

```bash
# $WP expands to:
docker exec my-project-wp wp --allow-root

# So this command:
$WP option update blogname "My Site"

# Becomes:
docker exec my-project-wp wp --allow-root option update blogname "My Site"
```

**How to read `$WP`:** Parse `.wp-create.json` at the project root and extract the `wp_cli.wrapper` value. Every WP-CLI command in this skill assumes `$WP` is set to that value.

---

## Environment-Aware Execution

Agents read `wp_cli.wrapper` from `.wp-create.json` and prepend it to all WP-CLI commands. The wrapper value depends on the environment type:

| Environment | `wp_cli.wrapper` value | Notes |
|-------------|----------------------|-------|
| Native | `wp --path=/var/www/html/my-project` | Direct CLI, requires WP-CLI installed on host |
| Docker | `docker exec my-project-wp wp --allow-root` | Executes inside WordPress container |
| DDEV | `ddev wp` | DDEV proxies to the web container |
| Lando | `lando wp` | Lando proxies to the appserver container |
| wp-env | `npx wp-env run cli wp` | wp-env proxies to its CLI container |

**Important:** Never hardcode the execution method. Always read the wrapper from the manifest so commands work across all environments.

---

## Environment Detection: Reading `.wp-create.json`

The `.wp-create.json` manifest is generated by `/wp-create` at the project root. It is the single source of truth for all commands, agents, and skills.

```bash
# Check if manifest exists
if [ -f .wp-create.json ]; then
    # Extract the WP-CLI wrapper
    WP=$(jq -r '.wp_cli.wrapper' .wp-create.json)

    # Extract other useful values
    PROJECT_SLUG=$(jq -r '.project.slug' .wp-create.json)
    PRIMARY_LANG=$(jq -r '.languages.primary' .wp-create.json)
    ADDITIONAL_LANGS=$(jq -r '.languages.additional[]' .wp-create.json)
    ENV_TYPE=$(jq -r '.environment.type' .wp-create.json)
fi
```

When `.wp-create.json` does **not** exist, WP-CLI features are unavailable. Fall back to file-only operations (the pre-existing behavior).

---

## WP-CLI Command Reference

All 16 domains agents should know. Every command below is prefixed with `$WP` in practice.

| Domain | Commands |
|--------|----------|
| Database | `wp db create`, `wp db import`, `wp db export`, `wp db check`, `wp db query` |
| Content | `wp post create`, `wp post update`, `wp post delete`, `wp post meta update` |
| Media | `wp media import <url>`, `wp media regenerate` |
| Options | `wp option get`, `wp option update`, `wp option delete` |
| Menus | `wp menu create`, `wp menu item add-post`, `wp menu item add-custom`, `wp menu location assign` |
| Plugins | `wp plugin install`, `wp plugin activate`, `wp plugin deactivate`, `wp plugin list` |
| Theme | `wp theme activate`, `wp theme list` |
| Config | `wp config set`, `wp config get`, `wp config list` |
| Rewrite | `wp rewrite structure`, `wp rewrite flush` |
| Cache | `wp cache flush`, `wp transient delete --all` |
| Cron | `wp cron event list`, `wp cron event run` |
| Search | `wp search-replace 'old' 'new'` |
| Scaffold | `wp scaffold child-theme`, `wp scaffold plugin` |
| Export/Import | `wp export`, `wp import` |
| User | `wp user create`, `wp user update` |
| Eval | `wp eval 'php_code();'` |

### Useful Flags

- `--porcelain` — return only the ID (useful for capturing post/attachment IDs)
- `--format=json` — machine-readable output for parsing
- `--format=table` — human-readable output for display
- `--allow-root` — required inside Docker containers running as root
- `--force` — skip confirmation prompts (e.g., `wp post delete 1 --force`)

---

## ACF Field Seeding Patterns

### Preferred: `update_field()` via `wp eval`

Use ACF's own API for field operations. This is storage-format-agnostic and handles field key registration, serialization, and caching correctly.

```bash
# Simple field on options page
$WP eval "update_field('hero_title', 'Building Digital Excellence', 'option');"

# Image field (import first, use attachment ID)
ID=$($WP media import 'https://images.unsplash.com/photo-xxx' --title='Hero Background' --porcelain)
$WP eval "update_field('hero_image', $ID, 'option');"

# Repeater field
$WP eval "
\$rows = array(
  array('title' => 'Web Design', 'description' => 'Custom websites...', 'icon' => 43),
  array('title' => 'SEO', 'description' => 'Search optimization...', 'icon' => 44),
);
update_field('services_cards', \$rows, 'option');
"

# Page post meta (field on a specific page)
$WP eval "update_field('about_hero_title', 'Our Story', <post_id>);"
```

### Alternative: Direct `wp_options` for Bulk Operations

Faster for bulk seeding but coupled to ACF internals. Use only when ACF API is unavailable or for bulk performance.

ACF stores options page fields in `wp_options` with an `options_` prefix (e.g., field `hero_title` is stored as `options_hero_title`).

```bash
# Simple field
$WP option update options_hero_title "Building Digital Excellence"
$WP option update options_hero_image 42

# Repeater fields (indexed subfields + count)
$WP option update options_services_cards_0_title "Web Design"
$WP option update options_services_cards_0_icon 43
$WP option update options_services_cards_1_title "SEO"
$WP option update options_services_cards_1_icon 44
$WP option update options_services_cards 2  # total row count
```

### After Seeding: Always Flush Cache

```bash
$WP cache flush
```

---

## Bilingual Naming Convention

This convention matches the i18n helper system defined in the `wp-bilingual` skill.

- **Primary language fields use no suffix:** `hero_title`, `hero_description`, `cta_text`
- **Secondary language fields append `_<lang>`:** `hero_title_es`, `hero_description_es`, `cta_text_es`

### Seeding Bilingual Content

```bash
# Primary language (no suffix)
$WP eval "update_field('hero_title', 'Building Digital Excellence', 'option');"

# Secondary language (append _<lang>)
$WP eval "update_field('hero_title_es', 'Construyendo Excelencia Digital', 'option');"
$WP eval "update_field('hero_subtitle_es', 'Creamos sitios web que funcionan', 'option');"

# Bilingual repeater subfields
$WP eval "
\$rows = get_field('services_cards', 'option');
\$rows[0]['title_es'] = 'Diseno Web';
\$rows[1]['title_es'] = 'SEO';
update_field('services_cards', \$rows, 'option');
"
```

### Rules

- Non-translatable fields (images, URLs, numbers, booleans) do NOT get language variants
- Read `.wp-create.json` field `languages.additional` to know which suffixes to generate
- If `languages.additional` is empty, skip all `_<lang>` field operations

---

## Shipped Scripts

`scripts/` holds the checks that are worth re-running rather than retyping. Run each with
`wp eval-file`.

### `check-dev-host.php` — the development host, in four tables

```bash
$WP eval-file <skill>/scripts/check-dev-host.php          # needle from home_url()
$WP eval-file <skill>/scripts/check-dev-host.php old.host # or an explicit host
```

Read-only. Exits 1 when any row carries the host, so it gates a deploy from a shell script.

Sweep `postmeta`, `posts` and `termmeta`, never `options` alone. `options` holds the least of
this and is the only table people check. The rows that actually reach the page are elsewhere:
a `custom` menu item stores its target verbatim in `postmeta._menu_item_url`, so after a push
it is a navigation link that leaves the live site, and an absolute URL pasted into
`post_content` is the same defect inside an article body. On one audited site `options` alone
reported 7 occurrences and the full sweep reported 25.

`home` and `siteurl` are excluded — they are what makes the local install work. A `guid` match
is counted separately and never rewritten: WordPress treats a `guid` as a historical
identifier, not a URL, and changing it breaks the key feed readers use.

### `find-orphan-acf-ids.php` — IDs that outlive the post

```bash
$WP eval-file <skill>/scripts/find-orphan-acf-ids.php <theme-path>
```

Read-only. Exits 1 when an orphan reaches a template; dead data alone exits 0.

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

### `audit-menu-links.php` — menu items that go nowhere

```bash
$WP eval-file <skill>/scripts/audit-menu-links.php
```

Read-only. Exits 1 on any finding.

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

---

## Match Records by Slug, Never by ID

A script that runs on one install and then on another cannot match by post ID. IDs are
assigned per install; "post 354" on a developer machine is a different record, or no record,
on staging and on production. The same holds for term IDs, menu item IDs and attachment IDs.

Match on something the content carries with it: a slug, a menu item's title, a page's path, or
the `_<prefix>_seed_key` marker described above. Resolve it to an ID at the top of the script
and fail loudly when it does not resolve, rather than writing to whatever ID happens to exist.

**`get_posts()` with `'name' => $slug` does not return drafts, even with
`'post_status' => 'any'`.** `any` means every status not flagged `exclude_from_search`, and
`WP_Query` also narrows the query when `name` is set. A lookup that works for published pages
silently finds nothing the moment the record is a draft — which is the state a content script
most often has to fix. Use `post_name__in` with the statuses written out:

```php
$found = get_posts( array(
	'post_type'      => 'page',
	'post_name__in'  => array( $slug ),
	'post_status'    => array( 'publish', 'draft', 'pending', 'private', 'future' ),
	'posts_per_page' => 1,
) );
```

Print what resolved to what before writing anything. A script that reports
`slug 'about' -> 42` can be checked by the person running it; one that silently writes to 42
cannot.

---

## Common Patterns

### Always set an author

`wp post create` and `wp media import` leave `post_author` at **0** — a user
that does not exist. The post saves and renders, so nothing looks wrong until
something asks for the author: `the_author()` prints nothing, an Article schema
emits an empty `author`, the admin list shows a blank column, and a plugin that
dereferences the author object can fatal. Resolve an author once and pass it to
every create:

```bash
AUTHOR=$($WP user list --role=administrator --field=ID --number=1)
$WP post create --post_author=$AUTHOR ...
$WP media import file.jpg --post_author=$AUTHOR ...
```

Sweep at the end of any seeding run — it must print 0. Two exclusions, or the
sweep fails on a site that is perfectly seeded: WordPress creates auto-drafts with
`post_author = 0` on its own, and menu items get the same treatment because
`wp_insert_post()` falls back to `get_current_user_id()`, which is 0 under WP-CLI —
a menu item has no author to display, so it is noise here rather than a defect.

```bash
$WP db query "SELECT COUNT(*) FROM $($WP db prefix)posts WHERE post_author = 0 AND post_status != 'auto-draft' AND post_type != 'nav_menu_item';"
```

### Create Pages and Set Front Page

```bash
AUTHOR=$($WP user list --role=administrator --field=ID --number=1)
HOME_ID=$($WP post create --post_type=page --post_title='Home' --post_status=publish --post_author=$AUTHOR --porcelain)
ABOUT_ID=$($WP post create --post_type=page --post_title='About' --post_status=publish --post_author=$AUTHOR --porcelain)

$WP option update show_on_front 'page'
$WP option update page_on_front $HOME_ID
```

### Create and Assign Menus

```bash
$WP menu create "Primary EN"
$WP menu create "Primary ES"

$WP menu item add-post primary-en $HOME_ID --title="Home"
$WP menu item add-post primary-en $ABOUT_ID --title="About"
$WP menu item add-post primary-es $HOME_ID --title="Inicio"
$WP menu item add-post primary-es $ABOUT_ID --title="Acerca"

$WP menu location assign "Primary EN" primary_en
$WP menu location assign "Primary ES" primary_es
```

### Import Media and Use Attachment ID

```bash
ID=$($WP media import 'https://example.com/photo.jpg' --title='Hero Image' --porcelain)
$WP eval "update_field('hero_image', $ID, 'option');"
```

### Verify Operations

```bash
# Verify a field was seeded
$WP eval "echo get_field('hero_title', 'option') ? 'OK' : 'EMPTY';"

# Verify a page exists with correct template
$WP eval "echo get_page_template_slug($PAGE_ID);"

# Verify plugin is active
$WP plugin list --status=active --format=table

# Verify menus are assigned
$WP menu location list --format=table
```

### Final Cleanup After Seeding

```bash
$WP rewrite flush
$WP cache flush
```
