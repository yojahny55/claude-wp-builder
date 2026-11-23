# /wp-section — Step 6.6

`commands/wp-section.md` sends the run here at Step 6.6 when `--visual` is set. Follow it in
order, after Step 6.5 (the CSS a browser sees is compiled) and before Step 6.7.

The parity gate of `/wp-finalize` compares computed styles at the end of a build. This step
compares what a visitor sees, one section at a time, while the agents that wrote it are still
in reach: it measures the built section against its demo section pixel by pixel, and hands
what differs back to the CSS agent, at most three times.

## Contents

- When it does not run
- 1. The page that shows the section
- 2. Is the section seeded?
- 3. Measure
- 4. Fix pass (exit 1), at most three rounds

## When it does not run

- `--visual` absent: skip, and print nothing about it.
- `--hybrid`, or `Template: cinematic`: skip, and say "visual: skipped (cinematic)". The
  scroll engine pins and scrubs those sections, so a screenshot at rest is not what a visitor
  sees.
- The section has no content yet (2 below). `--visual` is for a section whose page has been
  seeded (`/wp-seed`, or edited by hand); `/wp-yolo` builds every section before it seeds, so
  it does not pass the flag.

## 1. The page that shows the section

- Target `front-page.php` (the default): the page `$WP option get page_on_front` names, at
  the site's home, `$WP option get home`. `0` (no static front page): skip, and say "visual:
  not measured (no static front page)".
- Any other `--target`: the first published page using that template:

  ```bash
  $WP post list --post_type=page --post_status=publish --meta_key=_wp_page_template \
    --meta_value=<target> --fields=ID,url --posts_per_page=1
  ```

  No page: skip, and say "visual: not measured (no published page uses <target>)". Never
  create a page to measure.

## 2. Is the section seeded?

Ask the section's own field group, `group_<slug>` (Step 5's naming convention, hyphens as
underscores), how many of its fields hold content on that page. `wp eval` takes no arguments,
so the question is a script run with `eval-file`:

```bash
$WP eval-file "${CLAUDE_PLUGIN_ROOT}/skills/wp-section-run/scripts/section-seeded.php" <page-id> <slug_with_underscores>
```

`0`: skip, and say "visual: not measured (content not seeded yet; run /wp-seed, then
/wp-section <slug> --visual)". `-1` (no ACF/SCF, or no such field group): skip, and say
"visual: not measured (no field group group_<slug>)". An empty repeater or a missing image would only measure the
absent content, and the CSS agent would "fix" it with values that are not the demo's.

## 3. Measure

```bash
out=$(mktemp -d)
node "${CLAUDE_PLUGIN_ROOT}/bin/section-diff.mjs" --demo demo/<page>.html --site <url> \
  --section <slug> --out "$out" --json
```

`<page>` is the `--page` value (default `index`). `--section` takes the slug: the tool
matches it against the demo's delimiter names the same way `/wp-section --list` slugifies
them. Keep the defaults (`--viewports 390,1440`, `--threshold 2`, `--size-tolerance 5`):
they are the tolerances antialiasing and font hinting need, and a tighter run only measures
noise.

| Exit | Meaning | Do |
|---|---|---|
| 0 | every viewport within tolerance | "visual: pass" with each viewport's percent; stop here |
| 1 | a viewport over a tolerance | go to 4 |
| 2 | nothing measured (no Chrome, no `playwright-core`, a page failed) | "visual: not measured (<the tool's stderr line>)"; stop. The section is still built |
| 4 | the section root is missing on one side, or its selector matches twice | "visual: not measured (<the tool's stderr line>)"; stop. Name the root class to check |
| 64 | usage | a bug in this step: report the command and the message verbatim; stop |

Exits 2 and 4 never fail the section: they mean the tool could not look, not that the
section is wrong.

## 4. Fix pass (exit 1), at most three rounds

Read `report.json` from `$out`: per viewport, `pass`, `diffPercent` (differing pixels) and
`widthDeltaPercent` / `heightDeltaPercent` (the built section's size against the demo's). Dispatch the CSS agent the routing in Step 5 already chose — `wp-css` on
`basic`, `wp-tailwind` on `tailwind` — and only that one, with:

- the slug, the block (`--block`, or the section's root class), the theme directory;
- each failing viewport's line from `report.json` and the paths of its three images,
  `<vw>-demo.png`, `<vw>-site.png` and `<vw>-diff.png`, which the agent reads;
- the demo source: the `--css` value under `--transcribe`, otherwise the demo page.

The agent's instructions, in the prompt:

- **Fix only this section's own rules.** `wp-css` edits the rules under this section's
  delimiter in `assets/css/styles.css`; `wp-tailwind` edits class names in this section's
  template part and its own component rules. Never `:root` tokens, global resets, the header,
  the footer or another section: a fix there moves sections this check is not measuring.
- **Take the value from the demo, never from the pixels.** Find the declared demo value
  behind the difference (a padding, a gap, a font size, a breakpoint) and use it — verbatim
  under `--transcribe`, through the matching token otherwise. A number tuned until the
  screenshots agree breaks at the next viewport.
- **Never rename the section's root class or its block.** It is how the tool finds the
  section; renaming it turns the next measurement into exit 4.
- **Not every difference is CSS.** Different text (seeded content against the demo's copy),
  a missing image or font, or a script-driven state is returned as `not CSS: <reason>` with
  nothing edited.

Each round, in this order:

1. **Keep a copy** of every file the agent may edit — `assets/css/styles.css` on `basic`;
   the template part and the section's component CSS on `tailwind` — under
   `$out/before/`, keeping each file's path relative to the theme, so two files with the
   same name never overwrite each other. `$out` is the directory of the measurement this
   round starts from.
2. Dispatch the agent, as above.
3. Rebuild (Step 6.5 again on `tailwind`).
4. Measure again (3), into a new `--out` directory so each round's images stay apart.

**A round that made it worse is undone.** When the new measurement exits 2 or 4, or its worst
`diffPercent` is higher than the round before, put back the copies from the `before/` of the
round that made it worse, rebuild on `tailwind`,
stop, and report the previous measurement with "last fix round reverted (<why>)". The tables
above are for the first measurement; after a fix round, exits 2 and 4 mean the round broke
something.

Stop when any of these holds, and report the last measurement:

- exit 0: "visual: pass after <n> fix rounds";
- three fix rounds done;
- the worst viewport's `diffPercent` fell by less than half a point since the last round (the agent
  is no longer converging; another round only churns CSS);
- the agent returned `not CSS` for every failing viewport.

What remains over tolerance goes into the summary as
`visual: over tolerance — <vw>px <diffPercent>% (width <w>%, height <h>%), … — images in <out>`, with the
agent's `not CSS` reasons. It is reported, not hidden: the section is built, and whoever reads
the summary decides whether the difference matters.
