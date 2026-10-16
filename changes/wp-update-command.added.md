- **`/wp-update` updates core, plugins and themes behind a backup and a verification pass.** Updating a store by
  hand meant remembering the order (backup, core, db update, plugins, migrations, checks) and
  rediscovering the traps: `tar --exclude` after the operands has no effect, premium plugins
  licensed to another domain fail with `Unauthorized` and must be skipped rather than bypassed,
  and a half-updated pair such as Elementor and Elementor Pro leaves version skew. The command
  backs up outside the docroot, runs WooCommerce and Elementor migrations, verifies pages and
  `debug.log`, keeps a clone's mail and gateways disabled, and prints the rollback.
