# ACF / SCF custom fields under Polylang

How the bundled scripts carry a post's or a term's custom fields to its counterpart: which field
types are translated, copied or re-pointed, and why. The summary is in `../SKILL.md`.

## Contents

- Which plugin
- What the scripts walk and write
- A term's fields
- Translated types, and nesting
- Copied types
- Re-pointed types
- A plain `url` field is a negative control
- `clone` fields are never walked

## Which plugin

Use **Secure Custom Fields (SCF)**, the scaffold default — the free wordpress.org fork that ships
`repeater`, `flexible_content` and `clone`, which ACF sells as PRO. ACF free works for the
`text`, `textarea`, `wysiwyg` and `group` types only, through the identical API. **Never activate
both**: each defines `get_field()`, `get_field_objects()` and `update_field()`, and activating the
second over the first fatals the site.

## What the scripts walk and write

`pllx_acf_payload()` in `pll-lib.php` flattens a post's custom-field values to a dot-notation map
(`pllx_acf_walk()`); `pllx_acf_write()` in `pll-lib.php` writes that map back through
`update_field()`/`get_field()`. Both work against whichever plugin defines `get_field_objects()`,
`get_field()` and `update_field()`.

## A term's fields

**This covers a post's own fields. A taxonomy TERM'S fields are a separate surface Polylang's own
APIs never reach.** `pll_save_term_translations()` joins two terms into a translation group the
same way `pll_save_post_translations()` joins posts, but it copies and translates no custom-field
value: a repeater or a plain text field attached to a term is invisible to it. ACF/SCF accept the
string `"<taxonomy>_<term_id>"` everywhere a post id is otherwise expected (`get_field_objects()`,
`get_field()`, `update_field()`), so the import walks and writes a term's fields through the same
`pllx_acf_walk()` / `pllx_acf_write()` with that string in place of a post id, and copies its
non-text fields with `pllx_acf_copy_untranslated_term()`, the term-meta version of
`pllx_acf_copy_untranslated()`.

**Ceiling:** reference types (`link`, `page_link`, `post_object`, `relationship`) on a term reach
no counterpart at all. The link-rewrite pass is written against post content and post ids, and
has no term equivalent.

## Translated types, and nesting

The value is walked, sent through translation, and written back:

| Field type | Key shape |
|---|---|
| `text`, `textarea`, `wysiwyg` | `name` |
| `group` | `group_name.sub_name` |
| `repeater` | `repeater_name.ROW_INDEX.sub_name` |
| `flexible_content` | `flex_name.ROW_INDEX.sub_name` |
| `link` (title only) | `link_name.title` |

Containers are walked to any depth: a `group` inside a `repeater` row, a `repeater` inside a
flexible-content layout, and so on, each level adding its own segment (`sections.0.cta.label`).
A flexible-content row's sub-fields are matched by layout **name**. The writer resolves a dotted
path by the field structure, not by counting dots, and refuses a path that does not match it
rather than writing to a guessed location.

A `flexible_content` row's own `acf_fc_layout` tag is never emitted as a translatable key — it is
a machine identifier, not text — but the importer still needs it to write a valid row. A row the
counterpart already has keeps its tag untouched by the read-modify-write; a row created for the
first time gets it backfilled from the corresponding row on the *source* post, the only other
place that identifies the row's layout. Without this, a fresh flexible-content row written
through the same dot-notation path as a repeater row is invalid, and SCF/ACF silently drops the
whole field.

## Copied types

`image`, `number`, `true_false`, `url`, and any other type not listed above are present in the
field group and absent from the dot-notation map. `pllx_acf_copy_untranslated()` in
`pll-import.php` copies their stored rows onto the counterpart verbatim — and only when the
counterpart has never had that field set, so an editor's later change is never undone. An
`image` or `file` id is copied as-is, not swapped for that attachment's own translation.

## Re-pointed types

`link`'s `url` key, `page_link`, `post_object` and `relationship` are never walked into the
manifest. `pllx_repoint_acf_refs()` reads them from the SOURCE post on every run — wherever they
sit, including inside groups, repeater rows and flexible-content layouts — resolves each through
`pll_get_post()`, and writes the target-language equivalent onto the counterpart, since nothing
else ever gives the counterpart a value for these types. It runs inside the link-rewrite pass
(`internal-links.md`).

- With `return_format` left at its default, `page_link` returns a permalink **string**, never an
  id, and cannot be configured to return one.
- `post_object` and `relationship` are expected with `return_format => 'id'`; `pllx_acf_ref_id()`
  in `pll-lib.php` also accepts the `return_format => 'object'` shape (`WP_Post`/array with `ID`).
- What the pass last wrote is recorded per dotted path in `_pll_ref_<path>` meta on the
  counterpart. A value that no longer matches it, and is not the source's own unmapped value, is
  an editor's change and is left alone with a warning; two references differing only by row keep
  separate records.
- A reference whose target has no counterpart yet stays pointed at the source, with a warning.

## A plain `url` field is a negative control

An ACF `url` field that holds an internal link is **not** re-pointed, although a `link` or
`page_link` field with the identical value would be. `url`, like `image`, `number` and
`true_false`, is a scalar with no reference semantics ACF knows of; treating "looks like this
site's URL" as a signal would guess intent from content instead of the declared type, and would
make a project's "do not touch this URL" field change with whatever a translator pastes. Model a
URL that must follow the language as `link` or `page_link`.

## `clone` fields are never walked

With the default *seamless* display, a clone's sub-fields surface as ordinary siblings in
`get_field_objects()` and are already walked. With *group* display, `get_field_objects()` returns
the clone as a **second** object (type `clone`) over the same stored meta; walking it would emit
the same text under two dotted keys, and writing both back would let the second translation
overwrite the first. The text walk, the copy and the reference pass all skip `clone` for that
reason.
