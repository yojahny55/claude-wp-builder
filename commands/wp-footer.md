---
description: Build the WordPress footer — pulling from settings page (logo, copyright, social, contact, legal)
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "[screenshot-path]"
---

# WP Footer — WordPress Footer Builder

Generate a WordPress footer that pulls all dynamic content from the theme settings/options page via ACF fields.

## Step 1: Read Project Context

Read `.claude/CLAUDE.md` to extract:
- **Function prefix** (e.g., `kairo_`)
- **Theme slug**
- **Languages** (primary + secondary)
- **Theme directory path**

If `.claude/CLAUDE.md` does not exist, tell the user to run `/wp-init` first.

## Step 2: Read Demo Footer

Read `demo/index.html` and extract the footer section (between `<!-- ============ SECTION: Footer ============ -->` delimiters, or the `<footer>` element).

Analyze:
- Number of columns and their content
- Logo presence and position
- Contact information (address, phone, email)
- Social media links
- Legal/policy links
- Copyright text
- Newsletter signup (if any)
- Footer navigation menu

## Step 3: Screenshot Reference (Optional)

If `$ARGUMENTS` provides a screenshot path, read the screenshot file for additional visual reference.

## Step 4: Dispatch wp-template Agent

Dispatch the **wp-template** agent with these instructions:

> Generate `footer.php` in the theme directory.
>
> The footer MUST pull ALL dynamic content from the settings/options page using the project's i18n helper functions. NEVER hardcode content.
>
> Required elements (include only those present in the demo):
>
> - **Footer logo**: `prefix_get_field('footer_logo', 'option')` with fallback to `prefix_get_field('site_logo', 'option')`
> - **Footer description/tagline**: `prefix_get_field('footer_description', 'option')`
> - **Contact info**:
>   - Phone: `prefix_get_field('contact_phone', 'option')`
>   - Email: `prefix_get_field('contact_email', 'option')`
>   - Address: `prefix_get_field('contact_address', 'option')`
> - **Social links** (repeater): `prefix_get_repeater('social_links', array('platform', 'url', 'icon'), 'option')`
>   Each icon link renders at least 24x24 at desktop and mobile (WCAG 2.2 AA 2.5.8). A
>   16px glyph gets padding plus the equal negative margin, so the row keeps the demo's
>   spacing and nothing moves: `tailwind` → `p-1 -m-1` on the `<a>`; `basic` →
>   `.footer__social-link { padding: 4px; margin: -4px; }`
> - **Legal links**: `prefix_get_field('legal_privacy_url', 'option')`, `prefix_get_field('legal_terms_url', 'option')`
> - **Copyright**: `prefix_get_field('footer_copyright', 'option')` with fallback to `© {year} {blogname}`
> - **Designer credit**: `prefix_get_field('footer_credit', 'option')` (optional)
> - **Footer navigation**: `wp_nav_menu()` with `'footer_' . prefix_current_lang()` location
>
> Close the file properly:
> ```php
>     <?php wp_footer(); ?>
> </body>
> </html>
> ```
>
> Class naming — include the line matching the project's `Template:` and drop the
> other. `footer.php` is yours on both paths; only the class system changes.
> - `basic` → BEM naming: `.footer__logo`, `.footer__contact`, `.footer__social`, etc.
> - `tailwind` → keep the Tailwind utility classes already on the demo footer you were
>   handed, element for element. Never replace them with BEM names and never invent new
>   class names: `wp-tailwind` runs after you and renames only the groups its promotion
>   ladder promotes. See "File ownership" under "CSS agent routing" below.
>
> All output must be escaped. Match the demo layout structure.

## Step 5: Dispatch wp-acf Agent — Add Footer Fields to Settings Page

Dispatch the **wp-acf** agent with these instructions:

> Read `fields/settings.php` and ADD any project-specific footer fields to the **Footer tab** that are needed based on the demo design.
>
> The starter theme already includes basic footer fields (footer logo, brand text, copyright). Based on the demo, you may need to add:
> - Footer tagline or description text
> - Footer CTA section (text + button)
> - Newsletter signup heading/description
> - Footer column headings
> - Google Calendar embed code
> - Any other footer element the client should be able to edit
>
> For each new field:
> 1. Add the primary language field after the existing Footer tab fields (before the Contact tab)
> 2. Add the bilingual `_es` variant in the Spanish Translations tab
> 3. Follow the existing naming convention: `field_settings_footer_<element>`
>
> All fields use `'option'` as post ID. Instructions on the secondary-language fields name the
> project's primary language and are written in it — "Leave empty to use the English version." on
> an English-primary project. See "Editor Language" in `agents/wp-acf.md`.

