# DRAFT — Code Connect integration for claude-wp-builder

> Status: draft / proposal. Not implemented. Owner: Yojahny.

## The idea in one line

Map the client's Figma library components to this plugin's **canonical demo HTML snippets**
(BEM, section-delimited), so `get_design_context` returns markup `/wp-section` already knows
how to convert — instead of raw hex + absolute positions the model has to interpret.

## Why the demo layer, not PHP

Code Connect officially supports React, HTML (Web Components/Angular/Vue), SwiftUI and
Compose — **not PHP**. That's fine, because this plugin is demo-HTML-first anyway:

```
Figma ──▶ demo/index.html ──▶ /wp-section ──▶ ACF fields + template part + CSS
        (Code Connect          (existing SECTION-delimiter contract,
         plugs in HERE)         unchanged)
```

Everything downstream of `demo/` already works. The whole integration is: make the
Figma→demo step return our markup by mapping, not by reconstruction.

## Requirements (hard gates — check before starting)

1. **Figma Organization or Enterprise plan** — Code Connect publishing is plan-gated.
   Most of our clients hand us a Pro file: for them this is a no-op and the current
   figma-to-demo loop stays the path. Design the integration as optional.
2. **A published component library** in the client file (real components with props/variants,
   not loose frames). If the file doesn't have one, the prerequisite work is in Figma, not here.
3. Node + `@figma/code-connect` CLI, and a Figma access token with library read scope.

## Proposed layout

A new optional dir in the plugin (templates copied into the project by `/wp-init`):

```
figma/
  figma.config.json          # file URL, include globs
  components/
    button.figma.ts          # → canonical .btn / .btn--primary markup
    card.figma.ts            # → .card snippet with data-acf hints
    nav.figma.ts             # → header nav pattern from starter theme
    section-hero.figma.ts    # → full SECTION-delimited hero block
    ...
```

Each `.figma.ts` uses the **HTML client** and emits the snippet the rest of the plugin
expects — BEM classes from `wp-css-system`, plus ACF hints for `/wp-section`:

```ts
// card.figma.ts (sketch)
import figma, { html } from '@figma/code-connect/html'

figma.connect('https://www.figma.com/design/<file>?node-id=<card-component>', {
  props: {
    title: figma.string('Title'),
    body: figma.string('Body'),
    variant: figma.enum('Variant', { Default: 'card', Featured: 'card card--featured' }),
  },
  example: (p) => html`
    <article class="${p.variant}" data-acf="repeater-item">
      <h3 class="card__title" data-acf="text">${p.title}</h3>
      <p class="card__body" data-acf="textarea">${p.body}</p>
    </article>`,
})
```

`data-acf` is the only new contract: a hint `/wp-section` MAY read to pick the field type
instead of inferring it from content. Absent hint = current inference behavior, unchanged.

## What changes in the pipeline

| Piece | Change |
|---|---|
| `/wp-init` | New optional flag/question: "Figma library with Code Connect? (Org plan)" → copies `figma/` templates, records it in `.claude/CLAUDE.md`. |
| `/wp-demo` / figma-to-demo loop | When `get_design_context` returns a Code Connect snippet, **use it verbatim** (it's already our markup). Fall back to the current interpret-from-context path otherwise. This matches the hint priority already documented in figma-to-demo: Code Connect / docs → variables → raw hex. |
| `/wp-section` | Optionally read `data-acf` hints when present. No other change — the SECTION delimiter contract is untouched. |
| New (maybe) `/wp-figma-connect` | Generates `.figma.ts` stubs: reads the library components via MCP, matches them by name against `starter-theme/*/template-parts/components/` + the demo's BEM blocks, writes one file per component, runs `figma connect publish`. One-time per project. |

## First components to map (highest repetition = highest return)

Buttons, cards, nav/header, footer columns, form fields (CF7 markup), section headings.
Full sections (hero, testimonials) only after the atoms prove out — a section mapping breaks
whenever the designer restructures the frame; atoms are stable.

## Phasing

1. **Phase 0 — no code.** On the next Org-plan client, hand-write 3 mappings
   (button, card, nav), publish, and measure: tokens per section build + fidelity vs. the
   current loop. If the win isn't obvious, stop here.
2. **Phase 1.** `figma/` templates + the `/wp-init` question + the "use snippet verbatim"
   rule in the demo step.
3. **Phase 2.** `data-acf` hints in `/wp-section` and the `/wp-figma-connect` stub generator.

## Open questions

- How many of our clients are actually on Org/Enterprise? (If ~none, this whole doc is Phase 0
  forever — the figma-to-demo loop already covers Pro files.)
- Per-client libraries vs. one agency base library re-themed per client — the second makes the
  mappings reusable across projects, which is where the real payoff is.
- Layer-tree stability: mappings break when the designer restructures a mapped component.
  Needs a line in the client design-handoff checklist, not code.
