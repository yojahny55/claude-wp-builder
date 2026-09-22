---
description: Custom post type builder — registers a CPT and generates its fields, archive, single, optional teaser query-section, and seed helper
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "<name> [--no-teaser] [--from-demo <section-name>]"
---

# WP CPT — Custom Post Type Builder

Register a custom post type and generate everything it needs: registration, ACF fields bound to the type, archive + single templates, an optional home/teaser query-section, and a seed helper.

## Step 1: Parse Arguments
- **First word** = CPT name, singular lowercase (e.g., `team`, `service`, `project`). Required.
- `--no-teaser` = skip the teaser query-section.
- `--from-demo <section-name>` = read field/seed hints from that section in `demo/index.html`.

If no name: print usage error and exit.

## Step 2: Read Project Context
Read `.claude/CLAUDE.md` for function prefix, theme slug, languages, theme directory. If missing, tell the user to run `/wp-init` first and exit.

### CSS agent routing

Read `Template:` from `.claude/CLAUDE.md`. When `Template:` is `tailwind`, dispatch
`wp-tailwind`; when it is `basic`, dispatch `wp-css`.

- `basic` → dispatch `wp-css` exactly as described below.
- `tailwind` → dispatch `wp-tailwind` in **author** mode instead, passing the CPT name
  (which selects `components/<name>.css`) and the block name. The agent reads
  `skills/wp-tailwind-system/SKILL.md` for the decision ladder. It writes utility
  classes into the markup and only adds `@apply` rules where the ladder demands
  them. It must never write `assets/css/styles.css`.

Dispatch exactly one of the two, never both.

Every `tailwind` dispatch opens its quoted prompt with this line, verbatim:

> Mode: **author**

The quoted prompt it opens is the one under "The `tailwind` prompt body" below — **not**
the quoted prompt at the dispatch site, which is the `basic` branch's and names
`assets/css/styles.css`, the one file the `tailwind` path must never write.

`agents/wp-tailwind.md` gates Section Authoring Mode on that line and on nothing else, so
the line is not decoration: omit it and the dispatched agent falls into Demo Conversion
Mode, reads the prompt as a demo-file conversion and writes a `.tmp` nobody asked for. A
bare `author` anywhere else in the prompt — in prose, or inside an input path like
`demo/author.html` — selects nothing, precisely so that an ordinary demo page named after
the word cannot flip the mode by accident.

This routing governs every "Dispatch **wp-css** agent" step below (the archive/single/card
CSS in Step 4, and the teaser section in Step 5) — each one marks its `tailwind`
counterpart with `(routed — see "CSS agent routing" above)` rather than repeating the
block.

**Editing rule for this file.** `tests/checks/wp-commands-tailwind.sh` walks every
dispatch site by matching `Dispatch` and `**wp-css**` on one physical line, and accounts
for every other bolded `**wp-css**` in the file. So: keep `Dispatch` and `**wp-css**`
together on a single line at each dispatch site (never hard-wrap between them), and write
`wp-css` unbolded when you mean it in prose. The one place bolded prose is allowed is
inside this `### CSS agent routing` block — everything from this heading down to the next
heading at `###` or above is exempt, sub-headings and fenced examples included.

Routing matters here because `--from-demo` reads `demo/index.html`, and on the `tailwind`
path `/wp-yolo` Step 4 item 2 runs `/wp-cpt` *after* Step 2.6 has converted that file in
place. The markup this command reads is already Tailwind-native; building its CSS through
`wp-css` would leak plain CSS straight into `front-page.php` via the teaser.

#### The `tailwind` prompt body

Both dispatch sites below are the `basic` branch, and **on `tailwind` neither runs at
all** — do not follow the instructions in the site's own quoted prompt there. Dispatch
`wp-tailwind` in author mode with the prompt below instead, substituting the CPT name as
the slug and the block name.

**File ownership.** `wp-template` owns every `.php` file this command generates —
`archive-<name>.php`, `single-<name>.php` (the one Step 4 names BEM classes
`.<name>-single__*` for on `basic`), `template-parts/<name>/card.php` and the teaser
`template-parts/section-<name>.php` — on both paths. It is the only agent carrying the
ACF, escaping and i18n contract (`prefix_get_field()`, the `?:` fallbacks, `esc_html()` /
`esc_url()` / `esc_attr()`, the `@package` header, the ABSPATH check), none of which
`agents/wp-tailwind.md` describes. On `tailwind`, `wp-template` keeps the Tailwind utility
classes already on the markup it was handed instead of inventing BEM names, and
`wp-tailwind` runs **after** it returns — never beside it — editing only class names in
the files `wp-template` wrote. In Step 5 that means the three agents are no longer
simultaneous on `tailwind`: `wp-template` and `wp-acf` go together, `wp-tailwind` follows.
The invariant: no template ships without its ACF wiring and escaping, and none ships on
BEM class names in a Tailwind theme.

