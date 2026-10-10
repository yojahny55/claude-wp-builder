---
description: Seed WordPress content from demo HTML — parses sections, creates pages, imports media, populates ACF fields, builds menus, supports bilingual content
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[demo-file.html] [--exclude-slugs <slug,slug,...>] [--force-fields]"
---

# WP Seed — Content Seeding from Demo HTML

Parse a demo HTML file (or multi-page demo directory), extract content via BEM class conventions, and seed it into WordPress using WP-CLI. Creates pages, imports media, populates ACF fields for all configured languages, and builds navigation menus.

A one-off `wp eval` for a single field is fine inline, as the phases below do
throughout. Anything meant to be re-run — a bulk import, a script another
command will need to trigger again later — is a different case: see "Non-Trivial
Seed Logic Lives in `inc/seed/`, Never in a Scratchpad" in
`${CLAUDE_PLUGIN_ROOT}/skills/wp-cli-patterns/SKILL.md` before writing it as a throwaway file.

## Step 0: Read Project Manifest

**First: validate the project configuration.**

`${PROJECT_PATH}` is not an environment variable the way `${CLAUDE_PLUGIN_ROOT}` beside it is: it is the WordPress project root, the directory holding `.wp-create.json`, and you substitute the real path yourself — the one the user named, or the working directory when they named none — because an empty argument makes the validator print its usage line and exit `1`, which the table below then reads as "stop and report".

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs validate '${PROJECT_PATH}'"
```

| Exit | Meaning | Do |
|---|---|---|
| `0` | valid | continue |
| `1` | invalid, or the generated context block disagrees with the manifest | stop and report the message verbatim |
| `2` | an older manifest can migrate | run `wp-config.mjs migrate '${PROJECT_PATH}'`, then continue |
| `3` | no manifest | this project was not created by `/wp-create`; stop and say so |

On exit 2, run the migration before continuing.

**Amending the exit `3` row above:** Exit `3` here falls through to the bare-`wp` fallback below rather than stopping outright
— this command also seeds a WordPress root that was never run through `/wp-create`.

Read `.wp-create.json` from the project root to obtain the WP-CLI wrapper and language configuration.

```bash
bash -c "cat .wp-create.json"
```

Extract and store:
- **`$WP`** — the value of `wp_cli.wrapper` (e.g., `docker exec my-project-wp wp --allow-root`, `wp --path=/var/www/html/my-project`, `ddev wp`, `lando wp`, `npx wp-env run cli wp`)
- **Primary language** — `languages.primary` (e.g., `en`)
- **Additional languages** — `languages.additional` array (e.g., `["es"]`)
- **Project slug** — `project.slug`
- **Project path** — `project.path`

If `.wp-create.json` does not exist, fall back the same way `/wp-debug` does:
- Check if bare `wp` is available: `bash -c "which wp"`
- If available, set `$WP` to `wp` (assume the current directory is the WordPress root) and
  take the languages from the `Languages:` line of `.claude/CLAUDE.md` instead (first =
  primary, the rest = additional).
- If `wp` is not available either, abort with:
  > "No `.wp-create.json` found and no `wp` on PATH. Run `/wp-create` to set up the WordPress environment, or install WP-CLI."

Verify WP-CLI connectivity before proceeding:

```bash
bash -c "$WP option get siteurl"
```

If this fails, abort with a message suggesting the user check that the WordPress environment is running.

**Resolve the author once** — "Always set an author" in
`${CLAUDE_PLUGIN_ROOT}/skills/wp-cli-patterns/SKILL.md`. `wp post create` and `wp media import`
leave `post_author` at 0, a user that does not exist: the page renders, and `the_author()`,
the Article schema's `author` and the admin column come out empty, so every seeded page fails
`/wp-finalize` Check 7's author sweep.

```bash
bash -c "$WP user list --role=administrator --field=ID --number=1"
```

Store the ID as **`$AUTHOR`**, substituted the same way as `$WP`, and pass
`--post_author=$AUTHOR` to **every** `wp post create` and `wp media import` below. No
administrator is a stop, not a default: report it rather than creating posts owned by nobody.

---

## Phase 1: Parse Demo HTML

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-seed-run/references/parse-demo.md` now and follow
it — it is this phase, not background. It covers the arguments, locating the demo file, single- versus multi-page detection, and the per-file parse of sections, text, images and links by BEM class.


