# /wp-tailwindify — Step 4

`commands/wp-tailwindify.md` sends the run here at Step 4 (Verify Output). Follow it in order; nothing in it is optional background.


After the agent completes, and **before** the temporary file is moved over the output
path:
1. Read the temporary file the agent wrote
2. Verify section delimiters are preserved (count should match original)
3. Verify no `<style>` blocks remain (except `@keyframes`)
4. Verify no project-local stylesheet `<link>` remains. Only `fonts.googleapis.com`,
   `fonts.gstatic.com` and `cdn.tailwindcss.com` links may survive the conversion; a
   `<link>` to any other `.css` file means the demo's own stylesheet is still attached,
   the page is not Tailwind-native, and `/wp-yolo` Step 2.6 will re-convert it on every
   later run because a linked project stylesheet is plain-CSS evidence.
5. **Verify what it RENDERS, not only what it contains.** Items 2-4 are structural: a
   page can pass all three and still have lost a declaration. One did. The demo's reset
   read

       button{font:inherit;color:inherit;background:none;border:0;padding:0;cursor:pointer}

   and the conversion dropped the whole line as covered by preflight. Preflight covers
   five of those six declarations and NOT `cursor` — Tailwind v4 leaves buttons on the
   UA default, which is `default`. Every button on the site lost its pointer. Nothing
   downstream could catch it either, because every later gate compares the theme against
   the CONVERTED demo: once a declaration is gone from the reference, both sides agree
   and the site is wrong. **This is the only point in the pipeline where the original is
   still available to compare against.**

   ```bash
   node <plugin>/bin/tailwindify-parity.mjs <converted> --against <original> \
        --widths 1440x900,390x844
   ```

   It renders both and joins leaf elements on tag + text — the two use different class
   systems, so a selector join is impossible, but they render the same words. Exit 0
   clean, 1 deltas, 2 no usable browser (not a failure: say the gate could not run), 3
   crashed. Findings grouped by property, because a dropped reset shows up as the same
   property on many unrelated elements, and that shape is the diagnosis.

   `--widths` is a floor, not the whole sweep: the gate also reads every
   `max-width`/`min-width` value out of the ORIGINAL's own CSS and adds those exact
   pixel widths to what it samples. A breakpoint conversion off by one pixel (see the
   inclusive/exclusive rule above) is invisible at 1440 and 390 — a demo's `max-width:
   768px` and Tailwind's `max-md:` disagree only AT 768, so the sweep has to land
   there to see it.

   **Run it where the converted page renders.** Conversion strips the demo's stylesheet
   and adds no replacement (see Step 5), so unless the demo carries its own Tailwind
   runtime the converted page is bare HTML and there is nothing to compare — the gate
   detects that shape and says so rather than reporting every element as a delta. On the
   `/wp-yolo` path, run it once after Step 2.6 has converted every page. A delta the gate
   reports is not automatically a defect: `oklab()` for a colour with an opacity modifier
   and `rgba()` for the same colour are the same pixels, and the gate already resolves
   both through a canvas, but a `visually-hidden` heading that no one can see is still
   going to differ. Read them; do not paste them.
6. Only if 2, 3, 4 and 5 all hold — or 5 exited 2 and you reported that the rendering
   gate could not run — move the temporary file over the output path. Otherwise
   discard it, leave the output path untouched, and report the conversion as failed —
   never a partial success.
7. **Move with `\mv -f`, then prove the move happened.** An interactive shell aliases
   `mv` to `mv -i`; the prompt goes unanswered, the file is not moved, and the command
   still exits 0 — a whole demo folder has already been "converted" this way, three
   pages left untouched with three orphan `.tmp` files beside them and every page
   reported as a success. The leading backslash bypasses the alias and `-f` answers the
   prompt. Then check the post-condition before reporting anything for this page:
   `<output-path>.tmp` no longer exists **and** `<output-path>` now holds the converted
   markup (the delimiter count from item 2, no `<style>` block, no project-local
   stylesheet `<link>`). If the `.tmp` is still on disk, the move did not happen: report
   the page as failed, not converted. A page whose post-condition was not checked is
   never reported as converted.
8. Report the conversion result to the user
