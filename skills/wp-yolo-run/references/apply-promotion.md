# /wp-yolo — Step 4.4

`commands/wp-yolo.md` sends the run here at Step 4.4. Follow it in order; nothing in it is optional background.

The reason is the ladder's own criterion. `skills/wp-tailwind-system/SKILL.md` promotes a
utility group to an `@apply` class when it appears "3+ times, or on 2+ distinct pages" —
a judgment about the theme as a whole, which no agent looking at one section can make.
Run per section, `wp-tailwind` in author mode is told to grep what earlier sections
already wrote, and that turns the promotion into a function of dispatch order: the first
section runs with nothing to grep and ships raw utilities; by the time the fourteenth
sighting of a group crosses the threshold, the thirteen template parts that also carry it
have been written and are never revisited. The result is the same group living as a
semantic class in the sections built late and as raw utilities in the ones built early —
worse than either extreme, because the `@apply` file now exists without covering the
repetition it was created for. The cost sits on top: one serialized agent per section,
each re-reading a template part `wp-template` has just written and each appending to the
same `main.css`.

So dispatch `wp-tailwind` in **author** mode exactly once, over every
`template-parts/section-*.php` the walk produced, with:

- the full list of template parts, and the pages each belongs to (a group on two parts
  that both render on one page has NOT crossed the 2-page test — the ladder counts
  distinct pages, not files)
- the same file-layout rules it follows per section: `utilities/site.css` for a group
  that spans pages, `components/<page-slug>.css` for one local to a page, `@import`
  registered in `main.css` in the same step, never an empty file
- the standing prohibition: it edits **class names only**. Every `prefix_get_field()`
  call, every `esc_*()` wrapper, every `?:` fallback and every PHP control structure in
  those files belongs to `wp-template` and is left exactly as found.

Hand-invoked `/wp-section` keeps promoting inline, and should: a single section added to
a finished theme has the whole theme to grep and nothing to aggregate. `--defer-promotion`
exists for the walk, where the theme does not exist yet.
