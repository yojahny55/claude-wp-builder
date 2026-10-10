# /wp-init — Step 0

`commands/wp-init.md` sends the run here at Step 0 (Demo-First Path). Follow it in order; nothing in it is optional background.

## Contents

- Step D1 — Delimiter check
- Step D2 — Extract project info from demo
- Step D3 — Present pre-filled defaults
- Step D4 — Inject colors/fonts into theme: the craft vocabulary and its aliases, `@theme static`, the `--container-max` guard, and whether to run `/wp-tailwindify`
- Step D5 — Continue with normal scaffolding

**Step D1 — Delimiter check:**
- Read `demo/index.html` and scan for `<!-- ============ SECTION:` delimiters.
- If NO delimiters are found, inform the user:
  > "This demo doesn't have section delimiters. Running /wp-polish to prepare it..."
- Run the `/wp-polish` command on `demo/index.html`, then re-read the polished file.
- If SOME delimiters exist but sections appear to be missing them, also run `/wp-polish`.

**Step D2 — Extract project info from demo:**

Parse the demo HTML and extract as much as possible:

| Field | How to extract |
|-------|---------------|
| Project name | `<title>` tag content (remove suffixes like " — Home", " \| Homepage"). Fall back to `<h1>` content, then folder name. |
| Slug | Slugify the project name (lowercase, hyphens for spaces, strip special chars). |
| Industry | Analyze headings and body text for industry keywords. Examples: "patients"/"medical" → healthcare, "cases"/"legal" → law, "menu"/"dishes" → restaurant, "portfolio"/"design" → creative. If uncertain, set to "general". |
| Primary language | Read the `<html lang="">` attribute. Fall back to content language detection. Default: `en`. |
| Secondary language | Look for `lang=""` attributes on sub-elements, or content in a second language. Default: `es`. |
| Tagline | `<meta name="description">` content. Fall back to the hero subtitle (the `<p>` next to the hero `<h1>`), then to a one-line summary of the hero copy. Strip the project name if the meta merely repeats it. This becomes the WordPress site description (`blogdescription`) in Step 9. |
| Sections | List all section names from `<!-- ============ SECTION: Name ============ -->` delimiters (exclude Header and Footer). |
| Color palette | If `demo/DESIGN.md` exists (written by `/wp-demo` craft mode, path recorded as `design_md` in `.wp-create.json`), read its `colors` front matter first: `canvas`, `surface`, `ink`, `ink-soft`, `accent`, `accent-ink`, `hairline` map onto the theme tokens. Otherwise read `:root` CSS custom properties for `--color-*` values. If no `:root`, scan for dominant colors in inline styles. |
| Fonts | If `demo/DESIGN.md` exists, read `typography.display.fontFamily` and `typography.text.fontFamily` first. Otherwise read `font-family` declarations from `:root` or `<style>`. **Record where each family comes from, not only its name** — the full Google Fonts `<link href>` (it carries the weights) or the `@font-face` `src` path. Step 4.5 carries the files; a name alone leaves it nothing to carry and the theme renders a fallback. |

**Step D3 — Present pre-filled defaults:**

Show all extracted values in a summary and ask the user to confirm or adjust:

```
=== Extracted from Demo ===
  Project name:     Kairo Consulting
  Theme slug:       kairo-consulting
  Tagline:          Strategy consulting for growing teams
  Industry:         consulting
  Primary lang:     en
  Secondary lang:   es
  Sections:         Hero, Services, About, Testimonials, Contact
  Colors:           #1a5632, #c9a84c, #fafafa, #262626
  Fonts:            Inter, Playfair Display

Confirm these values? (Enter to accept, or type the field name to change it)
```

The user can override any field. Once confirmed, use these values for the rest of the init process.

**Step D4 — Inject colors/fonts into theme (template-aware):**

