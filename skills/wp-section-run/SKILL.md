---
name: wp-section-run
description: "The step detail of the /wp-section run, split out of commands/wp-section.md so the command stays a short map — Step 5's agent dispatch: the field naming convention, GEO citability, the --transcribe overlay, CSS agent routing and file ownership, the three-agent dispatch for an ordinary section, and the two-phase dispatch for a contact section. Use when /wp-section reaches a step that names one of these reference files, or when changing how a /wp-section step behaves. Not for the agents' own contracts (agents/wp-acf.md, wp-template.md, wp-css.md, wp-tailwind.md, wp-cf7.md) or the Tailwind token system (wp-tailwind-system)."
user-invocable: false
---

# /wp-section step detail

`commands/wp-section.md` owns the order of the run. Step 5 needs far more than a few paragraphs,
so it keeps its heading there and sends the run to one file here per case. The command reads the
file at that step, not before, and a contact section never pays for the ordinary dispatch or the
other way round.

These files are the step itself, not background reading. When the command says to read one,
read it whole and follow it in order.

## References, by step

| Step | File | Covers |
|---|---|---|
| 5, every section | [references/dispatch-rules.md](references/dispatch-rules.md) | The field naming convention, the GEO citability rubric, the `--transcribe` overlay, CSS agent routing by `Template:`, the one-writer-per-file ownership rule |
| 5, not a contact section | [references/non-contact.md](references/non-contact.md) | Agents 1-3 (`wp-acf`, `wp-template`, `wp-css` or `wp-tailwind` in author mode), their order per template, the tabs/accordion/filter markup contract |
| 5, contact section | [references/contact.md](references/contact.md) | The two-phase dispatch with `wp-cf7`, and where `wp-css` or `wp-tailwind` and `wp-template` sit in each phase |

## Changing a step

Edit the reference file, not the command, unless the step order or the step's entry
condition changes. A check that guards a step's wording reads the command with these files
expanded in place (`tests/checks/lib/expand-command.sh`); `tests/checks/wp-section-run.sh`
asserts that every file here is named both in this table and at its step in
`commands/wp-section.md`.
