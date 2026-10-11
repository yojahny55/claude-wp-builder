---
name: wp-page-run
description: "The step detail of the /wp-page run, split out of commands/wp-page.md so the command stays a short map — the per-type dispatch for the blog, legal, 404, search and embed page types (template, ACF fields and CSS agent prompts). Use when /wp-page reaches a type that names one of these reference files, or when changing how a /wp-page type behaves. Not for the argument parse, the CSS agent routing, the tailwind prompt body or the generic and custom types (they stay in the command), nor for the agents' own contracts (agents/wp-template.md, wp-acf.md, wp-css.md, wp-tailwind.md)."
user-invocable: false
---

# /wp-page step detail

`commands/wp-page.md` owns the order of the run. Each page type that needs more than a few
paragraphs keeps its heading there and sends the run to one file here. The command reads the
file at that type, not before, so a `/wp-page 404` run never pays for the blog or legal dispatch.

These files are the step itself, not background reading. When the command says to read one,
read it whole and follow it in order.

## References, by type

| Type | File | Covers |
|---|---|---|
| blog | [references/blog.md](references/blog.md) | `archive.php`, `single.php` and the journal card and single-post parts, `fields/blog.php`, the BLOG CSS dispatch |
| legal | [references/legal.md](references/legal.md) | `page-legal.php`, `inc/legal-search.php` (legal pages out of site search), `fields/legal.php`, the CSS dispatch |
| 404 | [references/404.md](references/404.md) | The styled `404.php` and its CSS dispatch |
| search | [references/search.md](references/search.md) | The styled `search.php` with its no-results state and its CSS dispatch |
| embed | [references/embed.md](references/embed.md) | The provider-embed template and its marked insertion point, optional chrome fields, the CSS dispatch, the `Requires plugin` summary line |

## Changing a step

Edit the reference file, not the command, unless the step order or the step's entry
condition changes. A check that guards a type's wording reads the command with these files
expanded in place (`tests/checks/lib/expand-command.sh`); `tests/checks/wp-page-run.sh`
asserts that every file here is named both in this table and at its type in
`commands/wp-page.md`.
