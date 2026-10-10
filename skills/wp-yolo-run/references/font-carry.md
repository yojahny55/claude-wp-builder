# /wp-yolo — Step 4.5

`commands/wp-yolo.md` sends the run here at Step 4.5. Follow it in order; nothing in it is optional background.

Before seeding, collect every `section.fonts[]` entry across the manifest (dedupe by
`family`+`weight`+`style`):

**An empty collection is checked, not believed.** `fonts: []` on every section means one
of two things, and they are not the same: a demo that genuinely uses a system stack, or a
manifest that missed what the demo loads. Grep the demo pages before concluding the first:

```bash
bash -c "grep -l 'fonts.googleapis.com\|@font-face' demo/*.html | head"
```

A hit means the manifest is wrong. Carry the families from the markup — the `css2` URL
names them and their weights — exactly as the recipe below does, and add one Review entry
naming the gap, because the next command to read that manifest will be misled the same way.
A build shipped a theme naming `"Inter", system-ui` over a demo rendering Archivo and
Source Sans 3, with an empty `assets/fonts/`, and nothing in the run said so: every step
after this one is conditioned on a non-empty list, so an empty one is not a warning, it is
silence.

- Copy each entry's `src` woff2 file(s) from the demo folder into `theme/assets/fonts/`.
  **When the file is not there.** Demos ship broken font paths as a matter of course —
  the rehearsal demo declares `src: url("assets/fonts/marcellus.woff2")` and carries no
  such file. Search the demo folder for the basename first (any subdirectory, matched
  case-insensitively). If it is genuinely absent, do **not** re-emit a `@font-face`
  whose `src` points at a file the theme does not have: that rule fails silently, and
  under `font-display: swap` the page renders the fallback stack with nothing logged
  anywhere to say why. Skip that family's `@font-face` rule entirely, drop the family
  name from the head of its font token so the theme stops naming a font it does not
  have, and add `font <family>: <src> not found in the demo folder — supply the woff2
  or the token keeps its fallback` to the Step 6 Review list. Keeping the name changes
  nothing at render time (a family with no face and no local install never rendered
  anyway) and leaves a token `/wp-finalize`'s font-parity check fails on: it passes a
  family with a face, or an intentional fallback stack, and nothing in between.
- Re-emit each `@font-face` rule with `src` rewritten to the theme-relative path
  (`assets/fonts/<file>.woff2`), and **place it by `Template:`**:
  - `basic` → enqueue the resulting stylesheet, or add the rule to the theme's existing
    fonts partial.
  - `tailwind` → write the rule into `assets/css/src/tailwindcss/base/fonts.css` and add
    its `@import` to `main.css` in the same step —
    `skills/wp-tailwind-system/SKILL.md` gives `base` the "resets and font-face" role,
    and its no-empty-file rule is why the rule and the import go in together.
    **Enqueue nothing.** A Tailwind theme has no fonts partial and enqueues exactly one
    stylesheet, the compiled `assets/css/dist/main.css`; a second enqueued stylesheet is
    the plain-CSS regression this template exists to remove, and
    `/wp-tailwind-migrate` Step 5 states the same rule — leave exactly one enqueue.

  Either way, every block's `transcribe`d CSS then resolves against a self-hosted font,
  not the demo's original path.
- **Never emit a `fonts.googleapis.com` request, preconnect included.** The theme self-hosts
  every family it names — a Google Fonts `<link>` in the demo is carried by downloading its
  woff2 into `assets/fonts/`, not by copying the link across. `/wp-init` Step 4.5 states that
  recipe (including the user-agent trap that silently yields TTF instead of woff2) and runs
  before this command; a preconnect to a host the theme never calls is a dead hint, which is
  what the starter used to ship. `section.fonts[]` families are self-hosted from the demo
  folder as above — self-hosted stays self-hosted, and linked fonts become self-hosted too.
