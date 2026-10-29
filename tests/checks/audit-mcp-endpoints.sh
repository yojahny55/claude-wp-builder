#!/usr/bin/env bash
# Plugins register MCP and OAuth servers as REST routes, on by default, some accepting the
# `read` capability, with a signing secret kept in wp_options that every database sync
# copies. No audit check read the route table, so a site only found out from a screenshot.
# SEC-046 inventories those routes, probes them unauthenticated and rates them. This pins
# the pieces whose loss would turn it back into silence or into a wrong instruction.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

sec=agents/wp-audit-security.md
ref=skills/wp-audit-standards/references/sec-procedures-mcp-endpoints.md
std=skills/wp-audit-standards/SKILL.md
geo=skills/wp-audit-geo-standards/SKILL.md
dis=skills/wp-audit-run/references/dispatch.md
for f in "$sec" "$ref" "$std" "$geo" "$dis"; do [ -f "$f" ] || fail "$f missing"; done

# Catalogued where the coverage machinery reads check ids, and routed to its procedure.
grep -qE '^\| SEC-046 \|' "$sec" || fail "SEC-046 not tabulated in $sec"
grep -Fq 'sec-procedures-mcp-endpoints.md' "$sec" || fail "$sec does not send the agent to the SEC-046 procedure"
grep -Fq 'sec-procedures-mcp-endpoints.md' "$std" || fail "$std does not list the SEC-046 reference"
grep -Fq 'SEC-046' "$dis" || fail "$dis does not name SEC-046 as an owned surface"

# Severity ladder: reachable or subscriber-level is a WARNING, admin-only is INFO, none is PASS.
grep -Fq 'rest_get_server()->get_routes()' "$ref" || fail "$ref lost the route inventory"
grep -Fq 'lowest required capability is `read`' "$ref" || fail "$ref lost the read-capability WARNING"
grep -Fq 'anonymous requests refused, every capability is admin-level' "$ref" || fail "$ref lost the admin-only INFO"
grep -Fq '| No route matched | PASS |' "$ref" || fail "$ref lost the PASS row"

# The live probe respects the production gate and sends no credential.
grep -Fq 'bin/prod-gate.sh' "$ref" || fail "$ref probes production without the gate"
grep -Fq '**unauthenticated**' "$ref" || fail "$ref probe is not stated as unauthenticated"

# Fix text: the known switches, per-environment DB options, the secret, and the editable scope.
for s in wpmedia_mcp_oauth_server_enabled mcp_adapter_create_default_server elementor_mcp_enabled; do
  grep -Fq "$s" "$ref" || fail "$ref fix text lost $s"
done
grep -Fq 'repeat the `$WP option update` on every environment' "$ref" || fail "$ref does not say DB options are per environment"
grep -Fq 'rotate the' "$ref" || fail "$ref does not mention rotating the stored secret"
grep -Fq 'code_scope.editable' "$ref" || fail "$ref does not let the editable scope decide where the filter goes"
grep -Fq 'code_scope.read_only' "$ref" || fail "$ref may write under a read-only path"

# An intentional endpoint is confirmed, never auto-removed; GEO must not contradict that.
grep -Fq 'confirm this endpoint is intended' "$ref" || fail "$ref lost the confirm-intended wording"
grep -Fq 'never `remove`' "$ref" || fail "$ref does not forbid a remove instruction"
grep -Fq 'Never add an MCP surface to' "$geo" || fail "$geo may contradict SEC-046"
grep -Fq 'SEC-046' "$geo" || fail "$geo does not point to SEC-046"

# The snippet is read-only PHP, passed through a quoted heredoc (PHP is full of single quotes).
grep -Fq "\$WP eval \"\$(cat <<'PHP'" "$ref" || fail "$ref snippet is not passed through a quoted heredoc"
body=$(sed -n "/<<'PHP'/,/^PHP\$/p" "$ref")
[ -n "$body" ] || fail "$ref inventory snippet not found"
if grep -qE 'update_option|delete_option|add_option|wp_insert_|->query|wp_remote_|unlink|file_put_contents|register_rest_route' <<<"$body"; then
  fail "$ref inventory snippet writes"
fi
grep -Fq 'Never send a `POST`' "$ref" || fail "$ref probe may POST to an OAuth/agent route"

echo PASS