> Mode: **author**
>
> Promote the `<name>` post type's repeated utility groups for this Tailwind theme.
>
> Read `skills/wp-tailwind-system/SKILL.md` before writing anything — it owns the
> decision ladder and the prohibition list.
>
> Context:
> - Page slug: `--page <name>` (decides `components/<name>.css`)
> - Block name: `--block <block>` (scopes every `@apply` class you create)
> - Theme path: `<theme path>`
> - Function prefix: `<prefix>`
> - Section HTML: the template files the wp-template agent has just written for this
>   post type, already carrying Tailwind utility classes — quoted below.
>
> Requirements:
> 1. Those template files belong to wp-template. Edit them in place; do not create
>    them and do not rewrite them. The only thing you change is class names. Leave
>    every `prefix_get_field()` call, every `esc_html()` / `esc_url()` / `esc_attr()`
>    wrapper, every fallback and every PHP control structure exactly as you found it.
> 2. Tailwind utility classes in the markup are the default. Most templates need no
>    CSS file entry at all, and come back unchanged.
> 3. A utility group repeated 3+ times, or on 2+ pages, becomes a semantic class via
>    `@apply` — `utilities/site.css` if it spans pages, `components/<name>.css` if it
>    is local to this one. The card markup is shared by the archive and the teaser on
>    `front-page.php`, so it is the usual cross-page candidate here. Grep the theme's
>    other `components/*.css` and `*.php` before choosing.
> 4. Name a class you write into `components/<name>.css` `<block>__<element>`. Name
>    one you write into `utilities/site.css` `site__<element>` instead — it qualified
>    for that file precisely because it spans more than one block.
> 5. If a target CSS file does not exist, create it with its first rule already in it
>    and add its `@import` to `main.css` in the same step, naming its cascade layer
>    (`layer(components)` for `components/<name>.css`, `layer(utilities)` for
>    `utilities/site.css`) — a bare `@import` beats every Tailwind utility regardless
>    of specificity. Never leave an empty file.
> 6. Colors and fonts come from the `@theme` block as utilities (`bg-primary`,
>    `font-primary`). No `:root`, no hardcoded hex a token already covers.
> 7. Responsive via Tailwind prefixes (`md:`, `lg:`). No hand-written `@media`.
> 8. Never write `assets/css/styles.css`. Never emit a `<style>` block.
>
> Template markup:
> ```php
> <paste the generated template files here>
> ```

## Step 3: Register the CPT and generate fields (parallel)

Dispatch **wp-template** agent:

> Generate `inc/post-types/<name>.php`:
> - `register_post_type( '<name>', [...] )` hooked on `init` via `add_action`
> - Labels for singular/plural (primary language from CLAUDE.md)
> - `'public' => true`, `'has_archive' => true`, `'menu_icon'` (choose a dashicon fitting the noun),
>   `'supports' => ['title','editor','thumbnail']`, `'rewrite' => ['slug' => '<name>']`
> - Escaping on labels; text domain = theme slug
> Then ensure `functions.php` `require`s every file in `inc/post-types/` (add a glob-require loop if not present).

Dispatch **wp-acf** agent:

> Generate `fields/<name>.php`:
> - Field group bound with location rule `post_type == <name>`
> - Fields inferred from the demo card (or `--from-demo` section): image (photo/thumbnail),
>   text (name/title — usually the post title, skip if so), text (role/subtitle), textarea/wysiwyg (bio/description),
>   repeater (socials: platform + url) when present
> - Bilingual variants per `wp-bilingual` when languages has a secondary
> - Group key: `group_<name>`

## Step 4: Archive and single templates

Dispatch **wp-template** agent:

