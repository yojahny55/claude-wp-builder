# /wp-demo — Step 2.6

`commands/wp-demo.md` sends the run here at Step 2.6, item 6 (Build). Follow it in order; nothing in it is optional background.

Create `demo/` if absent and write `demo/index.html` plus
**one file per page in the agreed page set** (`about.html`, `services.html`,
`contact.html` — whatever the docs and the curve named). Interior pages are
built here, not left for later: an index alone is half the failure this mode
exists to fix, and step 7 walks the whole directory. Each interior page is built
from its own rows in the sub-step 5 plan. An interior page whose body carries no
composition has not been built, only filled — and it will pass every machine gate,
because valid markup with correct tokens is exactly what a hand-rolled template
produces. Every page carries the
header and footer chrome from Step 4 (logo, nav, language switcher, hamburger
at mobile, footer columns) and Step 4's responsive breakpoints; ignore Step
4's single-file, no-CDN, `:root` token and placeholder-content clauses, which
are the plain path.
Generate `:root` from `demo/DESIGN.md` onto the token names in
`${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/design-md.md` — the
craft tokens (`--color-canvas`, `--color-ink`, `--font-display` and the rest),
which are what every composition's CSS already uses, not plain mode's
`--color-primary` set. The section delimiters are the ones plain mode uses,
unchanged, because `/wp-section` reads them either way.
Emit this **on every page this step writes** — `index.html` and each interior
page alike, since each carries its own `<style>` — immediately before that
page's `:root` block and in the same `<style>`:

```css
@property --container-max { syntax: "<length>"; inherits: true; initial-value: 1280px; }
```

`var(--container-max, 1280px)` guards a token that is *absent*. It does not
guard one that is present and malformed — `wide`, an empty string — because
`var()` substitutes the bad value and `calc()` is then invalid at
computed-value time, which unsets `padding-inline` to `0` at every viewport,
phones included. `@property` makes an invalid value fall back to
`initial-value` instead. Where `@property` is unsupported the rule is ignored
and the `1280px` fallback still covers the absent case, so it needs no
`@supports` guard.
**Emit every composition's CSS inside `@layer compositions { … }`, and never put
your own CSS in a layer.** An unlayered rule beats every layered one regardless of
source order or specificity, so this is what makes an author override work. Without
it the only thing deciding the winner is which block was written first, which is a
convention nobody can see in the output: a build that emitted its overrides above
the composition CSS had every equal-specificity rule silently ignored, spent a
round fixing things that were already "fixed", and found it only by screenshot.
A layer is a guarantee; an ordering rule is an etiquette that fails quietly.

Copy each chosen composition's `section.html` and `section.css`, fill the
`{{slots}}` with real copy and real assets — an image slot fills from that
gap's own `result.file` in `demo/.image-plan.json`, keyed by that gap's own
`slot` field, not a fixed string: `feature-zigzag`'s two gaps use
`feature_1_image_src` and `feature_2_image_src`, for example — **no page may ship with a
`{{` left in it** — check the page's *rendered markup*, not the whole file: the
inlined `motion.js` carries the literal `{{slot}}` inside a source comment, so a
naive whole-file grep fails on the engine every time and has already cost a build
cycle —: several slots fill `alt` and `aria-label` attributes, where
an unsubstituted marker is read out verbatim by a screen reader and never
appears on screen for anyone to notice — keep the delimiters and the BEM
block. Motion comes from `data-motion-*` attributes only. Inline the contents of
`${CLAUDE_PLUGIN_ROOT}/starter-theme/__tailwind__/assets/js/src/motion.js` in a
`<script type="module">` block (`motion.js` uses `export function initMotion`,
so a plain non-module `<script>` throws `SyntaxError: Unexpected token 'export'`
and silently disables all motion), after loading GSAP and ScrollTrigger from
`https://cdnjs.cloudflare.com` with pinned versions. Any bespoke effect goes
in its own `<script id="signature">` block so `/wp-init` can lift it to
`assets/js/signature.js`.
Inline `${CLAUDE_PLUGIN_ROOT}/starter-theme/__tailwind__/assets/css/src/tailwindcss/utilities/motion.css`
into a `<style>` block in the same step. It is the CSS half of the engine and
carries the `reveal` device wherever the browser supports scroll-driven
animation; without it, a demo in a modern browser reveals nothing, because
`motion.js` yields that device to the stylesheet.
