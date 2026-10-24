- **Named remote environments, EnvSync recipes and a measured DB dump in `/wp-clone`.** The
  manifest takes an optional `environments` map (`role` local, staging or prod, `url`, and a
  token-free `sync` block) that `validate` checks and `wp-config.mjs env-set` writes;
  `/wp-adopt` registers the environments `wp envsync env list` reports. The production gates
  of `/wp-update`, `/wp-clone` and `/wp-audit` read `role: "prod"` instead of comparing URLs
  and keep the URL rule only when there are no `environments`. `wp-environments` gains the
  EnvSync recipes (pull by scope, push only what is missing, volatile tables, token
  handling). `/wp-clone` Path A measured nothing before dumping: it now lists the ten heaviest
  tables, offers to skip log, queue, session and cache tables, and exports with
  `--single-transaction` through `gzip`, downloaded with a resumable `rsync --partial`.
