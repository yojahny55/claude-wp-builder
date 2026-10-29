- **`/wp-audit` renders a production runbook from its replay record.** Every applied fix now
  appends a typed entry to `<out>/replay.json` (`kind`: code, db-option, post-meta,
  wp-config, server, post-deploy; the exact command or file, the previous value or backup,
  and a `needs_server_rule` flag), and `bin/audit-runbook.mjs` renders it as
  `<out>/runbook-<date>.md` in the order production needs: pre-deploy checks, code and theme
  activation, wp-config, WP-CLI with a production `--url`, server rules, post-deploy
  (Elementor `flush-css`, page-cache purge) and verification curls. Before, the replay log
  covered settings only and every session wrote its "for production" list and its server
  steps by hand. Those lists reported `.htaccess` fixes as done for an nginx production,
  missed the nginx `location` that PHP-served endpoints such as `/llms.txt` and
  `/.well-known/` need, and let a physical `robots.txt` carrying the local host shadow the
  dynamic route. The runbook takes its Apache and nginx snippets from the new
  `skills/wp-audit-run/references/server-rules.md`, marks each one not applied, rewrites
  commands to the production URL, and refuses to write a runbook that would carry a local
  host. Named environments gain optional `server` and `page_cache` fields
  (`wp-config.mjs env-set --server= --page-cache=`).
