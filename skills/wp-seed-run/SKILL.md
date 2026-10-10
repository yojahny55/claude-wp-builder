---
name: wp-seed-run
description: "The step detail of the /wp-seed run, split out of commands/wp-seed.md so the command stays a short map — parsing the demo HTML, importing media by source identity, seeding the primary-language ACF fields with the three-way compare, the bilingual content for Polylang and the field-suffix strategy, the menus and their locations, and the final setup (rewrite flush, default-content cleanup, timezone, comments, author sweep). Use when /wp-seed reaches a phase that names one of these reference files, or when changing how a /wp-seed phase behaves. Not for the WP-CLI persistence rules (wp-cli-patterns) or the bilingual helpers themselves (wp-bilingual, wp-polylang)."
user-invocable: false
---

# /wp-seed step detail

`commands/wp-seed.md` owns the order of the run. Each phase that needs more than a few
paragraphs keeps its heading and entry condition there and sends the run to one file here. The
command reads the file at that phase, not before, so a run does not pay for the menu or
bilingual detail while it is still parsing the demo.

These files are the phase itself, not background reading. When the command says to read one,
read it whole and follow it in order.

## References, by phase

| Phase | File | Covers |
|---|---|---|
| 1 | [references/parse-demo.md](references/parse-demo.md) | Arguments, locating the demo file, single- versus multi-page detection, the per-file parse by BEM class |
| 3 | [references/import-media.md](references/import-media.md) | Resolving attachments by source identity, the import loop, seeding assets by role |
| 4 | [references/acf-fields.md](references/acf-fields.md) | Field ownership, the three-way compare, `update_field()` via `wp eval`, the `wp_options` alternative, verification |
| 5 | [references/bilingual.md](references/bilingual.md) | The Polylang and field-suffix variants of the secondary-language content |
| 6 | [references/menus.md](references/menus.md) | The location table per `i18n strategy`, menu structures and items, location assignment, verification |
| 7 | [references/final-setup.md](references/final-setup.md) | Rewrite flush, default-content cleanup, timezone, comments, the author sweep |

## Changing a phase

Edit the reference file, not the command, unless the phase order or the phase's entry
condition changes. A check that guards a phase's wording reads the command with these files
expanded in place (`tests/checks/lib/expand-command.sh`); `tests/checks/wp-seed-run.sh`
asserts that every file here is named both in this table and at its phase in
`commands/wp-seed.md`.