---

## Phase 1.5: Resolve before you create

**Every writing phase below resolves each record before it creates one.** Seeding runs more
than once — a demo changes, a section is rebuilt, `/wp-yolo` re-runs a step — and a phase
that creates unconditionally produces a second copy of everything it made last time. Pages,
attachments and menus are the records that duplicate most visibly, and a client looking at
two "About" pages cannot tell which one the theme reads.

Seeded records carry `_<prefix>_seeded_content` (the marker named in Phase 4.5). It is what
separates this run's own previous output from work the client did by hand, and it is the
only thing that can: a page created by seeding and a page created by a client are otherwise
identical rows. So every create goes through the same three-way resolution:

| What a lookup finds | Do |
|---|---|
| a record **carrying our marker** | reuse it — update it in place, keep its ID |
| a record **without the marker** | the client owns it. **Leave it exactly as it is**, record a conflict, and use its ID where a reference is needed |
| **nothing** | create it, and write the marker in the same step |

The second row is the one that must not be softened. An unmarked record is either the
client's work or something that predates seeding, and both are cases where overwriting
destroys something nobody can recover from the demo. Reporting the conflict is the whole
response — never "fix" it by overwriting, and never create a second record beside it, which
is the duplicate this phase exists to prevent wearing a different hat.

**Write the marker in the same command that creates the record**, not in a later pass. A
create that succeeds and a marker that does not leaves a record this project can never
recognise again: the next run finds it unmarked, reads it as client-owned, and seeding can
never touch it — or, worse, creates a duplicate beside it forever.

### Preview before writing

Resolve everything first, print what will happen, then write:

```
=== Seed plan ===
  create    4 pages, 12 attachments, 2 menus
  update    0 pages, 0 attachments, 0 menus
  skip      0 (unchanged)
  conflict  1 page — "About" exists without the seed marker; left untouched
  fields    update 3, skip 18, conflict 2
            conflict: hero_title (page "Home"), contact_phone (options)
```

Records and fields are counted separately because they are owned separately: the seeder can
own a page and not own a heading inside it (Phase 4). A plan that reported only records would
show `update 1 page` and say nothing about the two client edits inside it that are about to
be left alone — or, before the field compare existed, silently overwritten.

An unchanged re-run prints `create 0 / update 0` and every record under `skip`. That line is
how "re-running is safe" stops being a claim and becomes something the operator can see. A
run whose plan is all `create` on a project that has been seeded before is the signal that
resolution is not working — investigate before letting it write.

Conflicts go in this plan **and** in the Seed Report at the end, with the record named.

---

## Phase 2: Create Pages

Create a WordPress page for each page found in the navigation (or each HTML file in multi-page demos). **Skip any slug listed in `--exclude-slugs`** — do not create a WP Page for it (its URL is provided by a CPT archive via `has_archive`, and a WP Page would collide with `archive-<slug>.php`).

**Resolve by slug** (Phase 1.5). A page's title is edited freely by clients and its ID is not
knowable in advance; the slug is what the demo, the menu and the template all agree on:

```bash
# Existing page with this slug, and whether seeding owns it
bash -c "$WP post list --post_type=page --name='about' --format=ids"
bash -c "$WP post meta get <page_id> _<prefix>_seeded_content 2>/dev/null"
```

Create only what resolution says to create, marking it in the same step:

```bash
bash -c "ABOUT_ID=\$($WP post create --post_type=page --post_title='About' --post_name='about' --post_status=publish --post_author=$AUTHOR --porcelain) && $WP post meta add \$ABOUT_ID _<prefix>_seeded_content 1 && echo \$ABOUT_ID"
```

