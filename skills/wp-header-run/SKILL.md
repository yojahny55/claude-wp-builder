---
name: wp-header-run
description: "The step detail of the /wp-header run, split out of commands/wp-header.md so the command stays a short map — Step 4's wp-template prompt (header.php, the nav walker, the language switcher rule, class naming per template) and the CSS agent routing with the wp-tailwind author-mode prompt and file ownership. Use when /wp-header reaches a step that names one of these reference files, or when changing how a /wp-header step behaves. Not for the agents' own contracts (agents/wp-template.md, wp-css.md, wp-tailwind.md) or the Tailwind token system (wp-tailwind-system)."
user-invocable: false
---

# /wp-header step detail

`commands/wp-header.md` owns the order of the run. Step 4 needs far more than a few
paragraphs, so it keeps its heading there and sends the run to one file here per part. The
command reads each file at that step, not before.

These files are the step itself, not background reading. When the command says to read one,
read it whole and follow it in order.

## References, by step

| Step | File | Covers |
|---|---|---|
| 4 | [references/template-dispatch.md](references/template-dispatch.md) | The `wp-template` prompt: `header.php`, `inc/nav-walker.php`, the menu location helper, the language switcher per i18n strategy, the 24x24 target size, class naming per `Template:` |
| 4 | [references/css-routing.md](references/css-routing.md) | Routing the CSS agent by `Template:`, the `wp-tailwind` author-mode prompt that replaces Step 5, the file ownership rule, the editing rule the dispatch check relies on |

## Changing a step

Edit the reference file, not the command, unless the step order or the step's entry
condition changes. A check that guards a step's wording reads the command with these files
expanded in place (`tests/checks/lib/expand-command.sh`); `tests/checks/wp-header-run.sh`
asserts that every file here is named both in this table and at its step in
`commands/wp-header.md`.
