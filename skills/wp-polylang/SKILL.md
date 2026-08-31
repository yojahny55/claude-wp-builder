---
name: wp-polylang
description: Polylang multilingual methodology — one post per language joined by translation groups, driven through the pll_* API
user-invocable: false
---

# Polylang Multilingual System

This skill documents how to drive Polylang correctly from automation. It is the
alternative to `wp-bilingual`, which documents the ACF `_suffix` pattern. The two
are mutually exclusive per project: `_suffix` keeps one post with `hero_title`
and `hero_title_es`; Polylang keeps one post per language, each with the same
unsuffixed fields, joined into a translation group.

`wp-bilingual` remains the default. Choosing Polylang does not deprecate it.

## Data model

Polylang stores two things per translatable object:

| What | Where |
|---|---|
| The object's language | the `language` taxonomy (`term_language` for terms) |
| Which objects are translations of each other | the `post_translations` taxonomy (`term_translations` for terms) |

A translation group is a single term whose description holds a serialised map of
`lang => object_id`. Both taxonomies must agree. **Writing either one directly is
the mistake this document exists to prevent** — a group written by hand is
routinely asymmetric, and Polylang then reports the page as untranslated while
the database looks correct.

Always go through the API:

| Task | Call |
|---|---|
| Set a post's language | `pll_set_post_language( $post_id, $lang )` |
| Join posts as translations | `pll_save_post_translations( [ 'es' => 12, 'en' => 34 ] )` |
| Read a post's group | `pll_get_post_translations( $post_id )` |
| Set a term's language | `pll_set_term_language( $term_id, $lang )` |
| Join terms as translations | `pll_save_term_translations( [ 'es' => 5, 'en' => 9 ] )` |
| List configured languages | `pll_languages_list()` |
| Default language | `pll_default_language()` |

`pll_save_post_translations()` **replaces** the whole group rather than merging
into it — it is not a delta call. Passing only `{source, target}` silently drops
every other language already in that group, including languages the array
never mentions. The correct pattern is to read the existing group first with
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
wp eval-file script.php es en
```

- Positional arguments arrive as `$args`. `--flags` are **not** available; WP-CLI
  consumes those itself.
- The file is evaluated as real PHP source, so quoting is not a hazard the way it
  is with `wp eval "..."`.
- `__DIR__` resolves to the script's own directory despite the `eval()` wrapper,
  so scripts can `require_once __DIR__ . '/pll-lib.php'`.

## Menus

Per-language menu assignment lives in the `polylang` option, not in theme mods:

```php
$options = get_option( 'polylang' );
$options['nav_menus'][ $theme_slug ][ $location ][ $lang ] = $menu_term_id;
update_option( 'polylang', $options );
```

`combine_location()` (public instance method on `PLL_Nav_Menu`, inherited by
`PLL_Admin_Nav_Menu`) composes the synthetic `location___lang` key the admin UI
and the frontend use. It is a naming helper, not a storage API — Polylang reads
the option path above directly at `src/admin/admin-nav-menu.php:279`.

A translated menu whose items still point at source-language objects is the most
common Polylang misconfiguration, and it is invisible until a visitor clicks and
lands in the wrong language. Re-point every item with
`pll_get_post_translations()`.

A `custom` menu item (a literal href, not an object id + type) is not
automatically safe just because it is not `post_type` or `taxonomy`: a
duplicated menu produces exactly this shape, and a `custom` item whose URL
happens to be one of the site's own permalinks needs re-pointing the same
way — see "Internal links inside translated content" below, which covers
this case too.

## Internal links inside translated content

A source post's content, or an ACF reference field, may link to another
source-language post by its own permalink. That href is copied verbatim into
the translated counterpart along with the rest of the content — nothing
parses it — so after import it still points at the SOURCE-language post: a
button on the English page sends the visitor back to the Spanish site. This
is the same defect as an untranslated menu item, in post content instead of
a menu.

`pll-import.php` closes this with a link-rewrite pass that runs **after
every post's counterpart exists**, for the same reason the parent-fixup pass
does: a link's target may gain its own counterpart later than the post
containing the link, on a run where the linking post itself was skipped by
hash. The pass therefore runs over **every target-language post with a
source-language counterpart**, not only the posts (re)written in the current
run — cheap and idempotent, so this is safe to do unconditionally on every
import, including a real site's already-translated pages. It applies to:

- same-host `href="..."` attributes inside `post_content`;
- ACF/SCF `link` (its `url` key — the `title` is translatable text and
  travels through the manifest instead), `page_link`, `post_object` and
  `relationship` fields (read from the SOURCE post every run, since these
  types are never part of the translatable payload — see below — so nothing
  else ever gives the target a value to begin with);
- `custom` menu items, whenever their URL resolves to a post.

Rules:

- **Same host only.** Compared by *host*, not by a `home_url()` string
  prefix — `url_to_postid()` itself tolerates a scheme mismatch (measured:
  an `https://` href against an `http://` site still resolved), and a
  literal prefix test would not. A different host is never touched.
