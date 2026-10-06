---
name: wp-cli-patterns
description: WP-CLI-first rules for every agent — run WP-CLI instead of generating PHP, the $WP wrapper convention, ACF seeding patterns, matching records by slug, the shipped diagnostic scripts, and guarding a clone against outbound mail. Use when writing or running any WP-CLI command, seeding pages, fields, menus or media, or working in a project that has a .wp-create.json.
user-invocable: false
---

# WP-CLI Patterns — Best Practices for All Agents

This skill teaches the **WP-CLI-first principle**: use WP-CLI commands instead of generating PHP code whenever possible. WP-CLI saves tokens, reduces errors, and executes faster than writing throwaway PHP files.

## Reference files

- [references/seeding-recipes.md](references/seeding-recipes.md) — the WP-CLI command table and flags, ACF and bilingual seeding commands, and the
  page, menu, media, verification and cleanup recipes. Read when writing a seed run.
- [references/shipped-scripts.md](references/shipped-scripts.md) — what each shipped script measures, why it is shaped that way and how to read its
  output. Read before acting on a script's findings or writing a sweep that overlaps one.

---

## Core Rule: WP-CLI Over PHP Generation

**Always prefer a single WP-CLI command over generating PHP code.**

```
# BAD (costs tokens): Generate PHP file with update_option()
# GOOD (1 line):      $WP option update my_option 'value'

# BAD:  Generate PHP with wp_insert_post()
# GOOD: $WP post create --post_type=page --post_title='About' --post_status=publish

# BAD:  Generate PHP with wp_create_nav_menu()
# GOOD: $WP menu create "Primary" && $WP menu item add-post primary 5

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

The command table for the 16 domains agents use, and the flags worth knowing (`--porcelain`,
`--format=json`, `--allow-root`, `--force`), are in [references/seeding-recipes.md](references/seeding-recipes.md).

---

## ACF Field Seeding Patterns

Prefer ACF's own API, `update_field()` through `$WP eval`: it is storage-format-agnostic and
handles field key registration, serialization, and caching correctly. Write the `wp_options` rows
directly (`options_<field>`, a repeater as indexed subfields plus its row count) only when the ACF
API is unavailable or for bulk performance — that path is coupled to ACF internals. Always
`$WP cache flush` after seeding. Commands for simple, image, repeater and page fields: [references/seeding-recipes.md](references/seeding-recipes.md).

---

## Bilingual Field Names Follow the Recorded `i18n strategy`

Read the `i18n strategy` line in the project's `.claude/CLAUDE.md` before seeding a field in a
second language. An absent line means the project predates the choice and is `suffix`.

- **`polylang`** (the default for new scaffolds): one post per language, and every post uses the
  same unsuffixed field names. Seed the primary-language post only; `/wp-polylang` creates the
  other language's posts and fills their fields. The one exception is the ACF **options page**,
  which is global rather than per post and so keeps `_<lang>` duplicates (`footer_text_es`).
  Never create `hero_title_es` on a page here — Polylang serves nothing from it. Method:
  `wp-polylang`.
- **`suffix`**: one page carries every language. The primary language uses the bare name
  (`hero_title`); each secondary language appends `_<lang>` (`hero_title_es`). Read
  `languages.additional` in `.wp-create.json` for the suffixes to generate, and skip every
  `_<lang>` write when it is empty. Method: `wp-bilingual`.

Either way, non-translatable fields (images, URLs, numbers, booleans) get no language variant.
Seeding commands for both strategies: [references/seeding-recipes.md](references/seeding-recipes.md).

---

## Shipped Scripts

`scripts/` holds the checks that are worth re-running rather than retyping. Run each with
`wp eval-file`, except `find-redeclared-functions.php`, which reads files only and runs with
plain `php`.

Run them; do not read them first. Each entry below is how to run the script and what its exit
code means. What it measures and how to read its output are in [references/shipped-scripts.md](references/shipped-scripts.md).

`S` below is `${CLAUDE_PLUGIN_ROOT}/skills/wp-cli-patterns/scripts`.

### `check-dev-host.php` — the development host, in four tables

```bash
$WP eval-file "$S/check-dev-host.php"          # needle from home_url()
$WP eval-file "$S/check-dev-host.php" old.host # or an explicit host
```

Read-only. Exits 0 when no row carries the host, 1 when any row does, so it gates a deploy from
a shell script, and 2 when it could not determine a host to search for — treat 2 as not
measured, never as a pass.

### `find-orphan-acf-ids.php` — IDs that outlive the post

```bash
$WP eval-file "$S/find-orphan-acf-ids.php" <theme-path>
```

Read-only. Needs ACF or SCF active. Exits 1 when an orphan reaches a template; dead data alone
exits 0. Exits 2 when it cannot classify — the theme path is not a directory, or no ACF/SCF is
active to resolve field types — treat 2 as not measured, never as a pass. Without a theme path
every finding is `UNCLASSIFIED` and counts toward exit 1, so pass one to separate what reaches
the page from dead data.

### `audit-menu-links.php` — menu items that go nowhere

```bash
$WP eval-file "$S/audit-menu-links.php"
```

Read-only. Exits 1 on any finding, 0 otherwise.

### `find-redeclared-functions.php` — one global function, two sources (SEC-043)

```bash
php "$S/find-redeclared-functions.php" \
  loaded:plugin/<a>=wp-content/plugins/<a> inactive:plugin/<b>=wp-content/plugins/<b> \
  loaded:mu-plugin/<file>=wp-content/mu-plugins/<file> loaded:drop-in/<file>=wp-content/<file>