A page found **with** the marker keeps its ID and is updated in place — `wp post update`,
with `--post_author=$AUTHOR` when its author is 0, which is how a page seeded before the author
rule existed gets one —
so every menu item, `page_on_front` option and `page_link` field already pointing at it stays
pointing at it. Re-creating a page that already exists breaks those references silently:
the old page keeps the referrers, the new one gets the content.

```bash
# Create each page and capture its ID
bash -c "HOME_ID=\$($WP post create --post_type=page --post_title='Home' --post_status=publish --post_author=$AUTHOR --porcelain) && echo \$HOME_ID"
bash -c "ABOUT_ID=\$($WP post create --post_type=page --post_title='About' --post_status=publish --post_author=$AUTHOR --porcelain) && echo \$ABOUT_ID"
bash -c "SERVICES_ID=\$($WP post create --post_type=page --post_title='Services' --post_status=publish --post_author=$AUTHOR --porcelain) && echo \$SERVICES_ID"
bash -c "CONTACT_ID=\$($WP post create --post_type=page --post_title='Contact' --post_status=publish --post_author=$AUTHOR --porcelain) && echo \$CONTACT_ID"
```

Assign page templates if corresponding template files exist in the theme:

```bash
bash -c "$WP post update <page_id> --page_template='page-about.php'"
```

Set the front page to the Home page:

```bash
bash -c "$WP option update show_on_front 'page'"
bash -c "$WP option update page_on_front <home_id>"
```

If a Blog/News page exists, set it as the posts page:

```bash
bash -c "$WP option update page_for_posts <blog_id>"
```

Store all page IDs for use in later phases (menu creation, page-specific field seeding).

---

## Phase 3: Import Media

Import all collected image URLs into the WordPress media library.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-seed-run/references/import-media.md` now and follow
it — it is this phase, not background. It covers resolving attachments by source identity, the import loop, and seeding assets by role.


---

## Phase 4: Seed ACF Fields (Primary Language)

Populate all extracted content into ACF fields using WP-CLI. Primary language fields use **no suffix** (e.g., `hero_title`, not `hero_title_en`).

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-seed-run/references/acf-fields.md` now and follow
it — it is this phase, not background. It covers field ownership, the three-way compare, the `update_field()` method, the `wp_options` alternative, and verification.


---

## Phase 4.5: Values the demo does not supply

A demo carries one card per component, so seeding a real record set means filling fields no
source answers: the fifth lawyer's biography, an office's phone, a price. Inventing them is
allowed — a demo site with empty cards cannot be reviewed — but invented values are a
liability the moment they look real, and two of them have caused real trouble:

- A phone number generated a digit short of every other one on the site.
- A social-profile URL generated from a different person's handle, so a fictional record
  linked to a real stranger's account.

So, when a value has no source:

1. **Never generate anything that can resolve to a real person or account.** Social URLs,
   external links and anything handle-shaped stay EMPTY. The template already guards an empty
   field; a wrong link does not fail, it misinforms.
2. **Email and phone follow one shape for the whole site** — the same country code, the same
   digit count, the same local-part pattern — so a wrong one is visible at a glance instead of
   hiding among the plausible ones.
3. **Mark every invented record.** Seeded records already carry `_prefix_seeded_content`; that
   marker is what lets a later pass tell your content from the client's, so it goes on
   everything you create, including fields you fill in on a record that already existed.
4. **List what you invented at the end of the phase**, grouped by field, with the count:

   ```
   Invented, needs client data:
     person.phone       9 records
     person.bio         9 records
     office.hours      16 records
   Left empty on purpose:
     *.linkedin, *.social_*  (no value can be generated safely)
   ```

   That list belongs in the run summary and in the project's TODO, not only in this phase's
   output: the client has to replace these, and nobody can replace what nobody wrote down.

## Phase 5: Seed Bilingual Content

**Read `i18n strategy` from the project's `.claude/CLAUDE.md` first.** The two
strategies produce completely different content, and guessing wrong means
re-seeding the site.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-seed-run/references/bilingual.md` now and follow
it — it is this phase, not background. It covers the Polylang and field-suffix variants of the secondary-language content.


---

## Phase 6: Create Menus

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-seed-run/references/menus.md` now and follow
it — it is this phase, not background. It covers the location table per `i18n strategy`, menu structures, menu items, location assignment and verification.


