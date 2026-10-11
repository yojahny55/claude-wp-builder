---
name: wp-tailwind-migrate-run
description: "The step detail of the /wp-tailwind-migrate run, split out of commands/wp-tailwind-migrate.md so the command stays a short map — Step 4 (the parallel wp-tailwind author-mode dispatch and the prompt every agent receives) and Step 6 (the convention check, the after-shots and the before/after comparison against the golden). Use when /wp-tailwind-migrate reaches a step that names one of these reference files, or when changing how a /wp-tailwind-migrate step behaves. Not for the baseline gate, the Tailwind v4 check or the golden capture (they stay in the command), nor for the decision ladder (wp-tailwind-system)."
user-invocable: false
---

# /wp-tailwind-migrate step detail

`commands/wp-tailwind-migrate.md` owns the order of the run. Each step that needs more than a
few paragraphs keeps its heading and entry condition there and sends the run to one file here.
The command reads the file at that step, not before.

These files are the step itself, not background reading. When the command says to read one,
read it whole and follow it in order.

## References, by step

| Step | File | Covers |
|---|---|---|
| 4 | [references/step-4.md](references/step-4.md) | The `wp-tailwind` author-mode dispatch: the verbatim mode line, the plain-CSS input state, breakpoint naming, the five inputs, the write boundary and the ban on running the convention check; what each agent does |
| 6 | [references/step-6.md](references/step-6.md) | The convention check by full path and how to read it under `--page`, the after-shots, the visual comparison and its noise floor, the numeric contract and the pass criteria |

## Changing a step

Edit the reference file, not the command, unless the step order or the step's entry
condition changes. A check that guards a step's wording reads the command with these files
expanded in place (`tests/checks/lib/expand-command.sh`); `tests/checks/wp-tailwind-migrate-run.sh`
asserts that every file here is named both in this table and at its step in
`commands/wp-tailwind-migrate.md`.
