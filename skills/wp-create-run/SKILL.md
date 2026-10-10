---
name: wp-create-run
description: "The step detail of the /wp-create run, split out of commands/wp-create.md so the command stays a short map — the environment config templates and port assignment, the plugin profile install with its required-versus-optional outcomes, and the .wp-create.json manifest. Use when /wp-create reaches a step that names one of these reference files, or when changing how a /wp-create step behaves. Not for the environment helper itself (wp-environments) or the manifest validator (bin/wp-config.mjs)."
user-invocable: false
---

# /wp-create step detail

`commands/wp-create.md` owns the order of the run. Each step that needs more than a few
paragraphs keeps its heading and entry condition there and sends the run to one file here. The
command reads the file at that step, not before, so a run does not pay for the manifest or the
plugin profile before it reaches them.

These files are the step itself, not background reading. When the command says to read one,
read it whole and follow it in order.

## References, by step

| Step | File | Covers |
|---|---|---|
| 4.3 | [references/env-templates.md](references/env-templates.md) | The template for each environment, the `{{placeholder}}` values, port auto-assignment, the validation |
| 4.10 | [references/plugin-profile.md](references/plugin-profile.md) | Profile validation, installing each plugin, required versus optional outcomes, `plugins.degraded` |
| 5 | [references/manifest.md](references/manifest.md) | The `.wp-create.json` written to the project root, its fields and the validation that follows |

## Changing a step

Edit the reference file, not the command, unless the step order or the step's entry
condition changes. A check that guards a step's wording reads the command with these files
expanded in place (`tests/checks/lib/expand-command.sh`); `tests/checks/wp-create-run.sh`
asserts that every file here is named both in this table and at its step in
`commands/wp-create.md`.
