- **`/wp-audit` asks whether to run the browser suite.** Without `--suite`, the first
  question of the run now also offers the Playwright suite (axe-core, Lighthouse and the
  rendered-page criteria vendored from `web-portal-audit`). A yes acts exactly as the typed
  flag and reuses Step 6.5's public-URL resolution. Before, a bare `/wp-audit` never ran it.
