- **`/wp-demo-verify` finds the gap between `max-width: N` and `min-width: N+1`.** Page
  builders emit integer breakpoint pairs, and at a fractional CSS width (browser zoom, or OS
  display scaling such as 110% with a 766px window, 767.27px wide) neither query matches. On
  a real Elementor site that gave a 704px logo instead of 112px, columns with no width, and a
  box hidden on every device visible with 119px headings. The walk only shot integer widths,
  so it could never see it and the defect reached the client's eyes. It now reads the page's
  same-origin stylesheets for such pairs (up to three), loads the page inside each gap in
  Chromium (`--force-device-scale-factor=1.1`, window size searched and read back), compares
  it with N and N+1, and reports a blocking `breakpoint-gap` with up to five culprits and a
  `gap-<N>.png`/`.jpg`. Mobile-first pages report nothing; `--no-gaps` skips it.
  `wp-responsive` now says to write `max-width: N.98px` or `(width < N+1)` when a `max-width`
  query cannot be avoided. Check: `tests/checks/demo-verify-breakpoint-gap.sh`.
