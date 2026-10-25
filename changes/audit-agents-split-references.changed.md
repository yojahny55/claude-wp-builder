- **The two largest audit agents load far less per dispatch.** `wp-audit-performance` (84 KB) and
  `wp-audit-security` (79 KB) carried every procedure, script, fix recipe and the plugin
  inventory in the file the loader reads whole on each invocation, although a given run needs a
  few of them. The check tables, the report contract and the rules stay in the agent; the long
  per-check procedures moved verbatim to `skills/wp-audit-standards/references/perf-*.md` and
  `sec-*.md`, and each agent carries an index saying which file to read before which check. No
  check code was removed or reworded, and the checks that grep the agents now read the agent
  plus its references through `tests/checks/lib/agent-text.sh`.
