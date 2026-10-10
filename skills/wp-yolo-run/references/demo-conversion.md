# /wp-yolo — Step 2.6

`commands/wp-yolo.md` sends the run here at Step 2.6. Follow it in order; nothing in it is optional background.

## Contents

- Conversion is in place, with a backup
- Walk every page: detect, back up, convert (a repeated card once)
- Verify or restore, then report
- Accepted ceiling: a class borrowed across sections loses its provenance
- Under `--careful`, confirm the result

When `template == tailwind`, the section walk must transcribe from a Tailwind-native
demo, not a plain-CSS one. Transcribing plain CSS is what produced themes with zero
utility classes.

Conversion is **in place**, with a backup. Each `demo/<slug>.html` is replaced by its
Tailwind-native form and the untouched plain-CSS copy is kept out of the way as
`demo/.original/<slug>.html`. The backup goes in a dot-prefixed subdirectory on purpose:
`/wp-seed` (Step 5, item 1) turns **every** `.html` file it finds in `demo/` into a WP
Page whose slug is the filename, so a sibling backup named `demo/<slug>.original.html` would seed a phantom
page with slug `<slug>.original` out of unconverted markup — one per demo page.
`demo/.original/` falls outside the `demo/*.html` pattern entirely, so no reader that
enumerates the demo with a `demo/*.html` glob can see it: shell globbing, Python's `glob`,
`ripgrep` and `fd` all skip dot-prefixed entries by default. `/wp-seed` states no glob of
its own — `commands/wp-seed.md` says only that it processes the `.html` files in `demo/` —
so the dodge rests on that enumeration honouring the dot rule, as every tool above does. The exception is a recursive descent that does not honour the
dot rule — `find demo -name '*.html'` walks into `demo/.original/` and returns the backups
— so anything switching to `find` must add `-not -path 'demo/.original/*'` itself, and
`-not -path 'demo/.prepolish/*'` alongside it once `/wp-polish` has run over the same
folder, because that step keeps its own backups there. Nothing downstream takes a new
filename, because the demo page's own filename never changes.

Walk **every** page in the manifest's `pages[]` — the home page and every inner page,
not just `index`. For each page, in this order:

1. **Detect, per page.** Read `demo/<slug>.html` and decide whether it is *already
   Tailwind-native*. The absence of inline CSS does not answer that question, and the shape
   of the page arriving here is why. `wp-normalize` (Step 2) consolidates every external
   CSS rule it can *match to a section* inline, into the page it emits, so each page is
   self-contained — but a rule that matches no section (`:root` custom properties, resets,
   `body`, `@font-face`, a global `@media` block) is not inlined, and `wp-normalize` is
   never told to drop the `<link rel="stylesheet">` that still carries it. So the page in
   front of you may hold an inlined `<style>` block, the original `<link>`, or both, and
   each of those is CSS this page still depends on. Decide on evidence, not on the absence
   of one delivery mechanism:

   - **Plain-CSS evidence — any one of these means convert.** A `<style>` block; a static
     `style="` attribute; or a `<link rel="stylesheet">` pointing at the project's own
     `.css` file — a relative path (`assets/styles.css`), a site-rooted path
     (`/css/main.css`) or an absolute URL on the project's own domain all count the same,
     because the delivery route is not what matters. A linked stylesheet delivers CSS to
     the page exactly as much as a `<style>` block does. Only three hosts are exempt:
     `fonts.googleapis.com`, `fonts.gstatic.com` and `cdn.tailwindcss.com`. A `<link>` to
     any of those is not plain-CSS evidence; every other stylesheet `<link>` is.
   - **Tailwind evidence — what a converted page actually looks like.** Its `class`
     attributes are predominantly Tailwind utilities: layout (`flex`, `grid`, `hidden`),
     spacing and sizing (`px-4`, `mt-8`, `w-full`), typography (`text-lg`, `font-bold`),
     colour (`bg-slate-900`, `text-white`) and variant prefixes (`md:`, `lg:`, `hover:`).
     Semantic or BEM class names (`site-header__logo`, `hero`, `card__title`) are the
     plain-CSS shape, not Tailwind evidence.
   - **Skip only on Tailwind evidence and no plain-CSS evidence.** Then, and only then,
     leave the file alone, do not back it up, do not convert it, and note
     `demo already tailwind-native — conversion skipped` in the report for that page.
   - **Ambiguous input converts.** A page carrying both utilities and a project
     stylesheet, a page carrying neither, a page you cannot classify with confidence:
     convert it. The two mistakes are not symmetrical. Converting a page that was already
     Tailwind-native costs one redundant pass over markup that is already in the target
     form. Skipping a page that was not voids the entire tailwind path — the section walk
     transcribes the manifest's plain-CSS `cssRules` instead, and the theme ships with BEM
     CSS and no utility classes — while reporting success for every page. Bias every tie
     towards converting.

   Skipping on positive evidence is what makes *this step* idempotent — a second
   `/wp-yolo` pass over an already-converted demo detects and skips instead of converting
   twice, because conversion strips the `<style>` blocks *and* the project stylesheet
   `<link>` whose rules it absorbed (`@agents/wp-tailwind`, MUST remove), leaving Tailwind
   evidence and no plain-CSS evidence behind. It does **not** by itself make a re-run safe:
   by the time this step ran again, Step 2 would already have re-dispatched `wp-normalize`
   and emptied the manifest's `cssRules`, `fonts` and `backgrounds`. **Step 2's guard** is what
   refuses such a run, applying the same evidence test to the whole demo before normalize is
   dispatched. The two tests are not redundant: the guard asks "has this demo
   been converted" and stops the run; this one asks "has *this page* been converted" and
   skips one page. See Step 3's abort branch.