- If `$TEMPLATE` is `tailwind`: replace values in the `@theme` block in
  `assets/css/src/tailwindcss/main.css`:

  The `@theme` block lives in the compiled entry point `tailwindcss/main.css`;
  mapping the colours into any other file silently ships the default palette.

  | Extracted | Target variable |
  |-----------|----------------|
  | Primary/brand color | `--color-primary` |
  | Secondary color | `--color-secondary` |
  | Accent/CTA color | `--color-accent` |
  | Dark text/bg color | `--color-dark` |
  | Light bg color | `--color-light` |
  | Muted/gray color | `--color-gray` |
  | Heading font | `--font-primary` |
  | Body font | `--font-secondary` |

  Writing these two names loads nothing. **Step 4.5 carries the font files** — without it the
  theme names the demo's family and renders the next entry in the stack.

  If fewer than 6 colors are extracted, leave unmatched variables at their defaults.

  **When `demo mode` is craft and `demo/DESIGN.md` exists, write both vocabularies.**
  A craft demo's sections are copied from `skills/wp-demo-craft/compositions/`, whose
  CSS names its own tokens — `--color-canvas`, `--color-surface`, `--color-ink`,
  `--color-ink-soft`, `--color-accent`, `--color-accent-ink`, `--color-hairline`,
  `--font-display`, `--font-text`, `--space-section`, `--space-gutter`, `--container-max`,
  `--radius-sm`, `--radius-md` — while the starter's own CSS names `--color-primary` and its
  siblings. Only `--color-accent` is in both. Write one set and half the theme
  resolves properties nothing defines and renders unstyled, which is a failure with
  no error message. So write the craft vocabulary from `demo/DESIGN.md` front matter
  (`colors`, `typography`, `rounded`, `spacing`) into the same `@theme` block — which
  exists only once **Step 3** has copied the starter, so extract and confirm the values
  here and write them when the file is there, exactly as the rest of Step D4 does —
  Tailwind v4 emits every `@theme` variable into `:root`, and the colour and font
  ones also earn utilities (`bg-canvas`, `text-ink`, `font-display`) — and then
  define the starter's tokens as aliases onto it rather than as second copies of
  the same hex:

  | Starter token | Aliases to | The starter's role for it |
  |---------------|-----------|---------------------------|
  | `--color-primary` | `var(--color-accent)` | brand/signal colour; craft carries exactly one |
  | `--color-secondary` | `var(--color-ink)` | a second brand colour craft does not have — ink keeps `text-secondary` legible instead of inventing one |
  | `--color-accent` | *(no alias)* | the one shared name; `demo/DESIGN.md` defines it |
  | `--color-dark` | `var(--color-ink)` | dark text and dark fills |
  | `--color-light` | `var(--color-canvas)` | the light page background |
  | `--color-gray` | `var(--color-ink-soft)` | muted secondary text |
  | `--font-primary` | `var(--font-display)` | heading face |
  | `--font-secondary` | `var(--font-text)` | body face |

  **The craft block is `@theme static`, not `@theme`.** Tailwind v4 tree-shakes a
  plain `@theme`: a variable no utility class references is dropped from the compiled
  CSS. The starter's own tokens survive that because the starter's markup uses
  `bg-primary` and `text-dark`, but a craft demo's copied CSS reaches for
  `var(--color-canvas)` **directly** and generates no utility at all — so a bare
  `@theme` compiles the whole craft palette to nothing, every `var()` in thirteen
  compositions resolves to its fallback or to nothing, and the build still succeeds.
  `static` is what keeps an unreferenced variable in the output. Measured on a real
  build, not inferred.

  **`--container-max` travels with its `@property` guard, or the theme reproduces a
  bug the demo no longer has.** Every composition's gutter rule is
  `padding-inline: max(var(--space-gutter), calc((100% - var(--container-max, 1280px)) / 2))`,
  and `/wp-section` copies those thirteen rules into the delivered theme verbatim.
  The `var()` fallback covers a token that is *absent*; it does not cover one that is
  present and malformed (`wide`, an empty string), because `var()` substitutes the bad
  value and `calc()` is then invalid at computed-value time — which unsets
  `padding-inline` to `0` at every viewport, phones included. So write
  `--container-max` into the `@theme` block from `demo/DESIGN.md`'s `spacing.container`
  alongside the tokens above, **and emit this at the top level of
  `assets/css/src/tailwindcss/main.css`** (not inside `@theme`, which takes plain
  variable declarations only):

  ```css
  @property --container-max { syntax: "<length>"; inherits: true; initial-value: 1280px; }
  ```

  `inherits: true` is not decoration: registered with `inherits: false` the
  well-formed `:root` value stops reaching the sections that read it, which breaks the
  working case as well as the malformed one. Measured at a 1920 viewport on the exact
  gutter rule above: `1440px` → 232px with the rule and without it (unchanged), `wide`
  → 312px with it and **0px** without, empty → 312px with it and **0px** without.
  `commands/wp-demo.md` Step 6 emits the identical rule into the demo; without this
  step the theme the client actually receives is the one layer that still has neither
  guard. Where `@property` is unsupported the rule is ignored and the `1280px` `var()`
  fallback still covers the absent case, so it needs no `@supports` guard.

  **Alias by role, never by lightness.** A craft palette is often dark, so on such a
  build `--color-light` resolves to a near-black canvas and `--color-dark` to a bone
  ink. That reads backwards and is still correct: the pair the starter's CSS relies on
  is *contrast*, dark-on-light, and aliasing by role keeps it — `--color-dark` on
  `--color-light` stays ink on canvas. Aliasing by lightness would put ink-coloured
  text on an ink-coloured background on every dark demo.

  `--color-surface` and `--color-hairline` have no starter counterpart, so the mapping
  is one-way and nothing aliases onto them; only composition CSS reaches them.

  Record the table above in `<theme-dir>/DESIGN.md` (copied by Step 3) under a
  `## Token aliases` heading, so `wp-css` and `wp-section` read the mapping instead
  of re-deriving it.

  **When `demo mode` is craft, skip `/wp-tailwindify` entirely** and say so in one
  line: the compositions are already authored against the token vocabulary the theme
  now defines, so converting them to utilities discards the seam instead of crossing
  it. This is not the "already Tailwind-native" exemption below — a craft demo carries
  a `:root` and BEM classes and so reads as plain-CSS evidence on every test in that
  list — it is a separate, earlier stop. It has to be, because `wp-tailwind` maps
  colours to the nearest utility class, which would replace every
  `var(--color-ink)` reference in the composition CSS with a hardcoded class and
  delete the indirection the alias table above exists to preserve. `/wp-yolo` Step 2.6
  makes the same exception in the same terms.

  Otherwise, **run `/wp-tailwindify`** on the demo — do not merely suggest it. On the
  tailwind template the build transcribes from the demo, so a plain-CSS demo yields a
  plain-CSS theme. Whether to skip is decided on positive evidence that the demo is
  already Tailwind-native, never on the absence of a `<style>` block: a demo that keeps
  its rules in an external stylesheet carries no inline CSS at all and still has to be
  converted. This is `/wp-yolo` Step 2.6's rule, stated here in the same terms on
  purpose — do not restate it a third way:

  - **Plain-CSS evidence — any one of these means convert.** A `<style>` block; a static
    `style="` attribute; or a `<link rel="stylesheet"` pointing at the project's own
    `.css` file — a relative path (`assets/styles.css`), a site-rooted path
    (`/css/main.css`) or an absolute URL on the project's own domain all count the same,
    because the delivery route is not what matters. Only three hosts are exempt:
    `fonts.googleapis.com`, `fonts.gstatic.com` and `cdn.tailwindcss.com`. A `<link>` to
    any of those is not plain-CSS evidence; every other stylesheet `<link>` is.
  - **Tailwind evidence — what an already-converted demo looks like.** Its `class`
    attributes are predominantly Tailwind utilities: layout (`flex`, `grid`, `hidden`),
    spacing and sizing (`px-4`, `mt-8`, `w-full`), typography (`text-lg`, `font-bold`),
    colour (`bg-slate-900`, `text-white`) and variant prefixes (`md:`, `hover:`).
    Semantic or BEM class names (`site-header__logo`, `hero`, `card__title`) are the
    plain-CSS shape, not Tailwind evidence.
  - **Skip only on Tailwind evidence and no plain-CSS evidence.** Then, and only then,
    leave the demo alone and report `demo already tailwind-native — conversion skipped`.
    Everything else converts, a demo you cannot classify with confidence included: a
    redundant conversion costs one pass over markup already in the target form, while a
    wrong skip ships a plain-CSS theme and reports success. Say which case applied.

  `/wp-yolo` Step 2.6 repeats this check, so a skip here is safe.

**Step D5 — Continue with normal scaffolding:**

Proceed to **Step 2: Locate wp-content/themes/** and continue the normal flow (Steps 2-9) using the confirmed values from Step D3 instead of asking for them in Step 1.
