- **`/wp-audit` reports MCP, OAuth and agent servers exposed over REST (SEC-046).** Plugins
  now register MCP and OAuth servers as REST routes, on by default, some accepting the
  subscriber-level `read` capability, with a signing secret in `wp_options` that every
  database sync copies. No check read the route table, so an owner found them by chance.
  SEC-046 lists the matching routes with their owning plugin and required capability, probes (GET only)
  each one unauthenticated (through the production gate), and rates it: WARNING when
  reachable or `read`-level, INFO when admin-only, PASS when none. The fix names the known
  switches (two plugin filters, an Elementor option), says a filter goes where
  `code_scope.editable` allows and a DB option must be repeated per environment, and asks to
  rotate a stored secret that was ever exposed. An intentional public endpoint is "confirm
  intended", never "remove", and the GEO guidance now says so.
