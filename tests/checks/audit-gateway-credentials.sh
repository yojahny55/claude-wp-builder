#!/usr/bin/env bash
# SEC-040 — payment-gateway credentials stored at rest (agents/wp-audit-security.md).
#
# SEC-005 greps theme PHP for hardcoded secrets, but a WooCommerce payment gateway never
# keeps its live API key in a file: it lives in the `wp_options` row
# `woocommerce_<gateway_id>_settings`, a serialized array with keys like `api_key`,
# `secret_key` and `token`. Nothing that scans source code sees that row, and it is exactly
# the row a database dump, a staging snapshot, or a cloned copy carries verbatim. This test
# pins two directions: the check enumerates enabled gateways and reports a non-empty
# credential value at CRITICAL, AND it does not fold into the local-clone suppression list —
# a gateway deactivated on a clone is a clone artifact, but a credential still sitting in
# wp_options is true on production too and must still be reported.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail() { echo "FAIL: $1"; exit 1; }

SEC=agents/wp-audit-security.md
AUDIT=commands/wp-audit.md

[ -f "$SEC" ] || fail "$SEC is missing"
[ -r "$SEC" ] || fail "$SEC exists but cannot be read"

# --- SEC-040 is tabulated and CRITICAL ---
grep -Eq '^\| SEC-040 \|' "$SEC" || fail "$SEC: SEC-040 is not tabulated"
grep -E '^\| SEC-040 \|' "$SEC" | grep -Fq 'CRITICAL' \
  || fail "$SEC: SEC-040's table row is not CRITICAL"

# --- It reads the options table, not theme source ---
grep -Fq 'woocommerce_' "$SEC" || fail "$SEC: SEC-040 does not name the woocommerce_<gateway>_settings option"
grep -Fq 'get_option' "$SEC" || fail "$SEC: SEC-040 does not read the option with get_option"

# --- It enumerates enabled gateways, not a fixed list of plugin slugs ---
grep -Fq 'WC_Payment_Gateways' "$SEC" \
  || fail "$SEC: SEC-040 does not enumerate gateways via WC_Payment_Gateways"
grep -Fq 'enabled' "$SEC" || fail "$SEC: SEC-040 does not check whether the gateway is enabled"

# --- It checks credential-shaped keys ---
for key in api_key secret_key token publishable_key; do
  grep -Fq "$key" "$SEC" || fail "$SEC: SEC-040 does not check the credential-shaped key '$key'"
done

# --- Never print the credential value itself ---
grep -Fq 'never print the value itself' "$SEC" \
  || fail "$SEC: SEC-040 does not say to withhold the credential value from the report"

# --- Commerce gating: N/A when there is no WooCommerce, out of the denominator ---
grep -Fq 'site.commerce' "$SEC" || fail "$SEC: SEC-040 does not read site.commerce"
grep -Fq 'no WooCommerce' "$SEC" || fail "$SEC: SEC-040 does not give the N/A reason"

# --- The clone-suppression distinction is explicit, both directions ---
grep -Fq 'local-clone suppression' "$SEC" \
  || fail "$SEC: SEC-040 does not reference the local-clone suppression list"
grep -Fq 'deactivating the gateway on the' "$SEC" \
  || fail "$SEC: SEC-040 does not say deactivation does not clear the stored credential"
grep -Fq 'reported by SEC-040' "$SEC" \
  || fail "$SEC: SEC-040 does not say the credential is still reported despite deactivation"

# --- Fix is manual, never automatic ---
grep -Fq 'Fix is manual, never automatic' "$SEC" \
  || fail "$SEC: SEC-040 does not say the fix is manual"
grep -Fiq 'rotate the key' "$SEC" || fail "$SEC: SEC-040 does not tell the reader to rotate the key"
grep -Fiq 'scrub' "$SEC" || fail "$SEC: SEC-040 does not tell the reader to scrub a shared/cloned copy"

# --- The base contract this stacks on: /wp-audit Step 2.3 already names the gateway-credential
#     check as one of the commerce-only checks gated by site.commerce. ---
if [ -f "$AUDIT" ]; then
  grep -Fq 'gateway-credential check' "$AUDIT" \
    || fail "$AUDIT: does not name the gateway-credential check among the commerce-only checks"
fi

echo PASS
