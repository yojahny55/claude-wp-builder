- **`/wp-section --visual` checks a built section against its demo and fixes what differs.**
  After the CSS is compiled, Step 6.6 runs `bin/section-diff.mjs` on the page that shows the
  section. A viewport over tolerance goes back to the section's CSS agent with the demo, site
  and diff images; the agent fixes only that section's rules, with the demo's declared values,
  and says so when a difference is content rather than CSS. The loop stops after three rounds
  or when the difference stops shrinking, and the summary reports what remains. Without a
  local Chrome, or when the section cannot be found, it reports "not measured" and the section
  is still built.