> Generate `archive-<name>.php`:
> - `get_header()`, archive intro/title, grid loop over the main query rendering each item as a card
>   (reuse `template-parts/<name>/card.php`), `the_posts_pagination()`, `get_footer()`
> - When the demo draws a filter bar (text search, a select per taxonomy or relation), build it
>   on the starter's `assets/js/src/directory-filter.js` contract, the same for every directory:
>   a `[data-directory]` root, `[data-filter-text]`, one `[data-filter="<key>"]` per select with
>   options from the real terms/records, the results line `[data-filter-count]` with
>   `data-count-template="<?php echo esc_attr( prefix_t( 'directory_count' ) ); ?>"` (and
>   `data-count-template-one`), the `[data-filter-clear]` button, `[data-filter-empty]`, and
>   `data-filter-item` + `data-<key>` slugs on each card wrapper. Every label goes through
>   `prefix_t()`; the starter's string table already carries `directory_count`,
>   `directory_count_one`, `directory_clear`, `directory_empty`, `directory_search` (the text field's label) and `directory_all` (the empty select option). A filter mirrored in the URL uses `data-filter-param`, and that parameter
>   name must not be a public query var: a CPT or taxonomy slug makes WordPress query that
>   object instead of rendering this archive
> Generate `single-<name>.php`:
> - `get_header()`, item detail rendered from the CPT ACF fields via `prefix_get_field()`,
>   `get_footer()`, BEM classes `.<name>-single__*`
> Generate `template-parts/<name>/card.php`:
> - Single card markup shared by archive + teaser: thumbnail, title (`get_the_title()`),
>   role, excerpt/bio; permalink via `get_permalink()`
> - Class naming — include the line matching the project's `Template:` and drop the
>   other. These three files are yours on both paths; only the class system changes:
>   - `basic` → the BEM names above (`.<name>-single__*` and siblings)
>   - `tailwind` → keep the Tailwind utility classes already on the demo markup you
>     were handed, element for element. Never replace them with BEM names and never
>     invent new class names: `wp-tailwind` runs after you and renames only the groups
>     its promotion ladder promotes. See "File ownership" in "CSS agent routing" above.

**This step is the `basic` branch.** On `tailwind` it does not run at all — dispatch
`wp-tailwind` in author mode with "The `tailwind` prompt body" above instead, and do not
follow the quoted instructions below.

Dispatch **wp-css** agent (routed — see "CSS agent routing" above; on `tailwind`, dispatch `wp-tailwind` in author mode instead):

> Add `.<name>-archive`, `.<name>-card`, `.<name>-single` CSS within delimiters using design tokens.

## Step 5: Teaser query-section (unless --no-teaser)

**This step is the `basic` branch.** On `tailwind` it does not run at all — dispatch
`wp-tailwind` in author mode with "The `tailwind` prompt body" above instead, and do not
follow the quoted instructions below.

Dispatch **wp-template** + **wp-acf** + **wp-css** (mirror the /wp-section flow; the CSS agent is routed — see "CSS agent routing" above; on `tailwind`, dispatch `wp-tailwind` in author mode instead):

> `template-parts/section-<name>.php`:
> - `WP_Query( ['post_type' => '<name>', 'posts_per_page' => N, 'orderby' => 'menu_order'] )`
> - Section chrome from ACF: `prefix_get_field('<name>_heading')`, intro, button label
> - Render N cards via `template-parts/<name>/card.php`
> - "Show more" button → `get_post_type_archive_link('<name>')`
> `fields/section-<name>.php`: chrome-only ACF group (heading, intro, button_label) — NOT the items
> Inject `get_template_part('template-parts/section', '<name>')` into `front-page.php` at the sections placeholder.

## Step 6: Seed helper

**Always emit `inc/seed/<name>.php`** — a single runnable seeder that creates the N `<name>`
posts from the demo cards / detail pages. It must be executable standalone via the project's
WP-CLI wrapper (`$WP eval-file inc/seed/<name>.php`) so a later `/wp-yolo` Phase 3 (or a
manual run) can create the posts deterministically. For each post: create it
(`wp_insert_post` with `post_type => '<name>'`), set its ACF fields, and sideload the card
image (`media_sideload_image`) into the media library and set it as the thumbnail.
Make it idempotent where practical (skip if a post with the same title already exists).
It opens with the `defined( 'ABSPATH' ) || exit;` guard like every theme PHP file. `wp eval-file`
defines `ABSPATH`, so the guard costs the seeder nothing, and `/wp-finalize` fails a seed without it.
Primary language only; flag secondary.

## Step 6.5: Rebuild Tailwind CSS

On `Template: tailwind` the site enqueues only the compiled `assets/css/dist/main.css`, so
the classes the agents just wrote are invisible until it is recompiled:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/tailwind-rebuild.sh" <theme-dir>
```

Silent no-op on a non-Tailwind theme; skips itself when the user has `npm run preview`
running (the watcher already owns `dist/`). Do this before the summary — a summary that
lists files no browser can see yet is not a finished section.

## Step 7: Print Summary
List every file created and the registered post type, archive URL, and seed count.