- **Resolved with `url_to_postid()`.** A zero result means it is not a post
  URL (an archive, a term, the home page) and is left exactly as it is.
  Measured on this test site: a WooCommerce shop page's own permalink does
  **not** resolve through `url_to_postid()` even with the correct host —
  this is a real, observed limitation of WordPress's own resolver, not a
  bug in this pass, and such links are silently left alone like any other
  non-post URL.
- **Re-pointed via `pll_get_post( $id, $target_lang )`.** If it returns
  nothing, the target has no counterpart yet: the link is left pointed at
  the source and `pllx_warn()` names both posts. A link into the other
  language is bad; a broken link is worse.
- **Query string and fragment are preserved**, and a root-relative href is
  written back root-relative (`/servicios/?x=1#contacto` keeps both parts).
- Idempotent: every candidate rewrite is compared against the current value
  first, so a second run over unchanged content writes nothing and
  `post_content` stays byte-identical.

`pll-verify.php`'s check 9 audits the same condition on `post_content` as a
**hard failure** — the same severity as its menu-item check, for the same
reason — and check 1 (menus) now also inspects `custom` items whose URL
resolves to a post.

## An object with no language does not exist

Polylang filters every front-end query by the current language, and an object
carrying no `language` term matches none of them. A post, a page, a menu, a
media item or a **taxonomy term** created without `pll_set_post_language()` /
`pll_set_term_language()` is present in the database, visible in the admin, and
absent from the site. There is no warning. Assign a language in the same step
that creates the object, and sweep afterwards:

```bash
$WP eval 'foreach (get_posts(["post_type"=>"any","numberposts"=>-1,"post_status"=>"any"]) as $p) { if (!pll_get_post_language($p->ID)) echo "NO LANG: $p->ID $p->post_title\n"; }'
```

## Do not translate a taxonomy of proper nouns

Registering a taxonomy with `pll_get_taxonomies` looks free and is not. Where
the terms are proper nouns — provinces, countries, brands, venue names — most
of them are spelled identically in both languages, so translating the taxonomy
duplicates every term in order to relabel the one or two that differ. Three
things then go wrong:

1. **Slugs.** WordPress forces term slugs to be unique per taxonomy, so the
   translated copies can only be `matanzas-en`, `holguin-en`. An archive facet
   writes that slug straight into a URL the visitor shares.
2. **Import collision.** Because the "translated" name matches its source, an
   importer adopts the *existing* term as its own counterpart and flips its
   language — one project lost the province facet from every Spanish archive
   this way, with 14 terms silently reassigned from `es` to `en`.
3. **Counts.** A shared taxonomy's `get_terms()` count spans every object type
   registered to it; per-post-type facet counts must be recomputed.

Leave such a taxonomy **out** of `pll_get_taxonomies` so both languages share
one clean term list, and write the reason into `inc/post-types.php` — the next
person will otherwise "fix" the omission.

## Labels registered in PHP are not translatable strings

`cubasol_t()` covers the strings the templates print, but WordPress builds some
output from the labels passed to `register_post_type()`, which are plain
literals with no gettext behind them. `post_type_archive_title()` — the CPT
archive's `<title>` — is the one that bites: an English visitor gets the
Spanish plural over an English page. Filter it against a registered string:

```php
add_filter( 'post_type_archive_title', function ( $title, $post_type ) {
    $key = 'plural_' . $post_type;
    return cubasol_t( $key ) ?: $title;
}, 10, 2 );
```

Audit `wp_title`/`document_title_parts`, `the_archive_title`, and any admin
label a client will see, the same way.

## What free Polylang covers

Verified on Polylang 3.8.7 with no paid addon: `product` is translatable as a
post type, and `product_cat`, `product_tag`, `product_brand` and the `pa_*`
attribute taxonomies are all translatable. Product *content* needs no addon.

What does need the paid Polylang for WooCommerce addon is the runtime plumbing —
per-language cart, checkout and account page mapping, product variations, WC
emails. That is not content and is out of scope for content translation.

## ACF / SCF custom fields

`pllx_acf_payload()` in `pll-lib.php` flattens a post's custom-field values to a
dot-notation map (`pllx_acf_walk()`); `pllx_acf_write()` in `pll-import.php`
writes that map back through `update_field()`/`get_field()`. Both work against
whatever plugin defines `get_field_objects()`, `get_field()` and
`update_field()` — that is ACF or SCF, never both (see below).

**Translated** (the value is walked, sent through translation, written back):

| Field type | Key shape |
|---|---|
| `text`, `textarea`, `wysiwyg` | `name` |
| `group` (one level) | `group_name.sub_name` |
| `repeater` (one level) | `repeater_name.ROW_INDEX.sub_name` |
| `flexible_content` (one level) | `flex_name.ROW_INDEX.sub_name` |
| `link` (title only) | `link_name.title` |

