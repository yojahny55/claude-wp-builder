- **`/wp-audit` keeps a replay log and a resumable run state on disk.** Setting and
  database fixes were printed once at the end and then lost, per-agent reports lived only
  in the conversation, and a bulk database fix kept no old value. Now each such fix is
  appended to `<out>/replay.json` with its WP-CLI command, previous value and per-environment
  `applied_on` flags, and the closing list is printed from that file. Each agent's full
  report is written to `<out>/agents/<agent>.md` before synthesis (the parent receives only
  the findings JSON and a short summary), `<out>/run-state.json` lets a run resume after
  `/clear`, and a fix touching more than 25 rows dumps the previous values to
  `<out>/backups/` first. A `--replay <env>` flag is documented as future work.
