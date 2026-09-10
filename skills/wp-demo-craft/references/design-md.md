# demo/DESIGN.md

The visual truth of the build, in the open Stitch DESIGN.md format: YAML front
matter (`colors`, `typography`, `rounded`, `spacing`), then prose with a do and
don't list. `demo/BRIEF.md` carries the story; this file carries the tokens.
Write it before any markup — a demo whose palette is decided section by section
is a demo with several palettes.

## Assembly order, first source wins per field

1. **The client's own material.** Colours stated in the docs, the colours already
   in their logo, a typeface they have licensed or named. Nothing downstream
   overrides this.
2. **`npx designlang@12 <url>`** on the client's current site, then on each
   reference URL the docs name. Pinned to the major version — 12 is the current
   latest on the npm registry, checked rather than assumed — so a future major
   cannot change the flags or the output shape underneath this step, exactly as
   `impeccable@4` is pinned in `verify.md`. Take what the site declares. A site built on
   inline styles yields thin tokens; that is expected, and thin real tokens still
   beat invented ones.
3. **The catalogue.** Open `references/design-md/INDEX.md` — 64 real brands, one
   row each with industry, tone, display face and accent. Pick two or three rows
   by industry and tone, read **only those files**, and fill the remaining gaps
   from them. Cite the rows you used, by domain, in the file.
4. **Refero**, when Firecrawl is configured (`firecrawl_url` in
   `.wp-create.json`) and a named reference is a Refero Styles page: scrape it
   for its written direction and its do/don't list.

**The catalogue is vocabulary, never a copy source.** It exists so a build can
name what it is doing — this accent is a signal colour, this pairing is a
grotesque over a humanist serif — not so a build can wear another brand's
clothes. A client `DESIGN.md` whose palette and type pair match a catalogue entry
is a defect, and the fingerprint gate will catch the second client it happens to.

## Token mapping

The demo's `:root` is generated from this file onto the plugin's token names, so
every composition renders without edits:

`--color-canvas`, `--color-surface`, `--color-ink`, `--color-ink-soft`,
`--color-accent`, `--color-accent-ink`, `--color-hairline`, `--font-display`,
`--font-text`, `--space-section`, `--space-gutter`, `--container-max`,
`--radius-sm`, `--radius-md`.

`--container-max` is the content width, not the section width. Grounds stay
full-bleed and only the content inside them is constrained; without it every
composition pads by the gutter alone, so above about 1600px a heading sits hard
left and an aside hard right with a dead field between them.

Its value comes from the client material first and the nearest catalogue entry
second; when both are silent, **write `1280px`** — plain mode's content width, so
the two modes agree. Every composition also carries `1280px` as the `var()`
fallback, because an undefined `var()` makes `padding-inline` invalid at
computed-value time: it unsets rather than degrading, and a section with no
content width would render its body copy flush against a 390px screen edge. The
fallback is the floor, not the answer — a generated `:root` still writes the token.

A hardcoded hex in a section is a defect: the same value now exists in two
places, and the one in `:root` is the one `/wp-init` carries into the theme.
`/wp-init` reads this file before it reads the demo's `:root`.

**Derive scales in `oklch()`, record hex beside them.** Equal numeric steps in
oklch are equal perceptual steps, and holding lightness constant across hues
holds contrast, which is what makes a derived scale safe to generate rather than
hand-pick. A scale stepped in hex or HSL produces visible bright and dark spots
at the same numeric interval. `DESIGN.md` keeps the hex value as the recorded
token so nothing downstream breaks, and carries the oklch triple beside it.
