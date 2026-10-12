- **Re-running the browser suite against the same site no longer fails.** `bin/audit-suite.sh`
  rewrites `baseURL` and `siteName` in the kept `audit.config.js` and asserted that the text
  changed, so a second `/wp-audit --suite` against the URL and site name the config already
  held stopped with "has no assignable baseURL" and measured nothing until someone edited the
  config by hand. The guard now asserts that the pattern matched: a same-value re-run passes,
  and a config with no `baseURL` still fails. `tests/checks/audit-suite.sh` covers both.