```

Read-only, no WordPress bootstrap, PHP 7.4+. Exits 0 when nothing collides, 1 on any
collision, and 2 when a source path does not exist (`missing source: <label>` on stderr) —
treat 2 as not measured, never as a pass. An unreadable file or directory is printed as
`skipped: <path>` and is partial coverage. Each line is
`CRITICAL` (two loaded sources), `WARNING` (one loaded, the other inactive: it cannot be
activated) or `INFO` (only inactive plugins).

### `find-missing-media-files.php` — attachments whose file is gone (WP-060/061/062)

```bash
$WP eval-file "$S/find-missing-media-files.php" [archive-date] [sample-size]
```

Read-only. Exits 1 when any `BEFORE-ARCHIVE` or `UNDATED` miss exists, 0 when every miss is
`AFTER-ARCHIVE` or there are none, and 2 when it cannot measure: an archive date or sample size
it does not accept, a failed query, or an uploads directory it cannot resolve or read.

### `resolve-link-targets.php` — internal links the database can answer

```bash
$WP eval-file "$S/resolve-link-targets.php" links.txt resolved.json > http.txt
```

Read-only. `links.txt` is one href per line, optionally a TAB and the page it was found on. The
links the database answered go to `resolved.json`; the rest are printed as
`href TAB page TAB group`, ready for `${CLAUDE_PLUGIN_ROOT}/bin/link-sweep.mjs --urls`. Exits 0 when it ran, and 2 on
a bad invocation, an unreadable input or an unwritable output. How an audit uses it is
"Link and page sweeps against a site" in `${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-standards/SKILL.md`, the one place
that rule is written down.

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

Recipes for pages and the front page, menus, media, verification and final cleanup: [references/seeding-recipes.md](references/seeding-recipes.md).

## Guard a clone against outbound mail and calls

A restored clone carries the production SMTP credentials and any newsletter or webhook
integration. Before submitting a form, subscribing, or running any audit that exercises one,
drop a temporary must-use plugin that refuses mail and non-local HTTP:

```bash
mkdir -p wp-content/mu-plugins
cat > wp-content/mu-plugins/zz-clone-guard.php <<'PHP'
<?php
// Temporary: remove when the test run ends.
add_filter( 'pre_wp_mail', '__return_false', 1 );
add_filter( 'pre_http_request', function ( $pre, $args, $url ) {
	$host = wp_parse_url( $url, PHP_URL_HOST );
	$home = wp_parse_url( home_url(), PHP_URL_HOST );
	return ( $host && $host !== $home && 'localhost' !== $host ) ? new WP_Error( 'clone_guard', 'Blocked on clone: ' . $host ) : $pre;
}, 1, 3 );
PHP
```

Check it loaded: `$WP eval 'echo has_filter("pre_wp_mail") ? "guarded" : "open";'`.

Cleanup is part of the recipe, not an afterthought: delete the test rows the run created
(form entries, subscribers, comments), then `rm wp-content/mu-plugins/zz-clone-guard.php`.
A browser pointed at the clone must also route-block third-party analytics and reCAPTCHA
hosts, or it reports real hits to the production property.
