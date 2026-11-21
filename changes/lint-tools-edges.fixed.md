- **Lint and gate tools stop answering in silence.** `css-contour-lint` rejects unknown
  flags and accepts `--rule=<name>` (both used to run every rule), no longer reads `clearfix`
  as a search clear control, and no longer reads a border-only compound such as
  `.btn.btn-primary` as transparent when `.btn` paints a solid background. `contrast-propose`
  reads `#rgb`, `#rgba`, `#rrggbbaa` and `rgb()`/`rgba()` (alpha is flattened onto the
  background, then onto white; the proposal stays opaque) and reports bad or missing input as
  a one-line error with exit 2 instead of a stack or "no shade reaches it". `assets-fresh`
  exits 2 ("critical cuts not checked") when a manifest lists no sheet and no cut, instead of
  printing FRESH, and checks an optional `cutHash` for the cut file itself. `theme-template-check`
  takes the `widgets` script entry from `--entry` or the `wp-scripts` call in `package.json`,
  and its finding names the file it read.
