---
name: wp-demo-run
description: "The step detail of the /wp-demo run, split out of commands/wp-demo.md so the command stays a short map — the craft brief and its form interview, asset inventory and reference precedence, the grammar and composition plan with the family, world and image plan, the craft build of every page, and the section plan both modes record. Use when /wp-demo reaches a step that names one of these reference files, or when changing how a /wp-demo step behaves. Not for craft design rules (wp-demo-craft) or the demo page contract (wp-demo)."
user-invocable: false
---

# /wp-demo step detail

`commands/wp-demo.md` owns the order of the run. Each step that needs more than a few
paragraphs keeps its heading and entry condition there and sends the run to one file here. The
command reads the file at that step, not before, so a plain build never pays for the craft
brief and a craft build reads each part only when it gets there.

These files are the step itself, not background reading. When the command says to read one,
read it whole and follow it in order.

## References, by step

| Step | File | Covers |
|---|---|---|
| 2.6, item 3 | [references/craft-brief.md](references/craft-brief.md) | `demo/BRIEF.md`, the form interview (3a), the asset inventory (3.5), library references and motion clips (3.6), reference precedence (3.7) |
| 2.6, item 5 | [references/craft-composition.md](references/craft-composition.md) | The grammar, the composition plan, the family, signature move and world (5.4), the image plan (5.5) |
| 2.6, item 6 | [references/craft-build.md](references/craft-build.md) | `demo/index.html` and one file per page in the page set, what each page carries from `demo/DESIGN.md`, `demo/.image-plan.json` |
| 4.9 | [references/section-plan.md](references/section-plan.md) | `demo/.demo-plan.json` in both modes: its shape, unique section names, the slots craft mode records |

## Changing a step

Edit the reference file, not the command, unless the step order or the step's entry
condition changes. A check that guards a step's wording reads the command with these files
expanded in place (`tests/checks/lib/expand-command.sh`); `tests/checks/wp-demo-run.sh`
asserts that every file here is named both in this table and at its step in
`commands/wp-demo.md`.
