# /wp-header — Step 4

`commands/wp-header.md` sends the run here at Step 4, after the `wp-template` agent returns. Follow it in order; nothing in it is optional background.

## Contents

- CSS agent routing by `Template:`
- The `tailwind` prompt body (author mode)
- File ownership

### CSS agent routing

Read `Template:` from `.claude/CLAUDE.md`. When `Template:` is `tailwind`, dispatch
`wp-tailwind`; when it is `basic`, dispatch `wp-css`.

- `basic` → dispatch `wp-css` exactly as described below.
- `tailwind` → dispatch `wp-tailwind` in **author** mode instead. The header's
  `@apply` target is `layouts/header.css`, created only if a rule is genuinely
  needed — a nav expressible in utilities produces no CSS file at all. The agent
  reads `skills/wp-tailwind-system/SKILL.md`. It must never write
  `assets/css/styles.css`.
- `cinematic` → not routed by this command. Cinematic projects are built by
  the `/wp-cinematic-*` family (`/wp-init` Step 0.5 dispatches
  `/wp-cinematic-init`), and their CSS is `assets/css/cinematic.css` — not
  `styles.css` and not the Tailwind tree. Dispatch no CSS agent here.

Dispatch exactly one of the two, never both.

Every `tailwind` dispatch opens its quoted prompt with this line, verbatim:

> Mode: **author**

The quoted prompt it opens is the one under "The `tailwind` prompt body" below — **not**
Step 5's quoted prompt, which is the `basic` branch's and names `assets/css/styles.css`,
the one file the `tailwind` path must never write.

`agents/wp-tailwind.md` gates Section Authoring Mode on that line and on nothing else, so
the line is not decoration: omit it and the dispatched agent falls into Demo Conversion
Mode, reads the prompt as a demo-file conversion and writes a `.tmp` nobody asked for. A
bare `author` anywhere else in the prompt — in prose, or inside an input path like
`demo/author.html` — selects nothing, precisely so that an ordinary demo page named after
the word cannot flip the mode by accident.

This routing governs the "Dispatch **wp-css** agent" step below (Step 5, the header and
navigation CSS) — that step marks its `tailwind` counterpart with `(routed — see "CSS agent
routing" above)` rather than repeating the block.

**Editing rule for this file.** `tests/checks/wp-commands-tailwind.sh` walks every
dispatch site by matching `Dispatch` and `**wp-css**` on one physical line, and accounts
for every other bolded `**wp-css**` in the file. So: keep `Dispatch` and `**wp-css**`
together on a single line at each dispatch site (never hard-wrap between them), and write
`wp-css` unbolded when you mean it in prose. The one place bolded prose is allowed is
inside this `### CSS agent routing` block — everything from this heading down to the next
heading at `###` or above is exempt, sub-headings and fenced examples included.

#### The `tailwind` prompt body

Dispatch `wp-tailwind` with the prompt below in place of Step 5, once Step 4's
`wp-template` agent has returned. It supplies all five inputs
`agents/wp-tailwind.md`'s Inputs table declares — the markup, the local `@apply` target,
the block name, the theme path and the function prefix. The header is site chrome rather
than a page, so its local target is named with `--layout header`, which selects
`layouts/header.css`; `--page <slug>` is the other spelling of that same input and the two
are mutually exclusive. `layouts/` is one of the four sanctioned directories, and it is
absent from a fresh theme only because git cannot track an empty directory — creating it
alongside its first rule is licensed by `skills/wp-tailwind-system/SKILL.md`'s **File
layout** section.

**File ownership.** `wp-template` owns `header.php` and `inc/nav-walker.php` on both
paths — it is the only agent carrying the ACF, escaping and i18n contract
(`prefix_get_field()`, `wp_nav_menu()`, `esc_html()` / `esc_url()` / `esc_attr()`,
`wp_head()`), none of which `agents/wp-tailwind.md` describes. On `tailwind`,
`wp-template` keeps the Tailwind utility classes already on the demo header it was handed
instead of inventing BEM names, and `wp-tailwind` runs **after** Step 4 returns — never
beside it — editing only class names in the files `wp-template` wrote. The invariant: the
header never ships without its ACF wiring and escaping, and never ships on BEM class names
in a Tailwind theme.

> Mode: **author**
>
> Promote the site header's repeated utility groups for this Tailwind theme.
>
> Read `skills/wp-tailwind-system/SKILL.md` before writing anything — it owns the
> decision ladder and the prohibition list.
>
> Context:
> - Layout: `--layout header` (decides `layouts/header.css`; no `--page` on this
>   dispatch — the header is site chrome, not a page)
> - Block name: `--block <block>` (scopes every `@apply` class you create)
> - Theme path: `<theme path>`
> - Function prefix: `<prefix>`
> - Section HTML: `header.php` and `inc/nav-walker.php`, which the wp-template agent
>   has already written and which are quoted below, already carrying Tailwind utility
>   classes.
>
> Requirements:
> 1. Those two files belong to wp-template. Edit them in place; do not create them and
>    do not rewrite them. The only thing you change is class names. Leave every
>    `prefix_get_field()` call, every `esc_html()` / `esc_url()` / `esc_attr()`
>    wrapper, every `wp_nav_menu()` argument and every PHP control structure exactly
>    as you found it.
> 2. Tailwind utility classes in the markup are the default. A nav expressible in
>    utilities produces no CSS file at all, and the files come back unchanged.
> 3. A utility group repeated 3+ times, or on 2+ pages, becomes a semantic class via
>    `@apply` — `utilities/site.css` if it spans pages, `layouts/header.css` if it is
>    local to the header. The header renders on every page, so read that condition
>    carefully: what belongs in `layouts/header.css` is a group used only inside the
>    header, however many pages the header itself appears on. Grep the theme's other
>    `components/*.css`, `layouts/*.css` and `*.php` before choosing.
> 4. Name a class you write into `layouts/header.css` `<block>__<element>`. Name one
>    you write into `utilities/site.css` `site__<element>` instead — it qualified for
>    that file precisely because it spans more than one block.
> 5. If `layouts/header.css` does not exist, create it with its first rule already in
>    it and add its `@import` to `main.css` in the same step, in `base` → `components`
>    → `layouts` → `utilities` order, naming its cascade layer (`layer(components)` for
>    `layouts/header.css`, `layer(utilities)` for `utilities/site.css`) — a bare
>    `@import` beats every Tailwind utility regardless of specificity. Never leave an
>    empty file.
> 6. Colors and fonts come from the `@theme` block as utilities (`bg-primary`,
>    `font-primary`). No `:root`, no hardcoded hex a token already covers.
> 7. Responsive via Tailwind prefixes (`md:`, `lg:`) — including the hamburger
>    collapse. No hand-written `@media`.
> 8. Never write `assets/css/styles.css`. Never emit a `<style>` block.
>
> Header markup:
> ```php
> <paste header.php and inc/nav-walker.php here>
> ```
