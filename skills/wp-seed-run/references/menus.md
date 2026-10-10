# /wp-seed — Phase 6

`commands/wp-seed.md` sends the run here at Phase 6 (Create Menus). Follow it in order; nothing in it is optional background.

## Contents

- Create menu structures
- Add menu items
- Assign menus to theme locations
- Verify menu assignment

The location names come from the theme's `register_nav_menus()`, which
`/wp-init` Step 6 wrote per strategy, and the templates ask for them through
`<prefix>nav_location()` — so assign to exactly these, never to a name of your
own (`wp menu location assign` refuses one the theme does not register):

| `i18n strategy` | Locations |
|---|---|
| `polylang` | `primary`, `footer` — bare, registered once |
| `suffix` | `primary-<lang>`, `footer-<lang>` — hyphenated, one pair per language |

**Under `i18n strategy: polylang`**, create ONE primary and ONE footer menu per
language, and assign every language's menu to the SAME location — Polylang keeps
a per-language slot for every registered location, and the theme registers
`primary` / `footer` without language suffixes. Assign each with:

```bash
bash -c "$WP eval \"\$o = get_option('polylang'); \$o['nav_menus'][get_stylesheet()]['primary']['<lang>'] = <menu_id>; update_option('polylang', \$o);\""
bash -c "$WP eval \"\$o = get_option('polylang'); \$o['nav_menus'][get_stylesheet()]['footer']['<lang>'] = <footer_menu_id>; update_option('polylang', \$o);\""
```

**That option alone is not enough.** Polylang's frontend filter only
overrides a location it finds already present in the core
`nav_menu_locations` theme_mod — it never creates one. Writing only the
`polylang` option above, with no location ever registered the normal way,
leaves that theme_mod empty: `wp_nav_menu()` then falls through to its
hard-coded fallback markup for EVERY language, primary included, and the
fallback can look correct by coincidence — nothing on the primary-language
site looks broken, so the defect is invisible until a second language is
checked. Register the location the normal way for the primary language's
menu FIRST, so Polylang has something to override:

```bash
bash -c "$WP menu location assign 'Primary <PRIMARY_LANG>' primary"
bash -c "$WP menu location assign 'Footer <PRIMARY_LANG>' footer"
```

Then write the per-language option above for every language, primary
included.

Add each language's own pages to its own menu; do not add a page to the menu
of another language.

**Verify the menus from the front end, and only from the front end.** This is the
one assertion in this phase that can fail, and the obvious way to make it cannot:

```bash
for URL in "$($WP option get home)" "$($WP option get home)/es/"; do
  printf '%s  links: ' "$URL"
  curl -fsSk "$URL" | grep -c 'class="[^"]*menu-item'
done
```

Zero on any language is a failure. Do not continue and do not report the seed as
done — a header rendering its logo, its language switcher and its CTA with no links
between them reads as a deliberate minimal design, and that is how it shipped on all
16 pages of a delivery. `wp_nav_menu()` with `'fallback_cb' => false` renders nothing
for a location that resolves to menu `0`, which is correct behaviour and leaves no
trace: HTTP 200, no notice, no log line.

**`$WP eval 'print_r(get_nav_menu_locations());'` will tell you it is fine.** It
returns the core `nav_menu_locations` theme_mod, and Polylang's filter that *replaces*
that map with its own per-language one is a **frontend** filter — it does not run
under WP-CLI. So the CLI prints `primary => 15, footer => 17`, all
correct, on a site serving no navigation at all. Every CLI-based check of this will
pass on a broken site; only an HTTP request sees what a visitor sees.

Everything below this line describes the `suffix` strategy.

Create navigation menus for each configured language. Menu location names are **hyphenated** — `primary-<lang>`, `footer-<lang>` — matching the theme's `register_nav_menus()` and the name the suffix `<prefix>nav_location()` asks for. An underscore spelling of these is registered by neither starter: `wp menu location assign` refuses it, and the header renders no menu.

### Create menu structures

**Resolve by name** (Phase 1.5). `wp menu create` never refuses a duplicate name — WordPress
allows two menus called `Primary EN`, and `wp menu item add-post` then takes a slug that
resolves to whichever one it finds, so a second run can fill a menu the theme is not
displaying while the visible one keeps last run's items:

```bash
# Does a menu with this name already exist?
bash -c "$WP menu list --fields=term_id,name,slug --format=csv"
```

Create only the missing ones:

```bash
bash -c "$WP menu create 'Primary EN'"
bash -c "$WP menu create 'Primary ES'"

# Footer menus: the theme registers a footer location per language, and
# /wp-finalize fails any registered location left without a menu
bash -c "$WP menu create 'Footer EN'"
bash -c "$WP menu create 'Footer ES'"
```

**A menu that already exists is emptied of its seeded items before this run adds its own**,
rather than added to. Menu items are the one record where update-in-place does not work: a
demo whose navigation dropped a page leaves that item behind forever, and matching an
existing item to a demo link is guesswork the moment a title is edited. Delete the items
this project seeded (`wp menu item delete`), keep any the client added, then add this run's.
That is the same ownership rule, applied to a record whose identity is its position.

### Add menu items

Add each page to its language menu, using the page IDs from Phase 2. The first argument
is the **menu** (`primary-en` is the slug WordPress derives from `Primary EN`), not the
location; add the demo footer's links to `footer-en` / `footer-es` the same way:

```bash
# English primary menu
bash -c "$WP menu item add-post primary-en <home_id> --title='Home'"
bash -c "$WP menu item add-post primary-en <about_id> --title='About'"
bash -c "$WP menu item add-post primary-en <services_id> --title='Services'"
bash -c "$WP menu item add-post primary-en <contact_id> --title='Contact'"

# Spanish primary menu
bash -c "$WP menu item add-post primary-es <home_id> --title='Inicio'"
bash -c "$WP menu item add-post primary-es <about_id> --title='Acerca'"
bash -c "$WP menu item add-post primary-es <services_id> --title='Servicios'"
bash -c "$WP menu item add-post primary-es <contact_id> --title='Contacto'"
```

### Assign menus to theme locations

Use the hyphenated location names `register_nav_menus()` registers in the theme:

```bash
# Assign to theme locations (hyphenated, one pair per language)
bash -c "$WP menu location assign 'Primary EN' primary-en"
bash -c "$WP menu location assign 'Primary ES' primary-es"
bash -c "$WP menu location assign 'Footer EN' footer-en"
bash -c "$WP menu location assign 'Footer ES' footer-es"
```

### Verify menu assignment

```bash
bash -c "$WP menu location list --format=table"
```
