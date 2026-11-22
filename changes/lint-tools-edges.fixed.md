- **Lint and gate tools stop answering in silence.** `css-contour-lint` rejects unknown
  flags and accepts `--rule=<name>` (both used to run every rule), no longer reads `clearfix`
  as a search clear control, and no longer reads a border-only compound such as
  `.btn.btn-primary` as transparent when `.btn` paints a solid background. `contrast-propose`
  reads `#rgb`, `#rgba`, `#rrggbbaa` and `rgb()`/`rgba()` (alpha is flattened onto the
  background, then onto white; the proposal stays opaque) and reports bad or missing input as
  a one-line error with exit 2 instead of a stack or "no shade reaches it". `assets-fresh`
  exits 2 ("critical cuts not checked") when a manifest lists no sheet and no cut, instead of
  printing FRESH, and checks an optional `cutHash` for the cut file itself. `theme-template-check`
  takes the `widgets` script entries from `--entry` alone, or from every path any `wp-scripts
  build|start` call in `package.json` names plus `assets/js/src/index.js` when it exists (a
  module passes when any of them imports it), and its finding lists the files it read.
  `contrast-propose` also scores a moved background with a translucent foreground composited
  over each candidate and reports the final pair's real ratio. What is now an error (exit 2):
  an unknown argument, a `--pair` ratio of 0 or 1 or below or not a number (an empty ratio
  still means 4.5), and an unreadable colour in `--pair`; an unreadable or non-text colour in
  an `--axe` node is skipped with a WARN on stderr and the rest is reported.
