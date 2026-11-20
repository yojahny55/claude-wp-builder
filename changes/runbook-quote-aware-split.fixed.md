- **The production runbook no longer splits a command on an operator inside quotes.**
  `bin/audit-runbook.mjs` split each recorded command on `|`, `;`, `&&` and `||` without
  reading quotes, so a value such as `"%title% | %sitename%"` received a stray `--url=` inside
  the quoted text. The split is now quote-aware; an ordinary pipeline keeps one `--url` per
  `wp` call.