### CSS agent routing

Read `Template:` from `.claude/CLAUDE.md`. When `Template:` is `tailwind`, dispatch
`wp-tailwind`; when it is `basic`, dispatch `wp-css`.

- `basic` → dispatch `wp-css` exactly as described below.
- `tailwind` → dispatch `wp-tailwind` in **author** mode instead. The footer's
  `@apply` target is `layouts/footer.css`, created only if a rule is genuinely
  needed — a footer expressible in utilities produces no CSS file at all. The agent
  reads `skills/wp-tailwind-system/SKILL.md`. It must never write
  `assets/css/styles.css`.

Dispatch exactly one of the two, never both.

Every `tailwind` dispatch opens its quoted prompt with this line, verbatim:

> Mode: **author**

The quoted prompt it opens is the one under "The `tailwind` prompt body" below — **not**
Step 6's quoted prompt, which is the `basic` branch's and names `assets/css/styles.css`,
the one file the `tailwind` path must never write.

`agents/wp-tailwind.md` gates Section Authoring Mode on that line and on nothing else, so
the line is not decoration: omit it and the dispatched agent falls into Demo Conversion
Mode, reads the prompt as a demo-file conversion and writes a `.tmp` nobody asked for. A
bare `author` anywhere else in the prompt — in prose, or inside an input path like
`demo/author.html` — selects nothing, precisely so that an ordinary demo page named after
the word cannot flip the mode by accident.

This routing governs the "Dispatch **wp-css** agent" step below (Step 6, the footer CSS) —
that step marks its `tailwind` counterpart with `(routed — see "CSS agent routing" above)`
rather than repeating the block.

**Editing rule for this file.** `tests/checks/wp-commands-tailwind.sh` walks every
dispatch site by matching `Dispatch` and `**wp-css**` on one physical line, and accounts
for every other bolded `**wp-css**` in the file. So: keep `Dispatch` and `**wp-css**`
together on a single line at each dispatch site (never hard-wrap between them), and write
`wp-css` unbolded when you mean it in prose. The one place bolded prose is allowed is
inside this `### CSS agent routing` block — everything from this heading down to the next
heading at `###` or above is exempt, sub-headings and fenced examples included.

#### The `tailwind` prompt body

Dispatch `wp-tailwind` with the prompt below in place of Step 6, once Step 4's
`wp-template` agent has returned. It supplies all five inputs
`agents/wp-tailwind.md`'s Inputs table declares — the markup, the local `@apply` target,
the block name, the theme path and the function prefix. The footer is site chrome rather
than a page, so its local target is named with `--layout footer`, which selects
`layouts/footer.css`; `--page <slug>` is the other spelling of that same input and the two
are mutually exclusive. `layouts/` is one of the four sanctioned directories, and it is
absent from a fresh theme only because git cannot track an empty directory — creating it
alongside its first rule is licensed by `skills/wp-tailwind-system/SKILL.md`'s **File
layout** section.

**File ownership.** `wp-template` owns `footer.php` on both paths — it is the only agent
carrying the ACF, escaping and i18n contract (`prefix_get_field()`,
`prefix_get_repeater()`, `wp_nav_menu()`, `esc_html()` / `esc_url()` / `esc_attr()`,
`wp_footer()`), none of which `agents/wp-tailwind.md` describes. On `tailwind`,
`wp-template` keeps the Tailwind utility classes already on the demo footer it was handed
instead of inventing BEM names, and `wp-tailwind` runs **after** Step 4 returns — never
beside it — editing only class names in the file `wp-template` wrote. The invariant: the
footer never ships without its ACF wiring and escaping, and never ships on BEM class names
in a Tailwind theme.

