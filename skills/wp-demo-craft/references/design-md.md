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
2. **`npx designlang@12 <url>`** on the client's current site — the URL the docs
   name, **or `research.site` from `demo/RESEARCH.md` when `confidence` is
   `confirmed`** — then on each reference URL the docs name. Pinned to the major
   version — 12 is the current latest on the npm registry, checked rather than
   assumed — so a future major cannot change the flags or the output shape
   underneath this step, exactly as `impeccable@4` is pinned in `verify.md`. Take
   what the site declares. A site built on inline styles yields thin tokens;
   that is expected, and thin real tokens still beat invented ones.
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

## Motion mapping

The reference files describe how a site moves, and until now none of that reached
the build: the token mapping extracted colour, type and spacing, and the motion
vocabulary in 57 of the 67 catalogue entries was read by nobody. A demo therefore
took its palette from a reference and its motion from nowhere.

Two tokens carry it, and every composition's element animation consumes them:

| token | what it is | default when the reference is silent |
|---|---|---|
| `--ease-entry` | the easing an element arrives on | `cubic-bezier(.22,.61,.36,1)` |
| `--motion-rise` | how far an element travels as it arrives | `22px` |

Read them off the reference the same way the colour tokens are read. A site whose
motion is brisk and mechanical wants a shorter rise and a sharper curve; one whose
motion is soft and long wants the opposite. Two numbers are not the whole of a
site's motion identity, but they are the two that every entrance in the library
passes through, so getting them from the reference is the difference between a
demo that moves like its reference and one that moves like the default.

What the reference cannot give you is **which** elements move and in what order.
That is the composition's own choreography, written per element in its
`section.css` (`references/devices.md`, "How element animation is written"), and
it is a design decision rather than an extracted value.

Where a reference describes a motion the library has no device for — a hover that
lifts and shadows, a marquee, a cursor-following highlight — build it in the
composition's own CSS under the same contract. The refuse list constrains taste,
not technique.

## Token mapping

The demo's `:root` is generated from this file onto the plugin's token names, so
every composition renders without edits:

`--color-canvas`, `--color-surface`, `--color-ink`, `--color-ink-soft`,
`--color-accent`, `--color-accent-ink`, `--color-hairline`, `--font-display`,
`--font-text`, `--space-section`, `--space-gutter`, `--container-max`,
`--radius-sm`, `--radius-md`, `--ease-entry`, `--motion-rise`.

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

The `var()` fallback only ever covered an *absent* token. A present but
malformed one (`wide`, an empty string) still made `calc()` invalid at
computed-value time and unset `padding-inline` the same way. The build now
emits `@property --container-max { syntax: "<length>"; inherits: true;
initial-value: 1280px; }` alongside `:root`, so an invalid value falls back to
`initial-value` instead of unsetting — the `var()` fallback remains the only
guard where `@property` itself is unsupported.

A hardcoded hex in a section is a defect: the same value now exists in two
places, and the one in `:root` is the one `/wp-init` carries into the theme.
`/wp-init` reads this file before it reads the demo's `:root`.

**Derive scales in `oklch()`, record hex beside them.** Equal numeric steps in
oklch are equal perceptual steps, and holding lightness constant across hues
holds contrast, which is what makes a derived scale safe to generate rather than
hand-pick. A scale stepped in hex or HSL produces visible bright and dark spots
at the same numeric interval. `DESIGN.md` keeps the hex value as the recorded
token so nothing downstream breaks, and carries the oklch triple beside it.
