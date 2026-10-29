- **`bin/audit-suite.sh` run flags and third-party blocking.** `--workers`, `--timeout`,
  `--engines` and `--settle` replace hand edits of the generated `playwright.config.js`
  (which the scaffold used to overwrite at the start of the run, so they never applied;
  an edited config is now kept, tracked by `.scaffold-sums`). `--block-third-party` /
  `--no-block-third-party` with `--allow-hosts` block every host but the audited one, on
  by default against a local host so a clone sends no real hits to production analytics or
  embeds; `--workers` above 1 is refused against production, and `--project` points to
  `--engines`. A non-empty `--dir` refusal now lists the files in the way.
  `bin/ux-probe.mjs` gains `--block-third-party`, `--block-hosts` and `--allow-hosts` on the
  same allowlist (`bin/lib/third-party.cjs`). `/wp-audit` now looks for an existing Chromium
  with `bin/lib/browsers.mjs` before reporting "no browser".
