- **Documented exit-code table for every `bin/*.mjs` tool.** `bin/lib/exit-codes.mjs`
  (`COMMON` for new tools, `TOOLS` with the codes each existing tool really returns) and
  `docs/exit-codes.md` record them without renumbering anything, since commands and checks
  read the numbers in prose. `tests/checks/exit-code-table.sh` fails when a tool exits with
  an undeclared code or the table and the doc drift apart.
