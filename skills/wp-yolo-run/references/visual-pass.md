# /wp-yolo — Step 5

`commands/wp-yolo.md` sends the run here at the end of Step 5, item 3, only when `--visual` is set:
the pages are seeded and the CSS is compiled, and `/wp-finalize` has not run yet, so its parity
gate measures whatever this pass changes. Without `--visual`, skip this file and print nothing
about it.

`/wp-section --visual` cannot do this during Step 4: every section is built before `/wp-seed`
runs, so each one would measure an empty page. This pass runs the same visual check, section by
section, once there is content to measure.

## Contents

- Which sections
- How each one is measured
- One section at a time
- What it never does
- Report

## Which sections

Every section this run built with `/wp-section` in Step 4: the `kind: "static"` and
`kind: "contact"` sections of `pages[role=home]` and of every `pages[role=inner]` page, in
manifest order. Out of scope, and not listed:

- `kind: "cpt-teaser"` sections (built by `/wp-cpt`, not by `/wp-section`), `cpt-archive`
  pages and the blog;
- sections the scope reconciliation skipped;
- everything on `Template: cinematic`, and any section built `--hybrid`: say "visual: skipped
  (cinematic)" once, and stop.

The flag is not recorded in the build ledger, so a resumed run does the pass only when
`--visual` is passed again (`--resume --visual`). The list is then the same: the pass is not a
ledger unit, and it measures every built section whether this run or an earlier one built it.

## How each one is measured

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-section-run/references/visual-check.md` and follow its
sections 1 to 4 for the section, with the arguments Step 4 passed to `/wp-section` for it:
`--page`, `--target`, `--block` and `--css`, and `--transcribe`, which every `/wp-yolo`
section is built with. Its "When it does not run" list applies, except the `--visual` line.

- Home page sections target `front-page.php`: the page `page_on_front` names.
- Inner page sections target `page-<slug>.php`: the page `/wp-seed` created at that slug,
  which visual-check section 1 finds by slug.
visual-check.md cites `/wp-section`'s own step numbers, which mean other things here. Read
them inside this run as:

- `/wp-section`'s field naming: the section's field group is `group_<slug>`, where `<slug>` is
  the section name Step 4 passed to `/wp-section`, slugified, with hyphens as underscores.
- `/wp-section`'s CSS routing: the CSS agent Step 4 routed to, `wp-css` on `basic`, `wp-tailwind`
  on `tailwind`.
- `/wp-section`'s rebuild step: `bash "${CLAUDE_PLUGIN_ROOT}/bin/tailwind-rebuild.sh" <theme-dir>` on
  `tailwind`.
- "The section's component CSS" on `tailwind`: every file under
  `assets/css/src/tailwindcss/components/` that holds a rule for the section's block, which is
  where Step 4.4's `@apply` promotion put them. Copy each one before a round, with the
  template part.

## One section at a time

Never measure or fix two sections in parallel. On `basic` every section's rules live in one
`assets/css/styles.css`, and a round that is undone puts back the copy taken before it: two
sections in flight would put back each other's work.

The three-round cap is per section. A section that stops over tolerance does not stop the pass:
go on to the next one.

## What it never does

- **It never makes the run incomplete.** A section over tolerance, `not measured` or `not CSS`
  is reported, not blocking: the parity gate in Step 5.5 is still the gate.
- **It never creates or seeds content to measure.** A section whose fields are empty is "not
  measured (content not seeded yet)", the same as in `/wp-section`.
- **An exit 2 for a missing tool stops the pass.** When the stderr line says
  `playwright-core, pixelmatch or pngjs is not installed` or `no existing Chrome or Chromium`,
  no later section will have them either: record "visual: not measured (<the tool's stderr
  line>)" once for the whole pass and go on to item 4. Any other exit 2 is one page that
  failed to load: that section is "not measured (<the tool's stderr line>)", and the pass goes
  on to the next section.

## Report

Step 6 prints one `Visual:` line with the counts, and lists each section that is not a pass
under Review with the line visual-check gives it:

```
Visual:            <n> pass, <n> pass after fix rounds, <n> over tolerance, <n> not measured
```

Print it under either banner, `Build Complete` or `INCOMPLETE`: an incomplete run still built
those sections. Sections skipped as cinematic, and `not CSS` reasons, go under Review.
Without `--visual`, Step 6 prints no `Visual:` line.
