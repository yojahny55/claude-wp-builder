---
description: One-shot section builder — generates ACF fields + template part + CSS for a section from the demo
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "<section-name> | --list [--page <slug>] [screenshot-path] [--cf7] [--hybrid] [--no-hybrid] [--defer-promotion] [--page <slug>] [--target <template>] [--transcribe] [--block <name>] [--css <source>] [--no-blog-page] [--force-adopted]"
---

# WP Section — One-Shot Section Builder

Generate ACF field definitions, a template part, and CSS for a single section — all in one command. On `basic` it dispatches three agents in parallel; on `tailwind`, `wp-tailwind` runs after `wp-template` returns (see File ownership below).

## List mode (`--list`)

If `$ARGUMENTS` contains `--list`, build nothing; stop before the adopted-site guard and every
later step. It only prints the demo's sections: no manifest, theme or name needed.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-section-run/references/list-mode.md` now and follow it.

## Adopted-site guard

Run this before anything else. This command builds a theme, sections or content on the assumption
that the theme is one this plugin scaffolded; on an adopted site (a third-party theme) it would
overwrite that theme or generate one that does not belong. `${PROJECT_PATH}` is the WordPress project
root, the directory that holds the project manifest.

```bash
bash -c 'node "$1/bin/wp-config.mjs" require-origin "$2"' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

Exit `0` continue. Exit `5` stop and print the message verbatim: `adopted site with a third-party theme:
use /wp-audit, /wp-debug or /wp-update`. If `$ARGUMENTS` contains `--force-adopted`, append it to the
call (and ignore it everywhere else): the operator chose to build on an adopted site on purpose.

## Step 1: Parse Arguments

Parse `$ARGUMENTS`:
- **First word** = section name (required, e.g., `hero`, `services`, `about`, `contact`)
- **Remaining non-flag word** = screenshot path (optional; a flag token or its value is never treated as the screenshot path)
- **`--cf7` flag** = force CF7 contact form integration (optional)
- **`--hybrid` flag** = cinematic projects only (`Template: cinematic`): build the section as a **trailing flex layout** appended to the `trailing_sections` flexible-content field in `fields/trailing-sections.php`, not as a standalone field group, and skip the page-template injection — `front-page.php`'s trailing loop already renders every layout (see the Hybrid overlay below). Error and exit if the project is not cinematic.
- **`--page <slug>`** = read the section from `demo/<slug>.html` instead of `demo/index.html` (optional, **default `index`** — existing behavior unchanged when omitted)
- **`--target <template>`** = inject the `get_template_part` call into `<template>` (e.g. `page-about.php`) instead of `front-page.php` (optional, **default `front-page.php`** — existing behavior unchanged when omitted)
- **`--transcribe` flag** = activate **faithful Transcription Mode** (optional). When set, the dispatched agents reproduce the demo's exact declared CSS/geometry instead of re-authoring fresh design-system styles. When omitted, behavior is unchanged (the current re-authoring / design-system path).
- **`--block <name>`** = the unique BEM block name to scope every generated selector under (optional; used with `--transcribe` so parallel section builds can never collide on a selector).
- **`--css <source>`** = the demo source the section is transcribed from (optional; required with `--transcribe`). What it means depends on the project's `Template:`, per the transcription overlay below:
  - `basic` → the section's **verbatim** demo CSS, and the SOURCE OF TRUTH for the transcription: an inline CSS blob or a path to a CSS file, whose declared values are copied exactly.
  - `tailwind` → the converted demo page itself (HTML, converted in place by `/wp-yolo` Step 2.6), and the SOURCE OF TRUTH exactly as the CSS blob is on `basic`: its utility classes and element structure are the declared values (Step 5's transcription overlay).

- **`--no-blog-page` flag** = skip Step 6.7 (`/wp-page blog` after a blog section)
- **`--defer-promotion` flag** = `tailwind` only. Skip the `wp-tailwind` author-mode dispatch (Step 5). Set by `/wp-yolo` on the section walk; `/wp-yolo` Step 4.4 then runs one promotion pass over every template part. Ignored on `basic`. Never set it by hand for a one-off section: no later pass would promote its utilities.

> **Note:** `/wp-yolo` sets `--transcribe --block <block> --css <css-source>` on every `/wp-section` dispatch, plus `--defer-promotion` on the `tailwind` path (see `commands/wp-yolo.md` Steps 4 and 4.4). When invoked by hand without these flags, `/wp-section` keeps its original design-system authoring behavior.

If no section name is provided and `--list` is absent, print an error:
```
Error: Section name is required.
Usage: /wp-section <section-name> [screenshot-path] [--cf7] [--hybrid] [--page <slug>] [--target <template>] [--transcribe] [--block <name>] [--css <source>] [--no-blog-page]
Example: /wp-section hero
         /wp-section --list
         /wp-section services /path/to/screenshot.png
         /wp-section contact --cf7
         /wp-section about-story --page about --target page-about.php
         /wp-section hero --transcribe --block home-hero --css demo/index.css
         /wp-section pricing --hybrid
