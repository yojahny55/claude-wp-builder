#!/usr/bin/env bash
# /wp-woo-verify (N01 piece 4, second half): a store checked from outside by bin/woo-verify.mjs,
# with skills/wp-woocommerce/scripts/woo-verify.php on the WordPress side. This pins the
# contract that keeps it safe -- no writes without --order, --order only on a local store with
# no other order, the test order cancelled before it is deleted -- and the wiring;
# tests/checks/woo-verify-integration.sh runs it on a real store.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh
require_tool node php

cmd=commands/wp-woo-verify.md
tool=bin/woo-verify.mjs
php=skills/wp-woocommerce/scripts/woo-verify.php
for f in "$cmd" "$tool" "$php"; do [ -f "$f" ] || fail "$f is missing"; done
node --check "$tool" || fail "$tool does not parse"
php -l "$php" >/dev/null || fail "$php does not lint"

# The command: gate, the call, the order's conditions, the report.
need_token "$cmd" 'argument-hint: "[project-path] [--url <base-url>] [--order] [--read-only] [--tier catalog|store|full]"'
need_token "$cmd" "bash -c 'node \"\$1/bin/wp-config.mjs\" validate \"\$2\"' _ \"\${CLAUDE_PLUGIN_ROOT}\" '\${PROJECT_PATH}'"
need_token "$cmd" "bash -c 'node \"\$1/bin/woo-verify.mjs\" \"\$2\"' _ \"\${CLAUDE_PLUGIN_ROOT}\" '\${PROJECT_PATH}'"
need_token "$cmd" 'No `store` block: stop'
need_token "$cmd" 'Anything but `native`: stop'
need_token "$cmd" '`--order` is refused, before anything runs and with nothing written, unless the site is
local, the tier sells, cash on delivery is on, and the store has no other order — and with'
need_token "$cmd" 'WooCommerce sends the order'"'"'s
emails for real'
need_token "$cmd" '| `2` | could not measure: WP-CLI or the site did not answer |'

# The tool: refused before anything runs; nothing left behind; drift is setup's would-set.
need_token "$tool" "if (!local) refuse.push(\`the site reads as \${facts.environment}, not local\`);"
need_token "$tool" "not this WordPress (\${new URL(facts.home).hostname}) or loopback"
need_token "$tool" "if (facts.orders > 0) refuse.push("
need_token "$tool" "const drift = planLines.filter((l) => l.startsWith('would-set '));"
need_token "$tool" "const r = helper('forget-session', key);"
need_token "$tool" "sameSite = forget(token) > 0;"
need_token "$tool" "} else if (!sameSite) {"
need_token "$tool" "rejectUnauthorized: !local"
need_token "$tool" "const plan = block ? evalFile(SETUP, project, 'dry-run') : { code: 0, out: '' };"
# --read-only writes nothing, not even the cart session; --tier is only for a store with no block,
# and such a store gets no order (its address is the block's).
need_token "$tool" "line('skip', 'cart', 'read-only: the Store API cart would open a session on the store');"
need_token "$tool" "if (order && readOnly) usage("
need_token "$tool" "if (block && tierFlag) usage("
need_token "$tool" "if (!block) refuse.push("
code=0; node "$tool" /nonexistent --order --read-only >/dev/null 2>&1 || code=$?
[ "$code" = 64 ] || fail "$tool accepted --order with --read-only (exit $code, not 64)"
# --order's refusal comes before the first request to the site.
refuse_at=$(grep -n "process.stdout.write(\`refused: --order" "$tool" | sed -n 1p | cut -d: -f1)
first_req=$(grep -n "await request(at('/'))" "$tool" | sed -n 1p | cut -d: -f1)
[ -n "$refuse_at" ] && [ -n "$first_req" ] && [ "$refuse_at" -lt "$first_req" ] \
  || fail "$tool must refuse --order before it sends anything to the site"

# The PHP: only a local site, only the verification's own order, cancelled, then deleted for good.
need_token "$php" "const WOOVERIFY_EMAIL = 'woo-verify@example.test';"
need_token "$php" "if ( 'local' !== wp_get_environment_type() ) {"
need_token "$php" "if ( WOOVERIFY_EMAIL !== \$order->get_billing_email() || 'store-api' !== \$order->get_created_via() ) {"
need_token "$php" "add_filter( 'woocommerce_email_enabled_cancelled_order', '__return_false' );"
cancel_at=$(grep -n "\$order->update_status( 'cancelled'" "$php" | sed -n 1p | cut -d: -f1)
delete_at=$(grep -n "\$order->delete( true )" "$php" | sed -n 1p | cut -d: -f1)
[ -n "$cancel_at" ] && [ -n "$delete_at" ] && [ "$cancel_at" -lt "$delete_at" ] \
  || fail "$php must cancel the order (stock and sales back) before deleting it for good"

# Wiring.
need_token .github/workflows/ci.yml 'bash tests/checks/woo-verify-integration.sh'
need_token BACKLOG.md 'tests/checks/woo-verify-integration.sh'
need_token commands/wp-woo-setup.md '`/wp-woo-verify` checks it from outside'

echo "PASS: /wp-woo-verify checks a store without writing, and its --order is local, its own, and removed"
