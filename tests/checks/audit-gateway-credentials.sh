#!/usr/bin/env bash
# SEC-040 — payment-gateway credentials stored at rest (agents/wp-audit-security.md).
#
# SEC-005 greps theme PHP for hardcoded secrets, but a WooCommerce payment gateway never
# keeps its live API key in a file: it lives in the `wp_options` row
# `woocommerce_<gateway_id>_settings`, a serialized array with keys like `api_key`,
# `secret_key` and `token`. Nothing that scans source code sees that row, and it is exactly
# the row a database dump, a staging snapshot, or a cloned copy carries verbatim. This test
# pins two directions: the check enumerates every settings row from the database (active or
# deactivated plugin) and reports a non-empty secret-shaped value at CRITICAL, AND it does
# not fold into the local-clone suppression list — a gateway deactivated on a clone is a
# clone artifact, but a credential still sitting in wp_options is true on production too and
# must still be reported.

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

# Every other gate reads only the SEC-040 procedure, so a word elsewhere in the agent file
# cannot keep it green.
PROC=$(awk '/^### Procedure — SEC-040/{f=1;print;next} /^##/{f=0} f' "$SEC")
[ -n "$PROC" ] || fail "$SEC: no '### Procedure — SEC-040' section"
has() { printf '%s\n' "$PROC" | grep -Fq -- "$1"; }
hasi() { printf '%s\n' "$PROC" | grep -Fiq -- "$1"; }

# --- It reads the options table, not theme source ---
has 'woocommerce_<gateway_id>_settings' || fail "SEC-040 does not name the woocommerce_<gateway_id>_settings option"
has 'get_option(' || fail "SEC-040 does not read the option with get_option"

# --- It enumerates the settings rows from the database, so deactivated gateways are covered ---
has 'SELECT option_name FROM {$wpdb->options}' \
  || fail "SEC-040 does not enumerate woocommerce_*_settings rows from the options table"
has 'esc_like( "_settings" )' || fail "SEC-040 does not match the _settings suffix"
has 'only returns gateways whose plugin is active' \
  || fail "SEC-040 does not say why payment_gateways() alone misses deactivated gateways"
has '$settings["enabled"]' || fail "SEC-040 does not read enabled from the stored settings"
if printf '%s\n' "$PROC" | grep -Fq '$gateway->enabled'; then
  fail "SEC-040 reads enabled from the loaded gateway object, which misses deactivated plugins"
fi

# --- It matches secret-shaped key names by an end-anchored pattern, not an exact list ---
# The gates read the pattern line itself, so a word dropped from the regex cannot be covered
# by the same word appearing in the prose.
SECRET_RE=$(printf '%s\n' "$PROC" | grep -F '$secret     = "' | sort -u)
[ -n "$SECRET_RE" ] || fail "SEC-040 has no \$secret pattern line"
[ "$(printf '%s\n' "$SECRET_RE" | wc -l)" -eq 1 ] \
  || fail "SEC-040's detection and scrub snippets use different \$secret patterns"
[ "$(printf '%s\n' "$PROC" | grep -cF '$secret     = "')" -eq 2 ] \
  || fail "SEC-040 must define \$secret in both the detection and the scrub snippet"
for word in 'secret' 'secret_?key' 'password' 'token' 'signature' 'api_?key' 'consumer_?key'; do
  printf '%s\n' "$SECRET_RE" | grep -Fq "|$word|" \
    || printf '%s\n' "$SECRET_RE" | grep -Fq "($word|" \
    || printf '%s\n' "$SECRET_RE" | grep -Fq "|$word)" \
    || fail "SEC-040's \$secret pattern does not cover '$word'"
done
printf '%s\n' "$SECRET_RE" | grep -Fq '$/i";' \
  || fail "SEC-040's \$secret pattern is not anchored to the end of the key"
IDENT_RE=$(printf '%s\n' "$PROC" | grep -F '$identifier = "' | sort -u)
[ "$(printf '%s\n' "$IDENT_RE" | wc -l)" -eq 1 ] && [ -n "$IDENT_RE" ] \
  || fail "SEC-040's detection and scrub snippets use different \$identifier patterns"
printf '%s\n' "$IDENT_RE" | grep -Fq 'publishable_?key' \
  || fail "SEC-040 does not classify publishable_key as an identifier"
hasi 'public by design' || fail "SEC-040 does not say a publishable key is not a secret"
has '$flags      = array( "yes", "no"' || fail "SEC-040 does not skip on/off switch values"
has 'tokenization' || fail "SEC-040 does not explain why the pattern is anchored (tokenization flag)"
has '$walk( $name, $enabled, $value, $key_path );' || fail "SEC-040 does not walk nested arrays"
has 'woocommerce-ppcp-' || fail "SEC-040 does not cover gateways that store secrets outside *_settings rows"

# --- Never print the credential value itself, including in the scrub fix ---
has 'never print the value itself' \
  || fail "SEC-040 does not say to withhold the credential value from the report"
has 'never by dumping the option' || fail "SEC-040's scrub step does not forbid dumping the option"
CODE=$(printf '%s\n' "$PROC" | awk '/^```/{f=!f;next} f')
if printf '%s\n' "$CODE" | grep -Eq 'option (get|list)|option_value|var_export|print_r|var_dump'; then
  fail "a SEC-040 code block dumps option values"
fi
has 'option not found or not an array, nothing changed' \
  || fail "SEC-040's scrub does not say when it changed nothing"

# --- Commerce gating: N/A when there is no WooCommerce, out of the denominator ---
has 'site.commerce' || fail "SEC-040 does not read site.commerce"
has 'no WooCommerce' || fail "SEC-040 does not give the N/A reason"

# --- The clone-suppression distinction is explicit, both directions ---
has 'local-clone suppression' || fail "SEC-040 does not reference the local-clone suppression list"
has 'deactivating the gateway on the' \
  || fail "SEC-040 does not say deactivation does not clear the stored credential"
has 'reported by SEC-040' \
  || fail "SEC-040 does not say the credential is still reported despite deactivation"

# --- Fix is manual, never automatic ---
has 'Fix is manual, never automatic' || fail "SEC-040 does not say the fix is manual"
hasi 'rotate the key' || fail "SEC-040 does not tell the reader to rotate the key"
hasi 'scrub' || fail "SEC-040 does not tell the reader to scrub a shared/cloned copy"

# --- The base contract this stacks on: /wp-audit Step 2.3 names the gateway-credential check
#     as one of the commerce-only checks gated by site.commerce. ---
[ -f "$AUDIT" ] || fail "$AUDIT is missing"
grep -Fq 'gateway-credential check' "$AUDIT" \
  || fail "$AUDIT: does not name the gateway-credential check among the commerce-only checks"

echo PASS
