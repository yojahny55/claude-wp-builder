# WP-CLI seeding recipes

Copyable commands for the rules in `wp-cli-patterns`. Every command is written with `$WP`, the
`wp_cli.wrapper` value from `.wp-create.json`.

## Contents

- WP-CLI command reference and useful flags
- ACF field seeding — `update_field()` via `wp eval`, direct `wp_options` rows, cache flush
- Seeding bilingual content
- Pages and front page, menus, media
- Verifying a seed run, and final cleanup

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
- `--force` on `wp post delete` — **permanently deletes, bypassing the trash**; without it the
  post goes to the trash and can be restored. It is not a confirmation skip (that is `--yes`,
  on the commands that prompt). Use it only on a record you have just confirmed is this run's own.

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

## Seeding Bilingual Content

Which recipe applies is the project's recorded `i18n strategy` (absent means `suffix`).

**`suffix`** — secondary-language values go into `_<lang>` duplicates, on pages and on the
options page alike:

```bash
# Primary language (no suffix)
$WP eval "update_field('hero_title', 'Building Digital Excellence', 'option');"

# Secondary language (append _<lang>)
$WP eval "update_field('hero_title_es', 'Construyendo Excelencia Digital', 'option');"
$WP eval "update_field('hero_subtitle_es', 'Creamos sitios web que funcionan', 'option');"

# Bilingual repeater subfields
$WP eval "
\$rows = get_field('services_cards', 'option');
\$rows[0]['title_es'] = 'Diseño Web';
\$rows[1]['title_es'] = 'SEO';
update_field('services_cards', \$rows, 'option');
"
```

**`polylang`** — seed the primary-language posts with unsuffixed fields only, and let
`/wp-polylang` create and fill the other language's posts. Only the options page, which is
global, keeps `_<lang>` duplicates, written exactly as in the `suffix` block above.

---

## Common Patterns

### Create Pages and Set Front Page

```bash
AUTHOR=$($WP user list --role=administrator --field=ID --number=1)
HOME_ID=$($WP post create --post_type=page --post_title='Home' --post_status=publish --post_author=$AUTHOR --porcelain)
ABOUT_ID=$($WP post create --post_type=page --post_title='About' --post_status=publish --post_author=$AUTHOR --porcelain)

$WP option update show_on_front 'page'
$WP option update page_on_front $HOME_ID
```

### Create and Assign Menus

Assign only to locations the theme registers; `wp menu location assign` refuses any other name.
List them rather than guessing (underscore or hyphen, suffixed or bare):

```bash
$WP menu location list --format=csv
```

**`suffix`** — one location per language (the tailwind starter registers `primary-en`,
`primary-es`, `mobile-*` and `footer-*`), one menu per language, each assigned to its own:

```bash
$WP menu create "Primary EN"
$WP menu create "Primary ES"

$WP menu item add-post primary-en $HOME_ID --title="Home"
$WP menu item add-post primary-en $ABOUT_ID --title="About"
$WP menu item add-post primary-es $HOME_ID --title="Inicio"
$WP menu item add-post primary-es $ABOUT_ID --title="Acerca de"

$WP menu location assign "Primary EN" primary-en
$WP menu location assign "Primary ES" primary-es
```

**`polylang`** — one bare location per name (`primary`, `footer`), with no language suffix.
Assign the primary-language menu to it with `wp menu location assign` — that writes the core
`nav_menu_locations` theme_mod, which Polylang's per-language slots only override and never
create — and leave the other languages' menus to `/wp-polylang`'s import. Never create a
`primary-es` location here. Why both halves are needed: "Menus" in `wp-polylang`.

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