---

## Phase 6.5: Placeholder pages for `page_link` options fields

Grep `fields/settings.php` for `'type' => 'page_link'`. Each one is a settings
field the header, footer or a menu is going to read and print as a URL — a
legal-links column is the common case (privacy policy, terms, FAQ), but any
`page_link` field on the options page qualifies. A demo never supplies these:
there is no "Privacy Policy" section in a marketing page to seed content from,
so without this phase the field ships empty, or — worse — pointed at whatever
draft WordPress happened to create on install, which resolves to a 404 for a
logged-out visitor with nothing in the UI to say so.

For each such field currently empty, or resolving to a post that is not
`publish`:

1. Create a page in **publish** status (`wp post create … --post_author=$AUTHOR`, like every
   create in this command) whose body visibly states, in its own
   language, that the text is a generic placeholder pending review — never
   silently ship boilerplate as if it were the client's real copy.
2. Mark it with `_<prefix>_seeded_content` (the marker every seeded record carries)
   plus `_<prefix>_seed_placeholder`, so a later run can tell it
   apart from a page the client has since written for real.
3. Point the field at the new page: `update_field('<field>', get_permalink(<id>), 'option')`.
4. Under `i18n strategy: polylang`, create and publish one page per
   configured language, join them with `pll_save_post_translations()`, and
   set each language's own field (see "One deliberate crossover" in
   `skills/wp-contributing/SKILL.md` — options-page fields keep their
   `_<lang>` suffix under Polylang). Under `suffix`, write the `_<lang>`
   field directly.

**Re-running is safe.** A field whose target page still carries the marker
meta is free to be rewritten; the marker meta is gone — because the client
edited the page — the page is left exactly as it is, even if the field
already pointed somewhere else. This is the same idempotency rule as ACF
field seeding elsewhere in this command: never overwrite a client's own
work, only ever a previous run's own placeholder.

Templates that print one of these fields must not merely check for a
non-empty value: a `page_link` field keeps pointing at its page after that
page is unpublished or trashed, and WordPress then serves that URL as a 404
with nothing to say so. Confirm `agents/wp-template.md`'s `page_link` guard
(the options-page fields section under "i18n Helper Functions") is what the
generated header/footer actually calls before printing one of these links.

---

## Phase 7: Final Setup

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-seed-run/references/final-setup.md` now and follow
it — it is this phase, not background. It covers the rewrite flush, the default-content cleanup, timezone, comments, and the author sweep.


---

## Seed Report

Print a summary of everything that was seeded:

```
=== Seed Complete ===
Pages created:     Home (ID: 5), Services (ID: 7), Contact (ID: 8)
Pages updated:     (none)
Front page:        Home (ID: 5)
Author:            admin (ID: 1) — 0 posts without one
Media imported:    12 of 14 succeeded
  reused:          3 already imported from the same source
  WARNING:         2 images failed (see below)
ACF fields seeded: 23 fields (primary: en)
Bilingual fields:  23 fields (es)
Menus created:     Primary EN, Primary ES, Footer EN, Footer ES
Menu locations:    primary-en, primary-es, footer-en, footer-es   (polylang: primary, footer)
Timezone:          America/New_York
Default content:   Deleted

Left alone — the client owns these:
  - page "About" (ID: 31) has no seed marker. Nothing was written to it, and no
    second About page was created. The menu points at ID 31.
  → If this page should be seeded, delete it and re-run, or add the marker by hand.
  - field hero_title on page "Home" (ID: 5) was edited in wp-admin since the last
    seed. Left as "Welcome to Acme"; the demo now says "Building Digital Excellence".
  - field contact_phone (options) was edited since the last seed.
  → Run with --force-fields to overwrite these with the demo's values.

Failed media imports:
  - hero_background: https://example.com/image1.jpg (403 Forbidden)
  - team_photo: https://example.com/image2.jpg (timeout)
  → Upload these manually in wp-admin > Media

Next step: Visit <site_url> to verify, then run /wp-finalize for the pre-delivery checklist.
```
