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
2. **`npx designlang <url>`** on the client's current site, then on each
   reference URL the docs name. Take what the site declares. A site built on
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
`--font-text`, `--space-section`, `--space-gutter`, `--radius-sm`, `--radius-md`.

A hardcoded hex in a section is a defect: the same value now exists in two
places, and the one in `:root` is the one `/wp-init` carries into the theme.
`/wp-init` reads this file before it reads the demo's `:root`.
