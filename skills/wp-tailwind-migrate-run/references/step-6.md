# /wp-tailwind-migrate — Step 6

`commands/wp-tailwind-migrate.md` sends the run here at Step 6. Follow it in order; nothing in it is optional background.

Then run the convention check, still without changing directory. Step 0's warning is
what makes that possible: the build above ran in the theme root, the check below is a
**plugin-relative** script that takes the theme path as its *argument*, and the
screenshot block after it is theme-relative again. Run the check by its full path from
the plugin root — `${CLAUDE_PLUGIN_ROOT}` is that path — and do not run it from inside
the theme expecting `bin/` to resolve there:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/tailwind-native-check.sh" <theme-path>
```

That script judges a **whole-theme** migration, and two of its rules cannot hold
part-way through a `--page` run: it fails while `assets/css/styles.css` still exists
(Step 5 deliberately keeps it until the last template is migrated) and it fails while
any template still carries plain-CSS class names instead of utilities. Under `--page`,
record both as expected and re-run the check for real once the last template lands. On
a completed whole-theme run rule 1 is a genuine failure. Rule 6 scales to the theme: it
demands Tailwind utilities in every template that carries a class attribute, up to a
ceiling of three, so a correct two-template theme passes it. Any count it reports below
that floor is a genuine half-migrated theme, not an artefact of the theme being small.
Say which case you are in rather than reporting the count as a defect.

Then re-shoot every migrated page and compare against the Step 0 golden:

```bash
for slug in <every page migrated>; do
  mkdir -p .tailwind-migrate/after/"$slug"
  # /wp-responsive-check <url-for-$slug>
  # Method B — the five fixed names are already in the cwd:
  mv responsive-*.png .tailwind-migrate/after/"$slug"/ 2>/dev/null || true
  # Method A — copy each capture as in Step 0; the glob may match nothing.
  [ "$(ls .tailwind-migrate/after/"$slug"/responsive-*.png 2>/dev/null | wc -l)" -eq 5 ] \
    || { echo "Error: after-shots for $slug are incomplete."; exit 1; }
done
```

**The comparison mechanism, stated because there isn't an automatic one.**
`/wp-responsive-check` analyses a single page for layout faults; it does not diff two
images and will not tell you the migration changed something. For each page and each
of the five widths: **Read both PNGs** — `.tailwind-migrate/before/<slug>/responsive-<w>.png`
and `.tailwind-migrate/after/<slug>/responsive-<w>.png` — and compare them directly,
naming what differs (spacing, colour, font, wrap point, element order).

### A differing-pixel count proves nothing until you know its noise floor

`compare -metric AE before.png after.png null: 2>&1` looks like the objective test this
step wants, and it is not one on its own. Anything the GPU composites — `backdrop-filter`
above all, but also large gradients and transformed layers — does not rasterise
identically between two runs. Measured on a page with six `backdrop-blur` cards: two
consecutive captures of **the same unchanged page** differed by 135k pixels, while
baseline against the migrated version differed by 26k. Read in isolation, the real
comparison looked five times cleaner than the page compared against itself.

So before you compare anything, **capture the same page twice and diff those two**. That
number is the floor. A before/after count at or under it says nothing; only a count well
above it is evidence, and it still needs the visual read to say what moved.

### The numeric contract is the actual oracle

Screenshots are the fallback. What survives a migration unchanged is *geometry*, so
measure it directly in the page, before and after, and diff the numbers:

- page height, section count, every section's height, the gap between consecutive sections
- for each heading: box, line count, computed font-size, line-height, letter-spacing
- for each image/art group: rendered box
- counts of the repeated pieces (cards, list items, tiles)
- **the on-screen order of every row that can reverse** — for each flex row, whether the
  art sits left of the text, and each row's computed `flex-direction`

That last one is not padding. A rewrite that drops a `flex-row-reverse` mirrors a whole
section left-to-right while every box keeps its exact size — page height, section
heights, gaps and every element box stay byte-identical, and a contract built only from
sizes reports a perfect match. It happened; the screenshot read is what caught it, which
is precisely why both halves of this step exist.

Report each page and viewport as match or diverged, with the specific difference.
**Do not report the migration as successful without this comparison** — a
Tailwind-native theme that renders differently is a failed migration, not a completed
one. "The check passed" is not the same claim: `bin/tailwind-native-check.sh` validates
the CSS convention and cannot see the rendered design at all.

If a viewport diverged, fix it and re-compare before finishing.