A `flexible_content` row's own `acf_fc_layout` tag is never emitted as a
translatable key — it is a machine identifier, not text — but the importer
still needs it to write a valid row. A row the target already has keeps its
existing tag untouched by the read-modify-write; a row being created for the
first time (a brand-new translation counterpart) gets it backfilled from the
corresponding row on the *source* post, since that's the only other place
that still identifies the row's layout. Without this, a fresh flexible-content
row written through the same dot-notation path as a repeater row is invalid
and SCF/ACF silently drops the whole field — this was measured, not assumed
(see `tests/checks/wp-polylang-live.sh` and the Task 8 report in
`.superpowers/sdd/2026-08-21-wp-polylang-retrofit/`).

**Copied verbatim, never translated** (present in the field group, absent
from the dot-notation map, untouched by the importer): `image`, `number`,
`true_false`, `url`, and any other type not listed above.

**Re-pointed, not translated** (never walked into the manifest at all; fixed
up directly on the target post by the link-rewrite pass in `pll-import.php`
— see "Internal links inside translated content" above): `link`'s `url` key,
`page_link` (a permalink string, not an id — measured; see below), and
`post_object` / `relationship` (ids, given `return_format => 'id'` — see
below). `pllx_repoint_acf_refs()` reads these from the SOURCE post on every
run, resolves each reference through `pll_get_post()`, and writes the
target-language equivalent onto the target post, since nothing else ever
gives the target a value for these types to begin with.

Measured on the test site's fixture (`pll-acf-fixture.php`, extended for
Task 9): with `return_format` left at its default, `page_link` returns a
permalink **string**, never an id, and is not configurable to return one —
this is what "handle what you actually observe rather than what the
documentation implies" turned up here. `post_object` and `relationship` were
configured with `return_format => 'id'` for this pass to have a stable shape
to write; `pllx_acf_ref_id()` in `pll-import.php` also tolerates the
`return_format => 'object'` shape (`WP_Post`/array with `ID`) defensively,
though that was not the configuration measured.

**A plain `url` field stays a negative control, deliberately.** An ACF `url`
field that happens to hold an internal link is **not** re-pointed by this
pass, even though a `link` or `page_link` field holding the identical value
would be. The reasoning: `url`, `image`, `number` and `true_false` are all
generic scalar types with no reference semantics ACF itself is aware of —
treating "the string looks like this site's URL" as a signal would mean
guessing intent from content rather than from the field's declared type,
and would make a project's actual "do not touch this URL" field (exactly
what this test site's `pll_url` fixture field represents) unpredictably
mutable depending on what a translator happens to paste into it. `link`,
`page_link`, `post_object` and `relationship` are unambiguous because ACF
itself defines them as references; `url` is not, so it is left alone like
any other scalar. If a project needs a plain `url` field re-pointed, model
it as `link` or `page_link` instead.

**`clone` fields are deliberately never walked as their own type.** With the
default *seamless* display, a clone's sub-fields surface as ordinary siblings
under their own names in `get_field_objects()` and are already covered by the
branches above — walking `clone` too would re-emit the same value under a
second key. With *group* display, `get_field_objects()` returns the clone as
a **second** object (type `clone`) whose value duplicates the original
field's, backed by the same underlying meta; walking that would emit the same
text twice under two different dotted keys, and writing both back
independently risks the second write clobbering the first with a different
translation. Both shapes were probed live before reaching this conclusion —
adding a `clone` branch would open the exact "translate the same thing twice
and let the last write win" defect class this plan exists to close, not
prevent it.

**Ceiling:** one level of nesting inside `group`, `repeater` and
`flexible_content` — a group nested inside a repeater or a flexible-content
layout is not walked. Widen `pllx_acf_walk()` if a project needs more.

Verified against **Secure Custom Fields (SCF) 6.9.5** — the free,
wordpress.org fork that ships `repeater`, `group`, `flexible_content` and
`clone`, which ACF sells as PRO. ACF's free tier has none of those four types
and exposes the rest of this surface (`text`, `textarea`, `wysiwyg`, plain
`group`, plain `repeater`) through the identical API, so passing against SCF
implies passing against ACF free. ACF PRO was not available to test against
(no licence). **ACF and SCF cannot both be active** — both define
`get_field()`, `get_field_objects()` and `update_field()`, and activating the
second one over the first fatals the site. Install exactly one.

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

This matters for automation: a query filtered by `'lang' => $source` silently
excludes objects with no language — they never enter the result set, so
nothing downstream can see, count, or warn about them. Verified live on
Polylang 3.8.7: a WooCommerce catalogue (7 products, 9 `product_cat` terms)
enabled after initial activation had zero objects assigned any language,
while `post`/`page`/`attachment`/`category` — all present at activation —
were fully tagged. Anything that walks a site to find translatable content
must query without a `lang` filter, classify each object's language itself,
and count and report what has none — never assume "activated" means
"assigned everywhere."

On a site being retrofitted, the work is therefore not just creating
counterparts and joining them into groups — it may also require assigning a
source language to content Polylang never touched in the first place.
