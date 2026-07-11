# Expected: `/wp-yolo` fidelity + gate behavior for `fidelity-demo/`

Hand-traced oracle for this adversarial fixture. Every assertion below is cross-checked
against the documented behavior of `agents/wp-normalize.md`, `commands/wp-finalize.md`, and
`commands/wp-yolo.md` on this branch — not invented.

## The fixture's traps (one per failure class)

| Trap | Where | Why it breaks a re-authoring pipeline |
|------|-------|----------------------------------------|
| `.services` on BOTH pages | `index.html` + `services.html` (one `.services` rule in `styles.css`) | Split into two per-page section files, `.services` collides when bundled into one stylesheet. |
| CSS `background:url()` (no `<img>`) | `.home-hero` / `.sp-hero` in `styles.css` | A markup-only pass copies `<img>` only; the hero backgrounds silently vanish. |
| `@font-face` self-hosted | `Brand Sans` → `fonts/brand-sans-regular.woff2` | Font never carried → renders in a system fallback. |
| Per-page hero background | `hero-home.jpg` vs `hero-services.jpg` | Distinct per-page image never seeded → blank hero. |
| Header nav-graphic ≠ logo | `logo.svg` (role logo) vs `nav-icon.svg` (`.nav-toggle`, role nav-graphic) | Nav graphic mis-set as `site_logo`. |
| Literal `color:#BFBFBF` | `.services .note` | Mapped to nearest token (`--color-gray` #848484) instead of copied. |

## Expected `wp-normalize` manifest annotations

- **Unique blocks assigned** (not requested): the two `.services` sections →
  `home-services` and `sp-services`; heroes → `home-hero` / `sp-hero`.
- **`section.cssRules`** carries the verbatim declared CSS for each section (so `wp-css`
  transcribes, not guesses) — including `.services .note { color:#BFBFBF }` byte-for-byte.
- **`section.backgrounds`**: `["images/hero-home.jpg"]` (home hero), `["images/hero-services.jpg"]` (services hero).
- **`section.fonts`**: `[{ family:"Brand Sans", weight:"400", style:"normal", src:["fonts/brand-sans-regular.woff2"] }]` on the sections that use it.
- **`section.computed`**: `{height:480}` (home hero), `{height:320}` (services hero).
- **top-level `assets[]`** (role-tagged):
  - `logo.svg` → `role:"logo"`
  - `nav-icon.svg` → `role:"nav-graphic"`  ← NOT logo
  - `hero-home.jpg` → `role:"hero", page:"index"`
  - `hero-services.jpg` → `role:"hero", page:"services"`

## Expected build (`/wp-yolo`, Phase 2 transcription)

- Each `wp-css` dispatch gets its `block` + `cssRules` and transcribes literally:
  - `.services .note` color stays **`#BFBFBF`** — NOT token-mapped. (Failure #1 avoided.)
  - hero `background:url()` is transcribed into the section CSS. (Failure #3 avoided.)
  - no `min-height:44px` / textarea resizing / value rounding added.
- Selectors scoped under the assigned block → `home-services` and `sp-services` never both
  emit bare `.services`. (Collision structurally impossible.)
- **Fonts carried:** `brand-sans-regular.woff2` → `theme/assets/fonts/`, `@font-face` re-emitted
  with rewritten `src`, enqueued. No Google-Fonts preconnect (the demo uses none).
- **Assets seeded by role** (Phase 3): `logo.svg` → `site_logo`; `hero-home.jpg`/`hero-services.jpg`
  → each page's `inner_hero_image`; `nav-icon.svg` → theme asset only, never `site_logo`.

## Expected gate result (`/wp-finalize`, auto-run by `/wp-yolo`)

Auto-fixes applied then re-verified; nothing ambiguous remains, so the build **passes**:

- **Layer 1 (static):**
  - Collision scan: if two bare `.services` blocks ever reached the bundle, **auto-rename** to
    `home-services` / `sp-services`. (A shared class scoped under different page blocks would
    NOT be flagged — this is a true unscoped collision.)
  - Undefined-var scan: none (values are literals). 
  - Font parity: `Brand Sans` `@font-face` + `assets/fonts/brand-sans-regular.woff2` present. 
  - Background presence: both hero `background:url()` present (transcribed) or seeded. 
- **Layer 2 (WP-CLI):** `site_logo` non-empty; `inner_hero_image` seeded on both pages; menu
  assigned; pages exist.
- **Layer 3 (measured, if claude-in-chrome connected + site up):**
  - `.services .note` computed `color` == `rgb(191,191,191)` (#BFBFBF) — a hex mismatch would be
    a **hard-delta BLOCK**.
  - `.home-hero` height ≈ 480px, `.sp-hero` ≈ 320px — off by >3%/8px would **BLOCK**.
  - heading/body `font-family` resolves to `Brand Sans`, not a system fallback — fallback would
    **BLOCK**.
  - hero backgrounds visible; logo renders (not text fallback).
  - Sub-pixel / antialiasing differences → **WARN only**, never block.

## What would BLOCK if a builder regressed

- `.services` left un-namespaced and colliding → collision scan critical.
- hero `background:url()` dropped → background-presence critical + Layer-3 missing-background hard delta.
- `#BFBFBF` token-mapped to `--color-gray` → Layer-3 color hex hard delta.
- `Brand Sans` not carried → font-parity critical + Layer-3 system-fallback hard delta.
- `nav-icon.svg` set as `site_logo` → wrong logo renders (caught visually); `site_logo`
  should be `logo.svg`.

Under `--yolo`, any remaining critical marks the run **incomplete** and prints the Review list;
`/wp-yolo` does not report success.
