- **`/wp-status`: where the project is and what runs next.** A read-only command backed by
  `bin/wp-status.mjs` reads `.wp-create.json`, `.claude/CLAUDE.md`, `demo/` (including
  `FAILED.md`), the `/wp-yolo` build ledger and the audit findings ledger, and ends with
  `Next: <command> - <reason>`. It writes nothing, runs no WP-CLI and uses no network;
  `--json` gives the same report for scripts. Exit 0 whenever a report prints, 64 on bad usage.
