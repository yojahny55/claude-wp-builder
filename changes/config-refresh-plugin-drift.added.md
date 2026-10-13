- **`wp-config.mjs refresh <path>` updates only what the probe measures.** `drift` could not
  tell "the owner deactivated or installed plugins" from "this manifest describes another
  site", and the only remedy was a full re-adoption. `refresh` rewrites `plugins.installed`,
  `stack` and the PHP and WordPress versions, keeps every other field, writes a timestamped
  backup, re-renders the CLAUDE.md block and validates; it refuses when drift is structural
  (missing theme directory, another active theme). `/wp-audit` Step 2 offers it when every drift
  line is a plugin-list line.