```

## Step 2: Read Project Context

**First: validate the project configuration.**

`${PROJECT_PATH}` is not an environment variable the way `${CLAUDE_PLUGIN_ROOT}` beside it is: it is the WordPress project root, the directory holding `.wp-create.json`, and you substitute the real path yourself — the one the user named, or the working directory when they named none — because an empty argument makes the validator print its usage line and exit `1`, which the table below then reads as "stop and report". The path travels as a positional argument, never inside the `-c` string: write it in single quotes, and a path that holds a single quote gets each one written as `'\''`.

```bash
bash -c 'node "$1/bin/wp-config.mjs" validate "$2"' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

| Exit | Meaning | Do |
|---|---|---|
| `0` | valid | continue |
| `1` | invalid, or the generated context block disagrees with the manifest | stop and report the message verbatim |
| `2` | an older manifest can migrate | run `wp-config.mjs migrate '${PROJECT_PATH}'`, then continue |
| `3` | no manifest | this project was not created by `/wp-create`; stop and say so |

On exit 2, run the migration before continuing.

Read `.claude/CLAUDE.md` to extract:
- **Function prefix** (e.g., `kairo_`)
- **Theme slug**
- **Languages** (primary + secondary — needed for bilingual field variants)
- **Theme directory path**

### Hybrid overlay (`--hybrid`)

Read `Template:` from `.claude/CLAUDE.md`. If `--hybrid` is set and the template is not
`cinematic`, stop:
```
Error: --hybrid is only valid on a cinematic project (Template: cinematic). Use /wp-section <name> without it.
```
If the template is `cinematic`, `--hybrid` is **absent** and no `--target` was given, warn
once and continue as if it were set — the default target is `front-page.php`, and on the
cinematic starter that file renders the reel plus the trailing loop, not a `<main>` section
list, so a standalone section injected there would never render. An explicit `--target`
(e.g. `--target page-pricing.php`) is a normal inner page on a cinematic site and is built
the standard way; `--hybrid` is never implied over it.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-section-run/references/hybrid.md` now and follow it
when `--hybrid` is set or implied — it is this step, not background. It covers the four things
that change: the trailing flex layout, `get_sub_field()` in the template, the cinematic CSS file,
and the skipped injection.

## Step 3: Read Demo Section

**Stop if `demo/FAILED.md` exists.** Print its first ten lines and stop. Building
a theme from a demo that never passed verification produces a verified-looking
site on an unverified foundation, and every later audit measures the theme rather
than the demo it came from. The marker is cleared only by a craft verify loop
starting over (`/wp-demo iterate`, or a fresh craft run), which deletes it at its
top — so it always describes the last loop. Do not delete it by hand to get past
this gate.

Read the demo page for this section — `demo/<slug>.html` where `<slug>` is the `--page`
value (**default `index`**, i.e. `demo/index.html` when `--page` is omitted) — and extract
the section matching:
```
<!-- ============ SECTION: <Name> ============ -->
...
<!-- ============ END SECTION: <Name> ============ -->
```

The match should be case-insensitive on the section name. If the section is not found in the demo, warn the user but continue — ask them to describe the section content.

Analyze the extracted section for:
- All text content (headings, paragraphs, labels, CTAs)
- Images and their roles
- Repeating patterns (cards, list items, team members, etc.)
- Links and buttons
- Layout structure (grid, columns, etc.)

## Step 3.5: Detect Contact Section

Check if this is a contact section:
1. Section name matches `contact`, `contact-us`, `contacto`, or `get-in-touch` (case-insensitive)
2. OR the `--cf7` flag is present in `$ARGUMENTS`
3. OR the extracted demo HTML contains a `<form>` element with `<input type="email">` and `<textarea>`

If any condition is true, set `is_contact_section = true`. This changes the dispatch flow in Step 5.

## Step 4: Determine Target Page Template

The section will be included in a page template. Default is `front-page.php`. If `--target <template>` is provided, inject into that template instead (e.g. `page-about.php`). Everywhere below that names `front-page.php` refers to this resolved target template.

## Step 5: Dispatch Agents

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-section-run/references/dispatch-rules.md` now and follow it
— it is this step, not background. It covers the field naming convention every agent prompt
carries, the GEO citability rubric, the `--transcribe` overlay, which CSS agent the `Template:`
selects, and the one-writer-per-file ownership rule.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-section-run/references/non-contact.md` now and follow
it for a section that is not a contact section — it is this step, not background. It covers the
three agents, their order on `basic` and on `tailwind`, and each agent's prompt.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-section-run/references/contact.md` now and follow it
when `is_contact_section = true` — it is this step, not background. It covers the two-phase
dispatch, the CF7 form agent and the template agent's contact variant.

