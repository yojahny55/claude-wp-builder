---
name: wp-tailwindify-run
description: "Step detail of the /wp-tailwindify run, split out of the command. Use when /wp-tailwindify reaches a step that names one of these reference files, or when changing how a /wp-tailwindify step behaves."
user-invocable: false
---

# /wp-tailwindify step detail

`commands/wp-tailwindify.md` owns the order of the run. Each step that needs more than a few
paragraphs keeps its heading and entry condition there and sends the run to one file here. The
command reads the file at that step, not before.

These files are the step itself, not background reading. When the command says to read one,
read it whole and follow it in order.

## References, by step

| Step | File | Covers |
|---|---|---|
| 3 | [references/dispatch.md](references/dispatch.md) | The context handed to the `wp-tailwind` agent: input and linked stylesheets, output path, the `.tmp` write contract, the Tailwind v4 colour rule, Preflight, bare element selectors, inclusive `max-width`, cascade layers |
| 4 | [references/verify.md](references/verify.md) | The structural checks, the rendering parity gate, the `\mv -f` move with its post-condition check, the report |

## Changing a step

Edit the reference file, not the command, unless the step order or the step's entry
condition changes. A check that guards a step's wording reads the command with these files
expanded in place (`tests/checks/lib/expand-command.sh`); `tests/checks/wp-tailwindify-run.sh`
asserts that every file here is named both in this table and at its step in
`commands/wp-tailwindify.md`.
