- **`/wp-section` ports the section's JavaScript.** A single-section build had no script step,
  so a carousel or gallery built that way rendered and did nothing. The new `wp-js` agent
  writes one guarded, no-op-without-markup module per section under
  `assets/js/src/sections/`, bound to `data-` hooks it adds to the template part, reuses the
  theme's own tabs, accordion and filter modules, wires the module into `index.js` and
  rebuilds the bundle. `/wp-section` Step 6.4 dispatches it whenever a demo script touches the
  section, found with the new `bin/demo-scripts.mjs` (inline script bodies only, never the
  page markup); a library the theme does not have stops it with the install command, and a
  stopped port is undone.
