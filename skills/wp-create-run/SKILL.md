---
name: wp-create-run
description: "Step detail of the /wp-create run, split out of the command. Use when /wp-create reaches a step that names one of these reference files, or when changing how a /wp-create step behaves."
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
| 1 | [references/detect-output.md](references/detect-output.md) | The JSON structure `wp-env-setup.sh detect` prints |
| 4.2 | [references/overwrite.md](references/overwrite.md) | Overwrite on an existing manifest: export to the host, confirmation, `core download --force`, `db reset --yes` |
| 4.3 | [references/env-templates.md](references/env-templates.md) | The template for each environment, the `{{placeholder}}` values, port auto-assignment, the validation |
| 4.5 | [references/configure.md](references/configure.md) | `wp config create`, `FS_METHOD direct` and where not to carry it, `WP_ENVIRONMENT_TYPE local`, the validation of each |
| 4.10 | [references/plugin-profile.md](references/plugin-profile.md) | Profile validation, installing each plugin, required versus optional outcomes, `plugins.degraded` |
| 4.14 | [references/languages.md](references/languages.md) | Full locale codes (a bare `es` is skipped with exit 0), switching the site language, the validation |
| 4.15 | [references/permissions.md](references/permissions.md) | The PHP user, the inherited default ACL on `wp-content`, validation and the `setfacl` failure notes |
| 5 | [references/manifest.md](references/manifest.md) | The `.wp-create.json` written to the project root, its fields and the validation that follows |

## Changing a step

Edit the reference file, not the command, unless the step order or the step's entry
condition changes. A check that guards a step's wording reads the command with these files
expanded in place (`tests/checks/lib/expand-command.sh`); `tests/checks/wp-create-run.sh`
asserts that every file here is named both in this table and at its step in
`commands/wp-create.md`.
