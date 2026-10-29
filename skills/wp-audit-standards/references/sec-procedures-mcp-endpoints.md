# Security procedure — exposed MCP / OAuth / agent endpoints (SEC-046)

Part of the `wp-audit-standards` skill. Read before SEC-046. The agent's Tier 2 table holds the row; this file holds the inventory snippet, the live probe, the severity ladder and the fix text.

## Contents

- Inventory of routes
- Live probe
- Severity
- Fix text

### Procedure — SEC-046 (REST routes that serve MCP, OAuth or agent servers)

Plugins now register Model Context Protocol servers and OAuth servers as REST routes (for
example an SEO plugin's OAuth MCP server and an "MCP adapter" default server). They are on by
default, have no admin switch, and some accept the `read` capability, which every subscriber
holds. They also keep a signing secret in `wp_options`, and a database pull or push copies it
to every environment. Nothing else in the audit reads the route table, so nothing else sees them.

**Inventory.** One read-only `$WP eval` over the registered routes. It matches a route whose
path contains `mcp`, `oauth`, `a2a` or `agent` as a whole segment, skips the namespace index
routes, and for each handler reports the owning plugin (the file of its callback, when
reflection can read it) and the capabilities its permission callback tests (read from the
callback's own source lines; empty means unknown, not "none").

```bash
$WP eval '
// --- SEC-046 inventory: read-only, it only reads the registered routes ---
$hit = '#(^|[/_-])(mcp|oauth|a2a|agents?)([/_-]|$)#i';
$out = [];
$ns = array_map( function ( $n ) { return '/' . $n; }, rest_get_server()->get_namespaces() );
foreach ( rest_get_server()->get_routes() as $route => $handlers ) {
	if ( ! preg_match( $hit, $route ) || in_array( $route, $ns, true ) ) { continue; }
	foreach ( $handlers as $h ) {
		$cb   = $h['permission_callback'] ?? null;
		$file = '';
		$caps = [];
		$anon = false;
		try {
			if ( $cb === null || $cb === '__return_true' ) {
				$anon = true;
			} elseif ( $cb instanceof Closure || is_string( $cb ) || is_array( $cb ) ) {
				$rf = is_array( $cb )
					? new ReflectionMethod( is_object( $cb[0] ) ? get_class( $cb[0] ) : $cb[0], $cb[1] )
					: new ReflectionFunction( $cb );
				$file = (string) $rf->getFileName();
				$src  = $file && is_readable( $file )
					? implode( '', array_slice( file( $file ), $rf->getStartLine() - 1, $rf->getEndLine() - $rf->getStartLine() + 1 ) )
					: '';
				if ( preg_match_all( '/current_user_can\(\s*[\'"]([a-z_]+)[\'"]/', $src, $m ) ) { $caps = array_unique( $m[1] ); }
				if ( ! $caps && preg_match( '/return\s+true\s*;/', $src ) ) { $anon = true; }
			}
		} catch ( Throwable $e ) { /* not reflectable: caps stay empty = unknown */ }
		if ( ! $file ) { // owner of an open route: the handler's file, since __return_true lives in core
			try {
				$hc   = $h['callback'] ?? null;
				$rf   = is_array( $hc ) ? new ReflectionMethod( is_object( $hc[0] ) ? get_class( $hc[0] ) : $hc[0], $hc[1] ) : new ReflectionFunction( $hc );
				$file = (string) $rf->getFileName();
			} catch ( Throwable $e ) { /* owner unknown */ }
		}
		$plugin = '';
		if ( $file && preg_match( '#/plugins/([^/]+)/#', str_replace( '\\', '/', $file ), $p ) ) { $plugin = $p[1]; }
		$out[] = [
			'route'   => $route,
			'methods' => implode( ',', array_keys( $h['methods'] ?? [] ) ),
			'plugin'  => $plugin,
			'caps'    => array_values( $caps ),
			'anon'    => $anon,
		];
	}
}
echo wp_json_encode( $out );
// --- end SEC-046 inventory ---
'
```

`anon: true` means the permission callback is `__return_true`, absent, or a function whose
body only returns `true`. Callbacks that delegate to another function read as `caps: []`
and `anon: false`: that is "unknown", and the live probe below is what settles it. Route
patterns with a regex group (`(?P<id>...)`) are listed but not probed.

**Live probe.** Static reading cannot see a rewrite, a firewall rule or a filter that turns
a route off at request time, so reachability is measured. Send each listed concrete route
**unauthenticated**: `GET` when the handler declares it, otherwise `POST` with body `{}`.
Nothing else is sent, no token is ever supplied, and a `POST` to an MCP route is an
initialisation request, not an action.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' --max-time 15 -A "Mozilla/5.0" \
  "https://<host>/wp-json<route>"
```

- Requests to a production host go through `bin/prod-gate.sh`, exactly as the agent's Rules say.
  When the gate exits `4`, the probe is `UNMEASURED` for that host; the static inventory
  still counts. A local site is not gated.
- `2xx` is **reachable**. `401` or `403` is gated. `404` means the route is not served.
  A `403`/challenge page from a WAF is not the site's answer: record it as gated-by-edge, not as a pass.
- Probe the host the audit measures (production when confirmed in `/wp-audit` Step 2.3,
  otherwise the local URL), and say which one in the evidence line.

**Severity.**

| Finding | Severity |
|---|---|
| No route matched | PASS |
| Any route answered `2xx` to an anonymous request, or whose permission callback is open | WARNING |
| Any route whose lowest required capability is `read` (subscriber level), even when anonymous requests are refused | WARNING |
| Present, anonymous requests refused, every capability is admin-level (`manage_options` and similar) | INFO |
| Present, capability unknown and the probe was `UNMEASURED` | INFO, with the probe command as the `UNVERIFIED` line |

Report the route, methods, owning plugin, capabilities, anonymous status code and which host
was probed. An endpoint that is public on purpose is a choice, not a defect: the message always
says `confirm this endpoint is intended`, never `remove`. If `.claude/CLAUDE.md` or the GEO
surfaces record a deliberate public MCP server, say so and keep the finding at the measured
severity only when the capability or reachability is wider than that record.

**Fix text.** `Fix: manual`, `Owner: code` for a filter and `Owner: setting` for a DB option,
because switching a server off is the owner's decision. Name the switch the plugin offers; the
known ones are examples, not a list to trust blindly:

- Rank Math's OAuth MCP server: `add_filter( 'wpmedia_mcp_oauth_server_enabled', '__return_false' );`
- The MCP adapter's default server: `add_filter( 'mcp_adapter_create_default_server', '__return_false' );`
- Elementor's MCP routes: `$WP option update elementor_mcp_enabled 0`

Where a filter goes is decided by `code_scope.editable`: the child theme's `functions.php`
or `inc/` (a `prefix_` function hooked on the filter), or the site's own plugin. With neither
editable, the finding stays `Fix: manual` and names the vendor setting or a request to the
vendor; never write under a `code_scope.read_only` path. A DB option is not code, so it
does not travel with a deploy: repeat the `$WP option update` on every environment (local,
staging, production), and re-check after each database pull or push, which can restore the old value.

Some of these plugins store a signing secret in `wp_options` (a JWT secret, for example). The
secret rides every database pull and push, so if the endpoint was ever reachable, rotate the
secret after switching the server off. Never print the secret in the report; say which option
holds it.
