# /wp-section — Step 6.6

`commands/wp-section.md` sends the run here at Step 6.6 when `--visual` is set. Follow it in
order, after Step 6.5 (the CSS a browser sees is compiled) and before Step 6.7.

The parity gate of `/wp-finalize` compares computed styles at the end of a build. This step
compares what a visitor sees, one section at a time, while the agents that wrote it are still
in reach: it measures the built section against its demo section pixel by pixel, and hands
what differs back to the CSS agent, at most three times.

## When it does not run

- `--visual` absent: skip, and print nothing about it.
- `--hybrid`, or `Template: cinematic`: skip, and say "visual: skipped (cinematic)". The
  scroll engine pins and scrubs those sections, so a screenshot at rest is not what a visitor
  sees.

## 1. The page that shows the section

- Target `front-page.php` (the default): the site's home, `$WP option get home`.
- Any other `--target`: the first published page using that template:

  ```bash
  $WP post list --post_type=page --post_status=publish --meta_key=_wp_page_template \
    --meta_value=<target> --field=url --posts_per_page=1
  ```

  No page: skip, and say "visual: not measured (no published page uses <target>)". Never
  create a page to measure.

## 2. Measure

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
| 1 | a viewport over a tolerance | go to 3 |
| 2 | nothing measured (no Chrome, no `playwright-core`, a page failed) | "visual: not measured (<the tool's stderr line>)"; stop. The section is still built |
| 4 | the section root is missing on one side, or its selector matches twice | "visual: not measured (<the tool's stderr line>)"; stop. Name the root class to check |
| 64 | usage | a bug in this step: report the command and the message verbatim; stop |

Exits 2 and 4 never fail the section: they mean the tool could not look, not that the
section is wrong.

## 3. Fix pass (exit 1), at most three rounds

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
- **Not every difference is CSS.** Different text (seeded content against the demo's copy),
  a missing image or font, or a script-driven state is returned as `not CSS: <reason>` with
  nothing edited.

Then rebuild (Step 6.5 again on `tailwind`) and measure again (2), with a new `--out`
directory so each round's images stay apart.

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
