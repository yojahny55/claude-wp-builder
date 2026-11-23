---
name: wp-section-run
description: "Step detail of the /wp-section run, split out of the command. Use when /wp-section reaches a step that names one of these reference files, or when changing how a /wp-section step behaves."
user-invocable: false
---

# /wp-section step detail

`commands/wp-section.md` owns the order of the run. A step whose detail applies to only one kind
of run (a cinematic `--hybrid` build, a contact section) keeps its heading there and sends the run
to one file here per case. The command reads the
file at that step, not before, and a contact section never pays for the ordinary dispatch or the
other way round.

These files are the step itself, not background reading. When the command says to read one,
read it whole and follow it in order.

## References, by step

| Step | File | Covers |
|---|---|---|
| List mode, `--list` | [references/list-mode.md](references/list-mode.md) | The read-only `bin/demo-sections.mjs` call, what it prints, and its exit codes |
| 2, `--hybrid` set or implied | [references/hybrid.md](references/hybrid.md) | The four things that change on a cinematic trailing-flex build: the `trailing_sections` layout, `get_sub_field()` reads, `assets/css/cinematic.css`, the skipped Step 6 injection |
| 5, every section | [references/dispatch-rules.md](references/dispatch-rules.md) | The field naming convention, the GEO citability rubric, the `--transcribe` overlay, CSS agent routing by `Template:`, the one-writer-per-file ownership rule |
| 5, not a contact section | [references/non-contact.md](references/non-contact.md) | Agents 1-3 (`wp-acf`, `wp-template`, `wp-css` or `wp-tailwind` in author mode), their order per template, the tabs/accordion/filter markup contract |
| 5, contact section | [references/contact.md](references/contact.md) | The two-phase dispatch with `wp-cf7`, and where `wp-css` or `wp-tailwind` and `wp-template` sit in each phase |
| 6.6, `--visual` set | [references/visual-check.md](references/visual-check.md) | The page that shows the section, the `bin/section-diff.mjs` call and its exits, the CSS fix pass with the diff images, and when the three-round loop stops |
| 6.7, blog section | [references/blog-templates.md](references/blog-templates.md) | When a `blog`, `journal`, `news` or `posts` section runs `/wp-page blog`, the three cases that skip it, and what the summary says |
| 7, contact section | [references/summary-contact.md](references/summary-contact.md) | The contact summary: the CF7 form and email files, and the IDs of the forms created |

## Scripts

- [scripts/section-seeded.php](scripts/section-seeded.php) — run by Step 6.6 with `wp eval-file`: how many fields of `group_<slug>` hold content on the page the visual check measures (`-1` without ACF or the group).

## Changing a step

Edit the reference file, not the command, unless the step order or the step's entry
condition changes. A check that guards a step's wording reads the command with these files
expanded in place (`tests/checks/lib/expand-command.sh`); `tests/checks/wp-section-run.sh`
asserts that every file here is named both in this table and at its step in
`commands/wp-section.md`.
