- **Live payment keys no longer reach the transcript, and the domains import is pinned.**
  `/wp-update` looked for live gateway keys with `grep -E '(sk|rk|pk)_live_'`, which prints
  the full key line; it now counts (`grep -cE`) and reports only how many options hold one.
  `/wp-clone` listed `*_live_*` options with their values; it now lists names only.
  `bin/domains-import.sh` cloned a third-party repository's `main` unpinned and fed the CSV
  to the agent's context; it now fetches `DOMAINS_REF` (a tag or full SHA, defaulting to the
  commit last reviewed) and tells the maintainer to read the CSV diff before committing.
