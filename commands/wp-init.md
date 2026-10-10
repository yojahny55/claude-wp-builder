---
description: Scaffold a new WordPress project — copies starter theme, replaces placeholders, generates .claude/CLAUDE.md
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[project-name]"
---

# WP Init — Project Scaffolding

Scaffold a new WordPress project from the starter theme, configure i18n, and generate the project CLAUDE.md.

## Step 0.5: Select Starter Template

Ask the user to choose a starter template:

> **Select a starter template:**
> 1. **Tailwind Starter** — Tailwind CSS 4 + WordPress Scripts build pipeline, BrowserSync
> 2. **Cinematic Starter** — Scroll-driven cinematic reel (persistent video stage, scene scrub on desktop, autoplay-loop on mobile). Requires the [cinematic-scroll-kit](https://github.com/yojahny55/cinematic-scroll-kit) skill.

Store the selection as `$TEMPLATE`:
- Option 1 → `tailwind`
- Option 2 → `cinematic`

Default: `tailwind` (if user presses Enter without selecting).

There is no "Basic Starter" any more. `starter-theme/__starter__/` was removed
in 3600552 as superseded by the Tailwind template, but this command kept
offering it as option 1 AND as the Enter-key default — so the most likely path
through `/wp-init` copied a directory that does not exist. Treat `basic` as an
alias for `tailwind` if a caller still passes `--template=basic`, rather than
failing on it.

### If `$TEMPLATE = cinematic`

This branch follows a different scaffolding shape — the page is one continuous reel, not discrete sections. After Step 0.6, dispatch to `/wp-cinematic-init` for the cinematic-specific flow:

1. Resolve `cinematic-scroll-kit` (globally-installed skill → `./.cinematic-kit/` → vendored fallback in `starter-theme/__cinematic__/assets/cinematic-kit/`).
2. If none present, offer: `npx skills add yojahny55/cinematic-scroll-kit -g -y` (recommended). Decline → use vendored fallback.
3. Copy `starter-theme/__cinematic__/` as the theme.
4. Run the `wp-cinematic` agent against `schemas/scene.json` to generate `fields/scenes.php`, `fields/trailing-sections.php` (if hybrid), `inc/seed-cinematic.php`, and per-scene template fragments.
5. Skip the per-section `/wp-section` loop. Author scenes via `/wp-cinematic-scene <n>` and append trailing flex sections via `/wp-section <name> --hybrid` if hybrid mode is on.
6. Seed with `/wp-cinematic-seed` (uses kit sample videos).

Hybrid mode is **on by default** for cinematic — pass `--no-hybrid` to disable trailing sections.

## Step 0.6: Select Custom Fields Plugin

Ask the user to choose a custom fields plugin:

> **Select custom fields plugin:**
> 1. **SCF** (Secure Custom Fields) — Free, community fork
> 2. **ACF Pro** — Premium, requires license

Store the selection as `$CF_PLUGIN`:
- Option 1 → `scf`
- Option 2 → `acf`

Default: `scf` (if user presses Enter without selecting).

## Step 0.7: Select i18n Strategy

Ask the user how the site should handle its languages:

> **Select translation strategy:**
> 1. **Polylang** — one page per language at its own `/es/` URL, joined by translation
>    groups. Indexable, with per-language titles, meta and hreflang. Installs the
>    Polylang plugin. **Required if the second language has to rank in search.**
> 2. **Field suffixes** — one page per site, ACF/SCF fields duplicated as `_es`, language
>    picked by `?lang=`/cookie. No extra plugin, and **no SEO value for the second
>    language.** Choose it only when search traffic in that language does not matter.

Store the selection as `$I18N`:
- Option 1 → `polylang`
- Option 2 → `suffix`

Default: `polylang` (if the user presses Enter without selecting).

The default is deliberate, and it is an SEO decision. Under `suffix` a single URL
serves both languages off a query param, a cookie and `Accept-Language` — crawlers
send no cookie, so they only ever see the primary language; `?lang=es` canonicalizes
back to the primary URL; there is no hreflang pair because there is only one post; and
titles, meta descriptions and schema are per-post, so Rank Math has nowhere to store a
translated snippet. None of that is patchable inside the suffix model. Offer `suffix`
as the toggle it is — a language switch for a site whose second language does not need
to be found — never as the way to build a bilingual site that has to rank.

Existing projects are untouched: the strategy is read from the project's
`.claude/CLAUDE.md`, and a project whose `i18n strategy` line is absent stays `suffix`.
This default governs new scaffolds only.

Skip this question entirely when `$ARGUMENTS` contains `--i18n=suffix` or
`--i18n=polylang`, so `/wp-yolo` and other non-interactive callers can pass it
straight through.

## Pre-Step: Check for `.wp-create.json` Manifest

**First: validate the project configuration.**

`${PROJECT_PATH}` is not an environment variable the way `${CLAUDE_PLUGIN_ROOT}` beside it is: it is the WordPress project root, the directory holding `.wp-create.json`, and you substitute the real path yourself — the one the user named, or the working directory when they named none — because an empty argument makes the validator print its usage line and exit `1`, which the table below then reads as "stop and report".

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs validate '${PROJECT_PATH}'"
```

| Exit | Meaning | Do |
|---|---|---|
| `0` | valid | continue |
| `1` | invalid, or the generated context block disagrees with the manifest | stop and report the message verbatim |
| `2` | an older manifest can migrate | run `wp-config.mjs migrate '${PROJECT_PATH}'`, then continue |
| `3` | no manifest | this project was not created by `/wp-create`; stop and say so |

On exit 2, run the migration before continuing.

**Amending the exit `3` row above:** Exit `3` is not a stop here: this command also scaffolds a theme onto a WordPress
install that was never run through `/wp-create`, and the "If `.wp-create.json` does NOT
exist" branch below is that legitimate path. Treat exit `3` as "no manifest to read
config from" and fall through to that branch instead of aborting.

Before anything else, check if `.wp-create.json` exists in the current working directory or parent directories (same search pattern as `wp-content/themes/`).

### If `.wp-create.json` exists:

Read the manifest and extract:
- `project.name` → use as project name (skip asking in Step 1)
- `project.slug` → use as theme slug
- `languages.primary` → use as primary language
- `languages.additional` → use as secondary language(s)
- `wp_cli.wrapper` → use for WP-CLI commands instead of bare `wp`
- `project.domain` → use for site URL references

**Skip Step 1 entirely** — all project details come from the manifest, with one exception: the
manifest carries no tagline. Take it from the demo when the Demo-First Path runs, and otherwise
ask Step 1's **Tagline** question on its own. Skipping it leaves Step 9 writing an empty site
description, which is the state `/wp-finalize` fails on.

### If `.wp-create.json` does NOT exist:

Proceed with the normal flow (Step 0 → Step 1 → ...). No changes to existing behavior.

## Step 0: Check for Existing Demo

**Stop if `demo/FAILED.md` exists.** Print its first ten lines and stop. Building
a theme from a demo that never passed verification produces a verified-looking
site on an unverified foundation, and every later audit measures the theme rather
than the demo it came from. The marker is cleared only by a craft verify loop
starting over (`/wp-demo iterate`, or a fresh craft run), which deletes it at its
top — so it always describes the last loop. Do not delete it by hand to get past
this gate.

Before asking any project questions, check if a demo already exists.

### If `$ARGUMENTS` looks like a file path (ends in `.html` or `.htm`):

1. Copy the file to `demo/index.html` (create `demo/` directory if needed).
2. Proceed to the **Demo-First Path** below — skip the confirmation prompt since the user's intent is clear.
3. If both `demo/index.html` already exists AND a path argument is given, the path argument takes priority (copies over the existing demo).

### If `$ARGUMENTS` is NOT a file path (or is empty):

1. Check if `demo/index.html` exists in the current working directory.
2. If found, ask the user:
   > "I found an existing demo at `demo/index.html`. Would you like to use it as the basis for this project? (Y/n)"
3. If the user confirms, proceed to the **Demo-First Path**.
4. If the user declines or no demo exists, proceed to **Step 1: Gather Project Details** (the normal flow).

### Demo-First Path

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-init-run/references/demo-first.md` now and follow
it — it is this path, not background. It covers the delimiter check (D1), the project
details read from the demo (D2), their confirmation (D3), the colours and fonts written into
the theme with the craft token aliases and the `/wp-tailwindify` decision (D4), and the
return to Step 2 (D5).

## Step 1: Gather Project Details

If `$ARGUMENTS` is provided, use it as the project name. Then prompt the user for any missing details:

- **Project name** (display name, e.g., "Kairo Consulting")
- **Theme slug** (lowercase-hyphenated, e.g., "kairo-consulting") — suggest one derived from the project name
- **Primary language** (default: `en`)
- **Secondary language(s)** (default: `es`, comma-separated if multiple)
- **Client industry** (e.g., "consulting", "restaurant", "healthcare")
- **Tagline** (one sentence describing the site) — this is both the `Description:` line in
  `.claude/CLAUDE.md` and the WordPress site description written in Step 9. Never accept an
  empty answer here: an unset tagline leaves WordPress showing "Just another WordPress site"
  in the `<title>`, in feeds and in every SEO preview, and `/wp-finalize`'s Layer 2 gate fails
  on it. If the user has nothing, propose one from the industry and project name and confirm it.

If `$ARGUMENTS` was the project name, still ask for the remaining fields.

## Step 2: Locate wp-content/themes/

Search for the `wp-content/themes/` directory:

1. Check if `./wp-content/themes/` exists in the current working directory
2. Check if `../wp-content/themes/` exists (parent directory)
3. Check if `../../wp-content/themes/` exists (grandparent)
4. If not found, ask the user for the WordPress root path

Store the full path to `wp-content/themes/` for later use.

## Step 3: Copy Starter Theme

Copy the selected starter theme to the new theme directory:

- If `$TEMPLATE` is `tailwind` (or the legacy alias `basic`):
  ```
  cp -r ${CLAUDE_PLUGIN_ROOT}/starter-theme/__tailwind__/ <themes-dir>/<slug>/
  ```

- If `$TEMPLATE` is `cinematic`:
  ```
  cp -r ${CLAUDE_PLUGIN_ROOT}/starter-theme/__cinematic__/ <themes-dir>/<slug>/
  ```

Where `<slug>` is the theme slug from Step 1.

Only the two directories above exist. Copying anything else — `__starter__` in
particular — silently produces an empty theme directory, because `cp -r` on a
missing source fails while the rest of the flow carries on.

When `demo/DESIGN.md` exists, copy it to `<theme-dir>/DESIGN.md`. Later agents
(`wp-css`, `wp-section`) read it for the token vocabulary; it is the same file the
demo was built from. Append the Step D4 alias table under a `## Token aliases`
heading at the end — that is the only edit the copy gets, so the front matter the
demo was generated from stays byte-identical.

## Step 3.5: Wire Motion for the Recorded Demo Mode

Read `demo mode` from `.wp-create.json` (written by `/wp-demo` or `/wp-yolo`). Applies
to the Tailwind template only (the cinematic template has its own motion engine).

The engine has two halves — `assets/js/src/motion.js` and
`assets/css/src/tailwindcss/utilities/motion.css` — and both are wired or neither is.

- **craft**: keep `motion.js`, the `@import "./utilities/motion.css";` line in
  `assets/css/src/tailwindcss/main.css`, the GSAP import in `assets/js/src/index.js`,
  and the `gsap` dependency in `package.json` as copied. If the demo has a
  `<script id="signature">` block, lift its contents into `assets/js/signature.js` and
  enqueue it after the main bundle.
- **plain**: delete `assets/js/src/motion.js` **and**
  `assets/css/src/tailwindcss/utilities/motion.css`, remove the
  `@import "./utilities/motion.css";` line from `main.css`, remove the GSAP import from
  `assets/js/src/index.js` and the `gsap` dependency from `package.json`, and note in
  the summary that `wp-aos-animator` is the animation route for this project. Leaving
  the stylesheet behind ships a `reveal` ruleset no plain build ever triggers — plain
  demos emit no `data-motion` markup — which is dead CSS the step exists to remove.
- If `demo mode` is absent (no `/wp-demo` or `/wp-yolo` run yet), treat it as
  **plain**, the same as an explicit `"demo mode": "plain"`: delete `motion.js` and
  `utilities/motion.css` with its `main.css` import, remove the GSAP import and the
  `gsap` dependency, and note `wp-aos-animator` as the animation route. This mirrors the `i18n strategy` precedent: when the line
  is absent, the project ships the default rather than an invented third state.

## Step 4: Replace All Placeholders

Recursively replace placeholders in ALL files within the new theme directory:

1. `__starter__` → theme slug (e.g., `kairo-consulting`)
2. `__STARTER__` → theme slug uppercase with underscores (e.g., `KAIRO_CONSULTING`)
3. `__STARTER_NAME__` → project display name (e.g., `Kairo Consulting`)
4. `__STARTER_DOMAIN__` → site domain from `.wp-create.json` manifest `project.domain`, or `<slug>.local` if no manifest (Tailwind template only — present in `package.json`)

Use `find` + `sed` or equivalent to do this across all files (`.php`, `.css`, `.js`, `.json`, etc.).

## Step 4.5: Font carry

Step D4 wrote the demo's font *names* into `--font-primary` / `--font-secondary`. A name is
not a font: unless the family is actually loaded the browser silently renders the next entry
in the stack, which is why a converted theme looks "almost right" and nobody can say what
changed. **The theme self-hosts every family it names.** Run this step whenever a demo exists;
with no demo, skip it — the starter's tokens are a system stack that needs no loading, and
naming a family you did not carry is the defect this step exists to remove.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-init-run/references/font-carry.md` now and follow
it — it is this step, not background. It covers carrying a self-hosted or a Google Fonts
family into `<theme-dir>/assets/fonts/`, `font-display: swap`, the one preload, and what
to do when a font will not download.

## Step 5: Configure i18n

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-init-run/references/i18n.md` now and follow it
— it is this step, not background. It covers the Polylang variant of `inc/i18n.php`,
`SUPPORTED_LANGS` and `DEFAULT_LANG`, and the field-suffix rewrite that is mandatory when
the secondary language is not `es`.

## Step 6: Configure Theme Setup

Edit the theme's `register_nav_menus()` call — in `inc/theme-setup.php` on
`tailwind`, in `functions.php` on `cinematic` (that starter has no
`inc/theme-setup.php`).

Templates never build a location name. They call `<prefix>nav_location('primary')`
and `<prefix>nav_location('footer')`, which the `inc/i18n.php` installed in Step 5
answers for its strategy: `primary-<lang>` from the suffix helper, the bare
`primary` from the Polylang variant. So the registration below is the only half
that changes per strategy, and it has to match that answer exactly — a location
the helper asks for and nothing registers renders no menu at all, with no error
(`fallback_cb` is `false`).

### If `$I18N = polylang` (default)

Replace the starter's per-language entries with each location registered ONCE,
with no language suffix:

- `'primary' => 'Primary Navigation'`
- `'footer' => 'Footer Navigation'`

Polylang gives every registered location a per-language slot of its own and
swaps the right menu in at render time. Keeping `primary-en` and `primary-es`
as well would produce two competing systems for the same nav, and
`pll-verify.php` fails each of them for having no menu in the other language.

On `tailwind`, also register the theme's static strings so a client can edit
them under **Languages > Strings** instead of in code (the cinematic starter has
no `<prefix>get_translations()`; its literals are `<prefix>b()` pairs):

```php
add_action( 'init', function () {
    if ( ! function_exists( 'pll_register_string' ) ) {
        return;
    }
    foreach ( <prefix>get_translations() as $key => $values ) {
        pll_register_string( $key, $values['<primary_lang>'], '<Theme Name>' );
    }
} );
```

### If `$I18N = suffix`

- Keep the starter's per-language locations, named `<location>-<lang>` with a
  **hyphen** — the name the suffix `<prefix>nav_location()` builds. The starter
  ships them for `en` and `es`; make the list match the project's languages —
  one `primary-` and one `footer-` entry per language:
  - `'primary-en' => 'Primary Navigation (EN)'`
  - `'primary-es' => 'Primary Navigation (ES)'`
  - `'footer-en' => 'Footer Navigation (EN)'`
  - `'footer-es' => 'Footer Navigation (ES)'`

## Step 7: Generate .claude/CLAUDE.md

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-init-run/references/claude-md.md` now and follow
it — it is this step, not background. It covers the `.claude/CLAUDE.md` written at the
project root, the `## WP-CLI` section a manifest adds, and the `## Demo` section and
workflow line of a demo-first project.

## Step 8: Gather project docs (if present)

Check if a docs folder exists in the project root. If docs directory exists, run `/wp-context` to extract project
constraints and the scope manifest now (so every later command — especially `/wp-yolo` —
builds with the client's approved scope, integrations like IDX, and constraints in context).
If there is no `docs/` folder, skip this step silently.

## Step 9: Activate Theme and Install Dependencies

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-init-run/references/activate.md` now and follow
it — it is this step, not background. It covers the custom fields plugin, the Polylang
install and its languages, theme activation, the site identity (`blogname` and
`blogdescription`), and the Tailwind build.

## Step 9.5: Initialize git repository

The theme directory is the versioned deliverable and `/wp-yolo` requires a git repo
(for a rollback baseline and worktree-based isolation). Initialize one if absent:

```bash
cd <theme-dir>
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  git init -q
  printf 'node_modules/\n.DS_Store\n*.log\n' > .gitignore
  # Tailwind build output is regenerable — ignore dist if this is the tailwind template
  git add -A && git commit -q -m "chore: scaffold <slug> theme from starter"
}
```

Idempotent: if `<theme-dir>` is already inside a git work tree (e.g. the whole
site is versioned), skip init and leave the existing repo untouched.

## Step 9.6: Gitignore the local credentials file

`/wp-create` writes database and admin credentials to
`${PROJECT_PATH}/.wp-create.local.json` — a sibling of `.wp-create.json` at the
**project root**, not a file inside `<theme-dir>`. This is a different location
from Step 9.5 above: that step's `.gitignore` belongs to the theme's own git
repository, rooted at `<theme-dir>` (below `${PROJECT_PATH}`), and a repository
cannot ignore a path that lives outside it. If the project root is itself a
versioned repository — the whole site, not just the theme, which is a normal
delivery pattern — the credentials file needs its own ignore entry there:

```bash
cd ${PROJECT_PATH}
if ! grep -qxF '.wp-create.local.json' .gitignore 2>/dev/null; then
  [ -s .gitignore ] && [ -n "$(tail -c1 .gitignore)" ] && printf '\n' >> .gitignore
  printf '.wp-create.local.json\n' >> .gitignore
fi
```

`printf ... >>` creates `${PROJECT_PATH}/.gitignore` if it does not already
exist, and the `grep -qxF` guard makes the append idempotent on a re-run. The
`tail -c1` line is what makes the append safe on a pre-existing `.gitignore`
whose last line has no trailing newline: appending straight onto it produces
`*.log.wp-create.local.json`, a pattern that ignores neither, and the next
`git add -A` commits the database and admin passwords. Do this unconditionally,
whether or not `${PROJECT_PATH}` is a git repository yet — the entry costs
nothing when it isn't one, and protects the secret the moment it becomes one.

**Validation:** if `${PROJECT_PATH}` is inside a git work tree, `git
check-ignore -v .wp-create.local.json` (run from `${PROJECT_PATH}`) matches
the line just added. **On failure:** stop — do not continue to Step 10. Print
the last line of `${PROJECT_PATH}/.gitignore` and tell the user that
`.wp-create.local.json` holds the database and admin passwords, is not
ignored, and must not be committed until it is.

## Step 10: Print Summary

Print a summary:

```
=== Project Initialized ===
Project:    <Project Name>
Theme:      <themes-dir>/<slug>/
Template:   <Tailwind Starter|Cinematic Starter>
CF Plugin:  <SCF|ACF Pro>
Slug:       <slug>
Prefix:     <prefix>
Languages:  <primary> + <secondary>
CLAUDE.md:  <path-to-claude-md>

Next step: Run /wp-demo to create a demo mockup.
```

If `$TEMPLATE` is `tailwind`, add after "Next step":
```
Live view:  In a second terminal, `cd <theme-dir> && npm run preview` and keep it running.
            It recompiles CSS/JS on every file the builders write and reloads the browser
            through BrowserSync (http://localhost:3000, proxying <domain>). Without it,
            each builder recompiles once when it finishes; reload manually.
```

**If this is a demo-first project**, adjust the summary:

```
=== Project Initialized (from existing demo) ===
Project:    <Project Name>
Theme:      <themes-dir>/<slug>/
Template:   <Tailwind Starter|Cinematic Starter>
CF Plugin:  <SCF|ACF Pro>
Slug:       <slug>
Prefix:     <prefix>
Languages:  <primary> + <secondary>
Sections:   <detected sections>
CLAUDE.md:  <path-to-claude-md>
Demo:       demo/index.html (pre-polish copy at demo/.prepolish/index.html)

Next step: Run /wp-header to build the site header.
```
