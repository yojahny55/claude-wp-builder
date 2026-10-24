- **State-file contract and configurable report directory.** The audit ledger
  (`.wp-audit-findings.json`), the `.wp-audit/` reports, manifest backups and Robin's runtime
  cache were written without ever saying whether they belong in git, and in a normal repo the
  ledger got committed. `TOOL_STATE_PATHS` in `bin/wp-config.mjs` is now the single list, and
  `wp-config.mjs gitignore-check <root>` prints the entries git would commit (exit 4).
  `/wp-adopt`, `/wp-audit` and `/wp-robin` call it and offer (default yes) to ignore the
  plugin's own entries, the one exception to `/wp-adopt`'s no-`.gitignore` rule. Reports go to
  `--out`, else `WP_AUDIT_OUT_DIR`, else `audit.out_dir`, else `.wp-audit`; the renderer warns
  when that directory is unignored inside a git tree and prints absolute paths.