## Step 6: Add to Page Template

**Skip this step under `--hybrid`** — the trailing loop in `front-page.php` renders the layout.

After all agents complete, check if the resolved target page template (the `--target` value, default `front-page.php`) already includes this section:

```php
get_template_part('template-parts/section', '<name>');
```

If not present, add the `get_template_part()` call inside the `<main>` element, in a logical order relative to other sections.

If the page template does not exist yet, create it with `get_header()`, `<main>`, the `get_template_part()` call, `</main>`, and `get_footer()`.

## Step 6.4: Behaviour (`wp-js`)

A section whose demo has a script — a carousel, a gallery, tabs, an accordion, a filter, a
form check — is not built until the script is. Skip this step under `--transcribe` (the
`/wp-yolo` run ports every script once, in its behaviour-carry step), under `--hybrid`, and on a
`cinematic` theme. Otherwise find the scripts that touch the section. A hit in the page's
markup is not one — the section's own HTML always names its classes — so search scripts only:
the `.js` files, and the inline `<script>` blocks of the demo page, extracted first:

```bash
grep -rlE '<root-class>|<child-ids-or-data-attributes>' demo --include=*.js
sed -n '/<script\b/,/<\/script>/p' demo/<page>.html | grep -cE '<root-class>|<child-ids-or-data-attributes>'
```

None: skip, and say "no behaviour" in the summary. Some: dispatch **wp-js** with the slug,
the theme directory, the template part path, the section's CSS, the demo section's markup and
those scripts (a shared script whole: the agent ports only what acts on this section).
It writes `assets/js/src/sections/<slug>.js`, wires it into `index.js`, adds `data-` hooks to
the template part, and rebuilds the bundle. A `BLOCKED:` return (a library the theme does not
have, no `index.js`) goes into the summary verbatim with the files it touched; the section
is reported as built without its behaviour, never as finished. Its "CSS needed" lines go
into the summary too: the CSS agent's next pass owns them.

## Step 6.5: Rebuild Tailwind CSS

On `Template: tailwind` the site enqueues only the compiled `assets/css/dist/main.css`, so
the classes the agents just wrote are invisible until it is recompiled:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/tailwind-rebuild.sh" <theme-dir>
```

Silent no-op on a non-Tailwind theme; skips itself when the user has `npm run preview`
running (the watcher already owns `dist/`). Do this before the summary — a summary that
lists files no browser can see yet is not a finished section.

## Step 6.7: Blog templates

Applies only when the section slug is `blog`, `journal`, `news` or `posts`.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-section-run/references/blog-templates.md` now and follow it.

## Motion attribute assertion (craft mode only)

When `.wp-create.json` records `"demo mode": "craft"`, after writing the template
part, compare it against the demo section it came from: every `data-motion*`
attribute present in the demo must be present in the template part. A missing
attribute is a **build failure**, not a warning. Report the section, the attribute
and the demo line, and fix it before continuing.

## Step 7: Print Summary

The `[basic only]` / `[tailwind only]` markers below are report annotations, not literal
output: print the line that matches the project's `Template:` and drop the other. On
`tailwind` the section's styling lives in the template part's utility classes, so a CSS
file appears in the report only when the `wp-tailwind-system` ladder demanded an
`@apply` rule.

### For non-contact sections:
```
=== Section "<Name>" Built ===
Files created/updated:
  - fields/<section-name>.php (ACF field definitions)
  - template-parts/section-<name>.php (template part)
  - assets/css/styles.css (<Name> section CSS)                       [basic only]
  - components/<page-slug>.css or utilities/site.css (only if a rule was needed) [tailwind only]
  - <page-template>.php (added get_template_part call)
  - Blog templates: built by /wp-page blog | skipped (<reason>) [blog sections, Step 6.7]
  - Behaviour: assets/js/src/sections/<slug>.js (wp-js) | no behaviour | BLOCKED: <reason> [Step 6.4]

Fields registered:
  - <list of field names>

Next: Run /wp-section <next-section> for the next section.
```

### For contact sections:

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-section-run/references/summary-contact.md` now and follow
it when `is_contact_section = true` — it adds the CF7 files and the created form IDs.
