---
name: wp-polylang
description: Documents how to drive Polylang from automation — one post per language joined into translation groups through the pll_* API, and the bundled pll-setup, pll-export, pll-import and pll-verify scripts run with wp eval-file. Covers per-language menus, internal links, posts and terms with no language, WooCommerce products and categories, proper-noun taxonomies, language prefixes and CPT rewrite bases, hreflang, ACF/SCF fields and strings. Use when the project's .claude/CLAUDE.md records i18n strategy polylang (the default for new scaffolds), when translating or retrofitting a site with /wp-polylang, or when a translated page serves the wrong language, links back to the source language or is missing from the site. Not for the suffix model with hero_title_es fields (wp-bilingual), and not for WPML.
user-invocable: false
---

# Polylang Multilingual System

This skill documents how to drive Polylang correctly from automation. It is the
alternative to `wp-bilingual`, which documents the ACF `_suffix` pattern. The two
are mutually exclusive per project: `_suffix` keeps one post with `hero_title`
and `hero_title_es`; Polylang keeps one post per language, each with the same
unsuffixed fields, joined into a translation group.

Polylang is the default for new scaffolds, because only one post per language gives a
crawler a URL, an hreflang pair and Rank Math meta per language. A project whose
`.claude/CLAUDE.md` has no `i18n strategy` line predates the choice and is `suffix`.

`$WP` below is `wp_cli.wrapper` from `.wp-create.json` — the `wp` command itself on a native
install, or its Docker, DDEV, Lando or wp-env wrapper. Tested range: Polylang 3.6 to 3.8 and
Secure Custom Fields 6.9, free, with no paid addon.

## Reference files

- [references/acf-fields.md](references/acf-fields.md) — which ACF/SCF field types are
  translated, copied or re-pointed, nesting, a term's own fields, and which plugin to use. Read
  when a translated post or term carries custom fields, or a field came out blank, untranslated
  or pointing at the source language.
- [references/internal-links.md](references/internal-links.md) — what the link-rewrite pass
  changes in post content, ACF references and `custom` menu items, and its rules. Read when a
  translated page links back to the source language.
- [references/taxonomies-and-rewrite-bases.md](references/taxonomies-and-rewrite-bases.md) —
  why a taxonomy of proper nouns stays untranslated, prefixing links into it, and translating a
  CPT's or taxonomy's rewrite base. Read when registering a taxonomy or CPT for translation, or
  when a translated archive answers at an untranslated base.

## Data model

Polylang stores two things per translatable object:

| What | Where |
|---|---|
| The object's language | the `language` taxonomy (`term_language` for terms) |
| Which objects are translations of each other | the `post_translations` taxonomy (`term_translations` for terms) |

A translation group is a single term whose description holds a serialised map of
`lang => object_id`. Both taxonomies must agree. **Writing either one directly is
the mistake this document exists to prevent** — a translation group written by hand is
routinely asymmetric, and Polylang then reports the page as untranslated while
the database looks correct.

Always go through the API:

| Task | Call |
|---|---|
| Set a post's language | `pll_set_post_language( $post_id, $lang )` |
| Join posts as translations | `pll_save_post_translations( [ 'es' => 12, 'en' => 34 ] )` |
| Read a post's translation group | `pll_get_post_translations( $post_id )` |
| Set a term's language | `pll_set_term_language( $term_id, $lang )` |
| Join terms as translations | `pll_save_term_translations( [ 'es' => 5, 'en' => 9 ] )` |
| List configured languages | `pll_languages_list()` |
| Default language | `pll_default_language()` |

`pll_save_post_translations()` **replaces** the whole translation group rather than merging
into it — it is not a delta call. Passing only `{source, target}` silently drops
every other language already in that translation group, including languages the array
never mentions. Read the existing translation group first with
`pll_get_post_translations()`, merge the source and target ids into it, and
save the merged result:

```php
$group = pll_get_post_translations( $source_id );
$group[ $source ] = $source_id;
$group[ $target ] = $target_id;
pll_save_post_translations( $group );
```