2. **Back up, per page.** Otherwise create `demo/.original/` if it does not exist and
   copy `demo/<slug>.html` to `demo/.original/<slug>.html` — but **only if
   `demo/.original/<slug>.html` does not already exist**. If it does, it is already the
   pristine original from an earlier run; overwriting it with an already-converted page
   would destroy the only plain-CSS reference that exists.
3. **Convert in place, per page.** Run
   `/wp-tailwindify demo/<slug>.html --out demo/<slug>.html` — the output path is the
   demo page itself, so the converted markup lands on the same path the original
   occupied.

   **Convert a repeated card once, not once per copy.** `section.repetition` is an array
   with one entry per repeated list, so a section holding two lists carries two entries and
   **both** are handled — treating it as a single object collapses the first list and leaves
   every copy in the second to be converted one by one. For each entry, pass its `selector`,
   `exemplar` and `variants` through to `/wp-tailwindify` and tell it to convert the
   exemplar plus each variant, then apply that exemplar's resulting `class` attributes to
   its non-variant siblings position-for-position. **Only the `class` attribute is written.**
   Every other attribute and all text stay exactly as the demo had them — not just the
   obvious `href`, `src`, `alt` and `data-*`, but `id`, `aria-*`, `title`, `role` and
   anything else on the element; the list is illustrative, not a licence to drop what it
   omits. Each index listed in `variants[]` **keeps its own
   converted `class` attributes** — it was converted precisely because it differs, so
   stamping the exemplar's string over it would flatten away the difference that made it a
   variant. The remaining siblings are the same component with different content — that is
   what the entry asserts — so their utility strings are identical by construction and
   re-deriving each one from the same CSS is pure repetition of work.

   A variant never donates its classes either. `exemplar` is guaranteed not to appear in
   `variants[]`, so stamping is always from a plain copy; if a manifest violates that, treat
   the entry as unusable, convert the list in full and say so in the report.

   This matters more than it looks. A directory page drawing sixteen cards from four
   records, or a board page drawing eighteen from three, is the most expensive page in the
   demo *and* the one whose markup collapses hardest: in the theme all N become a single
   template part inside a loop, so the N-1 extra conversions are paid for and then thrown
   away. Skipping them does not reduce fidelity, because the copies were never independent.

   If the conversion of a sibling would differ from the exemplar's — a card that is
   genuinely wider, ordered differently, or hidden at a breakpoint — then it is a variant
   and the manifest should have listed it in `variants[]`. Do not apply the exemplar's
   classes to it: convert it in full and add a `review[]` note so the next run's
   classification is corrected rather than silently worked around.
4. **Verify, or restore.** Read `/wp-tailwindify`'s Step 4 verification result for this
   page: section delimiters preserved, no `<style>` blocks remaining, and no project-local
   stylesheet `<link>` remaining. The third item is what makes item 1's skip terminate: a
   converted page that still links `assets/styles.css` carries plain-CSS evidence, so the
   next run classifies it as not-yet-Tailwind-native and converts it again, forever.

   On a failure there is normally **nothing to restore**, and the restore below is a
   belt-and-braces check rather than the main line of defence. `/wp-tailwindify` has the
   agent write `<output-path>.tmp` and moves it over the demo page only after that
   verification passes (its Step 3, and Step 4 items 5-6); a page that failed never
   reaches `demo/<slug>.html`, so what is sitting there is still the pristine original
   and copying the backup over it changes nothing. Keep the check anyway, but condition
   it on that invariant instead of assuming it holds: after a reported failure, compare
   `demo/<slug>.html` byte-for-byte with the backup. **Identical** — the contract held;
   report the page as unconverted and touch nothing. **Different** — something outside
   the contract wrote that path (a hand-run conversion, an older plugin version, an
   editor, or an `mv` that prompted instead of moving), so restore `demo/<slug>.html`
   from `demo/.original/<slug>.html` and report the page as unconverted. Never leave a
   truncated or half-converted page at `demo/<slug>.html`: item 1 would read the wreckage
   on the next run, see utility classes and no project stylesheet, declare the page
   already Tailwind-native and skip it forever, and items 2-6 below would build from the
   wreckage.
5. **Re-point — nothing to re-point.** Because conversion is in place, every later
   reader picks up Tailwind-native markup with no argument change and no new flag:
   item 2 (`/wp-cpt <name> --from-demo <section>`, which reads `demo/index.html`),
   item 3 (`/wp-header`, same file), item 4 (`/wp-footer`, same file), item 5 (the home
   `sections[]` walk, `--page index` → `demo/index.html`) and item 6 (every inner page's
   walk, `--page <slug>` → `demo/<slug>.html`) all resolve to the converted file.
   `demo/.original/<slug>.html` is a reference copy only: it is never a build source, it
   is not a manifest page, no `--page` value ever resolves to it, and `/wp-seed` never
   globs it.
6. **Report.** Record which demo pages were converted, which were skipped as already
   Tailwind-native, and which were restored from backup after a failed verification.

**Accepted ceiling — a class borrowed across sections loses its provenance.** Demos
reuse a class wherever the geometry happens to match: a Contact page heading carrying
`.services__title` is ordinary demo authoring. Conversion inlines that rule's
declarations onto the element as utilities, so the render stays right and each section
still transcribes from its own markup — what is lost is the *evidence of sharing*. After
conversion the two headings read as two independent utility groups, so the decision
ladder's "same group on two or more pages" test must be run over the converted markup by
comparing utility strings, there being no class name left to record it. Missing it costs
a duplicated inline group, never a wrong render, which is why this is accepted here
rather than worked around.

Under `--careful`, confirm the conversion result with the user before continuing.
