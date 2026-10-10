# /wp-yolo — Step 5.5

`commands/wp-yolo.md` sends the run here at Step 5.5. Follow it in order; nothing in it is optional background.

1. **Auto-fix mechanical findings** — no judgment required, apply directly.

   > **Template branch — read before applying any repair that writes CSS.** Every repair
   > below branches on the project's `Template:` value from Step 1.
   > On `basic`, a repair is a literal CSS declaration written into the theme CSS, read
   > from the demo's recorded CSS in the manifest.
   > On `tailwind`, a repair is expressed as **Tailwind utility classes in the markup** —
   > or an `@apply` rule, and only where the decision ladder in
   > `skills/wp-tailwind-system/SKILL.md` demands one — and is read from the
   > **Step 2.6-converted** demo page (`demo/<slug>.html`), never from the backup at
   > `demo/.original/<slug>.html` and never from the manifest's plain-CSS `cssRules`.
   > Never write a raw CSS declaration into a theme CSS file on the tailwind path: that
   > re-injects exactly the plain CSS this template exists to remove.
   >
   > **`@font-face` is the one carve-out, and the only one.** Tailwind has no utility
   > and no `@apply` form for it, so it is rung 4 of the ladder — raw CSS for what
   > Tailwind cannot express — not a breach of the line above. The missing-font repair
   > below therefore does re-emit a raw `@font-face` block; it goes into
   > `assets/css/src/tailwindcss/base/fonts.css` with its `@import` added to
   > `main.css`, exactly as in Step 4.5, and never into a section's component file or a
   > second enqueued stylesheet. No other repair on this path may write raw CSS.

   - Token-drifted value with a clear literal source in the demo → replace it with the
     demo's literal value on `basic`; on `tailwind`, re-express the corrected value as
     the Tailwind utility (or `@apply` rule) that produces it, sourced from the converted
     demo page.
   - Missing font → copy the woff2 file(s) into `theme/assets/fonts/` and re-emit the
     `@font-face` rule exactly as Step 4.5's font carry does it, including its branch:
     on `basic` into the enqueued stylesheet or fonts partial, on `tailwind` into
     `assets/css/src/tailwindcss/base/fonts.css` plus its `@import` in `main.css`, with
     no second enqueue. If the woff2 is not in the demo folder, Step 4.5's
     missing-source branch applies here too — no `@font-face` pointing at a file that
     does not exist; the finding goes to Review instead.
   - Missing logo/hero asset → seed it by its manifest `role` (`logo` / `hero`), same as
     `/wp-seed`'s role-tagged asset pass.
   - Colliding block (unscoped generic class) → rename/rescope it to its manifest-assigned
     unique `block` name.
   - Missing `background:url()` → on `basic`, transcribe it verbatim from the demo's
     recorded CSS (`section.backgrounds` in the manifest) into the theme CSS. On
     `tailwind`, take the background from the converted demo page and express it as a
     Tailwind utility (`bg-[url(...)]` and its companions) in the markup, or as an
     `@apply` rule when the ladder demands one — not as a raw declaration in a theme CSS
     file.
2. **Re-verify** — after applying any auto-fix, re-run the affected gate layer(s) to
   confirm the finding actually cleared. Do not assume the fix worked; re-run and check.
3. **Ambiguous findings are reported, not guessed.** Value drift with no clear literal
   source, or a layout mismatch needing design judgment, is never auto-fixed — add it
   verbatim to the blocking **Review** list.
4. **Any critical finding still open after auto-fix + re-verify — including everything
   ambiguous — blocks delivery.** This applies **even under `--yolo`**: `/wp-yolo` does not report success while any critical remains. The run is marked incomplete and the
   Review list is printed prominently at the top of Step 6's report, before the rest of
   the summary.