Same shape for terms with `pll_get_term_translations()` /
`pll_save_term_translations()`. `create_media_translation()` is the one
exception — it merges internally, so it does not need this pattern.

## Running PHP against a site

No `wp pll` command is available, so automation runs through `wp eval-file`:

```bash
$WP eval-file script.php es en
```

- Positional arguments arrive as `$args`. `--flags` are **not** available; WP-CLI
  consumes those itself.
- The file is evaluated as real PHP source, so it carries none of the shell-quoting
  hazards of a multi-statement `$WP eval "..."`.
- `__DIR__` resolves to the script's own directory despite the `eval()` wrapper,
  so scripts can `require_once __DIR__ . '/pll-lib.php'`.

### The bundled scripts, in order

Run them rather than writing new ones. `SCRIPTS` is
`${CLAUDE_PLUGIN_ROOT}/skills/wp-polylang/scripts`; `/wp-polylang` drives them in this order.
Every script exits `0` on success and `1` on failure, printing the reason on stderr as
`[x] …`. Exit 1 means stop and read stderr; there is no other code. Besides the causes in the
table, each exits 1 on a missing argument (it prints its usage line) and on Polylang being
inactive, and steps 2, 4 and 5 on a language Polylang has not configured — run step 1 first.

| # | Run | What it does | Needs | Exit 1 means |
|---|---|---|---|---|
| 1 | `$WP eval-file "$SCRIPTS/pll-setup.php" <source> <target>` | Verifies Polylang is usable and creates a missing language with a sane locale (`en_US`, `es_ES`, not Polylang's first match) | Polylang active | Polylang inactive, an unrecognised code, or source = target |
| 2 | `$WP eval-file "$SCRIPTS/pll-export.php" <source> <target> <out.json>` | Writes a manifest of everything missing or stale in the target language, and warns about objects with no language | Polylang active | The manifest could not be encoded or written |
| 3 | — | Translate the manifest's values (`/wp-polylang` Step 5 holds the rules) | | |
| 4 | `$WP eval-file "$SCRIPTS/pll-import.php" <translated.json>` | Validates the whole file before the first write, then writes it through the Polylang API, fixes parents, and runs the link-rewrite pass | Polylang; ACF or SCF only when the manifest carries `acf` values | A validation error (nothing was written) or a missing plugin |
| 5 | `$WP eval-file "$SCRIPTS/pll-verify.php" <source> <target>` | Audits the translated site | Polylang active | Any hard failure — including "nothing to audit" |

`pll-lib.php` holds the helpers the others `require`; it is never run on its own.

`pll-import.php` is safe to re-run after any failure: hashes are recorded only after a
successful write, so a second run resumes where the first stopped and skips everything already
current. Loop on the verifier:

1. Run `pll-verify.php`. Exit 0 is done.
2. On exit 1, read every `[x]` line. A failed or partial write: re-run `pll-import.php`. A
   missing counterpart: export, translate and import again. A link or menu item into the wrong
   language: re-run `pll-import.php`, whose link-rewrite pass fixes it once the target's
   counterpart exists.
3. Re-run `pll-verify.php`, and stop at exit 0.

Warnings do not fail the run, but "no language assigned" ones still need fixing: those objects
were not audited at all. Assign the source language (below) and run the loop again.

## What the importer does that you might not expect

- Counterparts are created published, mirroring the source's status.
- **Parents are rewritten on every run.** A counterpart's post or term parent is set to the
  source parent's counterpart each time, so a page an editor deliberately re-parented in the
  target language is put back. A child whose parent has no counterpart stays unhashed and is
  retried on the next run.
- **Media is not translated.** An image or file id in an ACF field is copied to the counterpart
  as-is, not swapped for that attachment's own translation.
- **ACF references are re-pointed and owned per path.** What the link-rewrite pass last wrote
  into a `link`, `page_link`, `post_object` or `relationship` field is recorded in
  `_pll_ref_<path>` meta, so an editor's later change to one row is left alone and reported
  (`references/acf-fields.md`).

## Menus

Per-language menu assignment lives in the `polylang` option, not in theme mods:

```php
$options = get_option( 'polylang' );
$options['nav_menus'][ $theme_slug ][ $location ][ $lang ] = $menu_term_id;
update_option( 'polylang', $options );
```

**That option is an override, not the assignment.** Polylang's frontend filter only
substitutes a location it finds already present in the core `nav_menu_locations`
theme_mod; it never adds one. Written alone, on a location that theme_mod has never had,
the option leaves the filter nothing to override: `wp_nav_menu()` falls through to its
fallback markup for every language, the default included — and the default's fallback can
look identical to its real menu, so nothing looks broken until a second language is
checked. Register one language's menu the normal way first, with
`$WP menu location assign <menu> <location>` (which writes the theme_mod), then write the
per-language override. `pll-import.php` does this on every menu it writes: a location with
no `nav_menu_locations` entry is seeded with the source-language menu.

A translated menu whose items still point at source-language objects is the most common
Polylang misconfiguration, and it is invisible until a visitor clicks and lands in the
wrong language. Re-point every item with `pll_get_post_translations()` — `custom` items
included, whenever their URL is one of the site's own permalinks.

## Internal links inside translated content

A link in a source post's content or ACF reference fields is copied into the counterpart
verbatim, so after import it still points at the source-language post. `pll-import.php`'s
link-rewrite pass re-points same-host links that resolve to a post, in `post_content`, in
ACF references and in `custom` menu items, on every target-language post on every run;
`pll-verify.php` fails the site on any it missed. The rules — same host only, resolved with
`url_to_postid()`, left pointed at the source with a warning when the target has no
counterpart — are in `references/internal-links.md`.

## An object with no language does not exist

Polylang filters every front-end query by the current language, and an object
carrying no `language` term matches none of them. A post, a page, a menu, a
media item or a **taxonomy term** created without `pll_set_post_language()` /
`pll_set_term_language()` is present in the database, visible in the admin, and
absent from the site. There is no warning. Assign a language in the same step
that creates the object, and sweep afterwards.

Sweep both halves. `post_type => "any"` silently skips attachments — they are
`exclude_from_search` — so the types are listed and filtered instead, and terms
need their own pass because no post query ever reaches them. `pll-verify.php` counts these
objects per type; the sweep names each one:

```bash
# Posts, pages, menu items and media.
$WP eval 'foreach (get_post_types() as $pt) { if (!pll_is_translated_post_type($pt)) continue; foreach (get_posts(["post_type"=>$pt,"numberposts"=>-1,"post_status"=>"any"]) as $p) { if (!pll_get_post_language($p->ID)) echo "NO LANG: {$pt} {$p->ID} {$p->post_title}\n"; } }'

# Taxonomy terms.
$WP eval 'foreach (get_taxonomies() as $tax) { if (!pll_is_translated_taxonomy($tax)) continue; foreach (get_terms(["taxonomy"=>$tax,"hide_empty"=>false]) as $t) { if (!pll_get_term_language($t->term_id)) echo "NO LANG: {$tax} {$t->term_id} {$t->name}\n"; } }'
```

Both must print nothing. The `pll_is_translated_*` guards keep the sweep quiet
about types and taxonomies Polylang was never asked to translate, which have no
language by design.

## Taxonomies and rewrite bases

- **Do not translate a taxonomy of proper nouns** (provinces, brands, venues). Duplicating
  every term to relabel the few that differ forces `-en` slugs into shared URLs, lets an
  importer adopt the source term as its own counterpart and flip its language, and splits
  facet counts. Leave such a taxonomy out of `pll_get_taxonomies`, write the reason into
  `inc/post-types.php`, and add the language prefix to links into it with two filters.
- **Polylang never translates a rewrite base.** A CPT registered with
  `'rewrite' => ['slug' => 'lawyers']` answers at `/en/lawyers/`. A translated base takes an
  extra rewrite rule plus a base swap in every permalink filter, chosen from the URL in hand,
  never from the current reader.

Both patterns, with the filters: `references/taxonomies-and-rewrite-bases.md`.

## Labels registered in PHP are not translatable strings

`prefix_t()` covers the strings the templates print, but WordPress builds some
output from the labels passed to `register_post_type()`, which are plain
literals with no gettext behind them. `post_type_archive_title()` — the CPT
archive's `<title>` — is the one that bites: an English visitor gets the
Spanish plural over an English page. Filter it against a registered string:

```php
add_filter( 'post_type_archive_title', function ( $title, $post_type ) {
    $key   = 'plural_' . $post_type;
    $label = prefix_t( $key );
    // prefix_t() returns the key itself when it has no entry, never ''.
    return $label !== $key ? $label : $title;
}, 10, 2 );
```

Audit `wp_title`/`document_title_parts`, `the_archive_title`, and any admin
label a client will see, the same way.

**Rank Math breadcrumbs need the same routing.** Their CPT-archive crumb is built from the
post type's registered label, not from `post_type_archive_title()`, so `/en/<cpt-plural>/`
and every single under it still show the primary-language plural after the filter above.
The `rank_math/frontend/breadcrumb/items` filter in `wp-audit-rankmath` Step 15 routes that
crumb through the same `plural_<post_type>` key.

## What free Polylang covers

Without a paid addon, `product` is translatable as a post type, and `product_cat`,
`product_tag`, `product_brand` and the `pa_*` attribute taxonomies are all translatable.
Product *content* needs no addon.

What does need the paid Polylang for WooCommerce addon is the runtime plumbing —
per-language cart, checkout and account page mapping, product variations, WC
emails. That is not content and is out of scope for content translation.

## ACF / SCF custom fields

The scripts carry a post's and a term's custom fields to the counterpart. Text types
(`text`, `textarea`, `wysiwyg`, a `link`'s title) are walked to any depth through `group`,
`repeater` and `flexible_content`, translated and written back by dotted path; other types
are copied once, only to a counterpart that never had the field; reference types are
re-pointed to the target language. A term's own fields are a separate surface that
`pll_save_term_translations()` never touches. Use SCF, the scaffold default; never activate
ACF and SCF together. The full rules: `references/acf-fields.md`.

## Strings

`pll_register_string()` registers a string for translation, but only the theme or
plugin that owns a string can register it. Polylang itself registers four strings
under the `WordPress` context: `blogname`, `blogdescription`, `date_format`, and
`time_format`. Empty values are absent from the table, so a site with no tagline
shows three entries instead of four.

The `date_format` and `time_format` options contain PHP date formats, not prose.
The Spanish-locale default for `date_format` is `j \d\e F \d\e Y`; English-locale
is `F j, Y`. Translating these produces garbage. Exclude them by comparing against
`get_option('date_format')` and `get_option('time_format')` rather than by
guessing at their shape.

Theme strings written as `__()` / `_e()` are **gettext**, a different mechanism
entirely, translated through `.po`/`.mo` files and not through Polylang's string
table. Do not conflate the two.

## Activation behaviour

Activating Polylang assigns a default language only to the post types and
taxonomies that were already registered as translatable **at that moment**. A
post type or taxonomy enabled for translation later (a common retrofit step —
e.g. turning on `product`/`product_cat` after the plugin has been running for
a while) keeps every one of its existing objects with **no language assigned
at all**. `pll_get_post_language()` / `pll_get_term_language()` return `false`
for them, not the default language.

A query filtered by `'lang' => $source` silently excludes those objects — they never enter
the result set, so nothing downstream can see, count, or warn about them. A WooCommerce
catalogue enabled after activation can have no product and no category with a language while
`post`, `page`, `attachment` and `category` are fully tagged. Anything that walks a site to
find translatable content must query without a `lang` filter, classify each object's
language itself, and count and report what has none. On a retrofit the work therefore
includes assigning a source language to content Polylang never touched.