> Mode: **author**
>
> Promote the site footer's repeated utility groups for this Tailwind theme.
>
> Read `skills/wp-tailwind-system/SKILL.md` before writing anything — it owns the
> decision ladder and the prohibition list.
>
> Context:
> - Layout: `--layout footer` (decides `layouts/footer.css`; no `--page` on this
>   dispatch — the footer is site chrome, not a page)
> - Block name: `--block <block>` (scopes every `@apply` class you create)
> - Theme path: `<theme path>`
> - Function prefix: `<prefix>`
> - Section HTML: `footer.php`, which the wp-template agent has already written and
>   which is quoted below, already carrying Tailwind utility classes.
>
> Requirements:
> 1. `footer.php` belongs to wp-template. Edit it in place; do not create it and do
>    not rewrite it. The only thing you change is class names. Leave every
>    `prefix_get_field()` and `prefix_get_repeater()` call, every `esc_html()` /
>    `esc_url()` / `esc_attr()` wrapper, every fallback and every PHP control
>    structure exactly as you found it.
> 2. Tailwind utility classes in the markup are the default. A footer expressible in
>    utilities produces no CSS file at all, and the file comes back unchanged.
> 3. A utility group repeated 3+ times, or on 2+ pages, becomes a semantic class via
>    `@apply` — `utilities/site.css` if it spans pages, `layouts/footer.css` if it is
>    local to the footer. The footer renders on every page, so read that condition
>    carefully: what belongs in `layouts/footer.css` is a group used only inside the
>    footer, however many pages the footer itself appears on. Grep the theme's other
>    `components/*.css`, `layouts/*.css` and `*.php` before choosing.
> 4. Name a class you write into `layouts/footer.css` `<block>__<element>`. Name one
>    you write into `utilities/site.css` `site__<element>` instead — it qualified for
>    that file precisely because it spans more than one block.
> 5. If `layouts/footer.css` does not exist, create it with its first rule already in
>    it and add its `@import` to `main.css` in the same step, in `base` → `components`
>    → `layouts` → `utilities` order, naming its cascade layer (`layer(components)` for
>    `layouts/footer.css`, `layer(utilities)` for `utilities/site.css`) — a bare
>    `@import` beats every Tailwind utility regardless of specificity. Never leave an
>    empty file.
> 6. Colors and fonts come from the `@theme` block as utilities (`bg-primary`,
>    `font-primary`). No `:root`, no hardcoded hex a token already covers.
> 7. Responsive via Tailwind prefixes (`md:`, `lg:`) — including the column stack. No
>    hand-written `@media`.
> 8. Never write `assets/css/styles.css`. Never emit a `<style>` block.
>
> Footer markup:
> ```php
> <paste footer.php here>
> ```

## Step 6: Dispatch the CSS Agent

**This step is the `basic` branch.** On `tailwind` it does not run at all: `wp-tailwind` in
author mode writes the footer's utilities into the markup and, only if a rule is genuinely
needed, into `layouts/footer.css`. Nothing on the `tailwind` path writes
`assets/css/styles.css`, `:root` custom properties, or BEM rules — so do not follow the
instructions below there.

Dispatch the **wp-css** agent (routed — see "CSS agent routing" above; on `tailwind`, dispatch `wp-tailwind` in author mode instead):

> Add footer CSS to `assets/css/styles.css`. Include:
>
> - Footer layout matching the demo (grid or flexbox columns)
> - Responsive: stack columns on mobile, side-by-side on desktop
> - Social links styling (inline list, icon sizing)
> - Contact info layout
> - Legal links (inline, separated)
> - Copyright bar (if separate from main footer)
> - Hover states for links
> - Use CSS custom properties from the design system
> - BEM naming convention
>
> Add the CSS within delimiter comments:
> ```css
> /* ============ FOOTER ============ */
> ...
> /* ============ END FOOTER ============ */
> ```

## Step 6.5: Rebuild Tailwind CSS

On `Template: tailwind` the site enqueues only the compiled `assets/css/dist/main.css`, so
the classes the agents just wrote are invisible until it is recompiled:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/tailwind-rebuild.sh" <theme-dir>
```

Silent no-op on a non-Tailwind theme; skips itself when the user has `npm run preview`
running (the watcher already owns `dist/`). Do this before the summary — a summary that
lists files no browser can see yet is not a finished section.

## Step 7: Print Summary

```
=== Footer Built ===
Files created/updated:
  - footer.php
  - assets/css/styles.css (footer CSS)          [basic only]
  - layouts/footer.css (only if a rule was needed) [tailwind only]
  - fields/settings.php (footer ACF fields in Footer tab)

Settings fields used:
  - footer_logo, footer_description
  - contact_phone, contact_email, contact_address
  - social_links (repeater)
  - legal_privacy_url, legal_terms_url
  - footer_copyright, footer_credit

Next: Run /wp-section <name> to build content sections.
```
