---
name: wp-init-run
description: "The step detail of the /wp-init run, split out of commands/wp-init.md so the command stays a short map — the Demo-First Path (delimiter check, project details read from the demo, the colour and font injection with the craft token aliases and the /wp-tailwindify decision), the font carry, the i18n helper and field-suffix rewrite, the generated .claude/CLAUDE.md, and plugin install, theme activation, site identity and the Tailwind build. Use when /wp-init reaches a step that names one of these reference files, or when changing how a /wp-init step behaves. Not for the bilingual helpers themselves (wp-bilingual, wp-polylang) or the Tailwind token system (wp-tailwind-system)."
user-invocable: false
---

# /wp-init step detail

`commands/wp-init.md` owns the order of the run. Each step that needs more than a few
paragraphs keeps its heading and entry condition there and sends the run to one file here. The
command reads the file at that step, not before, so a scaffold with no demo never pays for the
Demo-First Path or the font carry.

These files are the step itself, not background reading. When the command says to read one,
read it whole and follow it in order.

## References, by step

| Step | File | Covers |
|---|---|---|
| 0, Demo-First Path | [references/demo-first.md](references/demo-first.md) | Steps D1-D5: delimiter check, project details from the demo, confirmation, colours and fonts with the craft token aliases, `@theme static`, the `--container-max` guard, the `/wp-tailwindify` decision |
| 4.5 | [references/font-carry.md](references/font-carry.md) | Self-hosting every family the theme names, the Google Fonts fetch, `font-display: swap`, the one preload, the no-network fallback |
| 5 | [references/i18n.md](references/i18n.md) | The Polylang variant of `inc/i18n.php`, `SUPPORTED_LANGS` and `DEFAULT_LANG`, the field-suffix rewrite |
| 7 | [references/claude-md.md](references/claude-md.md) | The project `.claude/CLAUDE.md` template, its `## WP-CLI` and `## Demo` sections |
| 9 | [references/activate.md](references/activate.md) | Custom fields and translation plugins, theme activation, `blogname` and `blogdescription`, the Tailwind build |

## Changing a step

Edit the reference file, not the command, unless the step order or the step's entry
condition changes. A check that guards a step's wording reads the command with these files
expanded in place (`tests/checks/lib/expand-command.sh`); `tests/checks/wp-init-run.sh`
asserts that every file here is named both in this table and at its step in
`commands/wp-init.md`.
