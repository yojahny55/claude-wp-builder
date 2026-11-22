- **`/wp-section` has room to grow again.** The command sat 6 bytes under its 16 KB
  ceiling, so the next flag or gate would have failed `tests/checks/wp-section-run.sh`.
  The `--hybrid` overlay and the contact-section summary, each read by only one kind of
  run, moved to `skills/wp-section-run/references/` (`hybrid.md`, `summary-contact.md`),
  and the `--css` and `--defer-promotion` rationale that Step 1 repeated now lives once in
  `dispatch-rules.md`. The command is 13.5 KB, with 2.5 KB of headroom; the expanded text
  the checks read keeps every line it had.
