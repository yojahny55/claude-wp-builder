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

set -euo pipefail
cd "$(dirname "$0")/../.."

fail() { echo "FAIL: $1"; exit 1; }

SEC=agents/wp-audit-security.md
AUDIT=commands/wp-audit.md

[ -f "$SEC" ] || fail "$SEC is missing"
[ -r "$SEC" ] || fail "$SEC exists but cannot be read"

# --- SEC-040 is tabulated and CRITICAL ---
ROW=$(grep -E '^\| SEC-040 \|' "$SEC") || fail "$SEC: SEC-040 is not tabulated"
grep -Fq 'CRITICAL' <<<"$ROW" || fail "$SEC: SEC-040's table row is not CRITICAL"

# Every other gate reads only the SEC-040 procedure, so a word elsewhere in the agent file
# cannot keep it green.
PROC=$(awk '/^### Procedure — SEC-040/{f=1;print;next} /^##/{f=0} f' "$SEC")
[ -n "$PROC" ] || fail "$SEC: no '### Procedure — SEC-040' section"
# Here-strings, not `printf | grep -q`: under pipefail an early grep exit makes printf die of
# SIGPIPE on a long section, and the gate fails on text that is there. Every command that may
# fail is the left side of `||` or an `if` condition, so `set -e` never aborts on its own.
has() { grep -Fq -- "$1" <<<"$PROC"; }
hasi() { grep -Fiq -- "$1" <<<"$PROC"; }

# --- It enumerates rows from the database, so deactivated gateways are covered (the behavior
#     test below runs the enumeration; this pins the reason it must not use the registry) ---
has 'woocommerce_<gateway_id>_settings' || fail "SEC-040 does not name the woocommerce_<gateway_id>_settings option"
has 'only returns gateways whose plugin is active' \
  || fail "SEC-040 does not say why payment_gateways() alone misses deactivated gateways"
if grep -Fq '$gateway->enabled' <<<"$PROC"; then
  fail "SEC-040 reads enabled from the loaded gateway object, which misses deactivated plugins"
fi

# --- Behavior: run both snippets against a stubbed options table ---
# Four rounds of text gates each passed a pattern that missed a real key name, and a gate on
# the text cannot see a snippet that prints the value, walks nothing, or never saves. So the
# two `$WP eval '...'` blocks are extracted from the procedure and executed with php against a
# fixture (tests/checks/lib/sec040-gateway-credentials-behavior.php): the detection must
# report exactly the expected CRITICAL and INFO keys without printing any secret, and the
# scrub must blank exactly those keys, keep everything else, and save only when it changed
# something. php is on the CI runner; without it this check fails rather than skips, because
# the gates below no longer pin the classifier on their own.
command -v php >/dev/null 2>&1 || fail "php not found — SEC-040's behavior test cannot run"
tmp=$(mktemp -d) || fail "mktemp failed"
trap 'rm -rf "$tmp"' EXIT
awk -v dir="$tmp" '
  $0 == "$WP eval '"'"'" { n++; f = 1; next }
  f && $0 == "'"'"'"     { f = 0; next }
  f                      { print > (dir "/snippet" n ".php") }
  END                    { print n + 0 > (dir "/count") }' <<<"$PROC"
[ "$(cat "$tmp/count")" -eq 2 ] \
  || fail "SEC-040 must hold exactly two \$WP eval blocks (detection, scrub); found $(cat "$tmp/count")"
for n in 1 2; do
  { printf '<?php\n'; cat "$tmp/snippet$n.php"; } > "$tmp/lint$n.php"
  lint=$(php -l "$tmp/lint$n.php" 2>&1) || fail "SEC-040 snippet $n does not parse: $lint"
done
# The classifier block must be byte-identical in both snippets, or the scrub could blank a
# different set of keys than the detection reports.
for n in 1 2; do
  awk '/^\/\/ --- SEC-040 classifier:/{f=1} f{print} /^\/\/ --- end SEC-040 classifier ---$/{f=0}' \
    "$tmp/snippet$n.php" > "$tmp/classifier$n"
  grep -q '^\$classify = function' "$tmp/classifier$n" \
    || fail "SEC-040 snippet $n has no \$classify block between the classifier markers"
done
cmp -s "$tmp/classifier1" "$tmp/classifier2" \
  || fail "SEC-040's detection and scrub snippets carry different \$classify blocks"
behavior=tests/checks/lib/sec040-gateway-credentials-behavior.php
[ -f "$behavior" ] || fail "$behavior is missing"
out=$(php "$behavior" "$tmp/snippet1.php" "$tmp/snippet2.php" 2>&1) \
  || fail "SEC-040 snippets misbehave:
${out:-(php exited non-zero with no output)}"

hasi 'public by design' || fail "SEC-040 does not say a publishable key is not a secret"
has 'Coverage is limited to' || fail "SEC-040's Pass criterion does not bound its coverage"

# --- Never print the credential value itself, including in the scrub fix ---
has 'never print the value itself' \
  || fail "SEC-040 does not say to withhold the credential value from the report"
has 'never by dumping the option' || fail "SEC-040's scrub step does not forbid dumping the option"
CODE=$(awk '/^```/{f=!f;next} f' <<<"$PROC")
if grep -Eq 'option (get|list)|option_value|var_export|print_r|var_dump' <<<"$CODE"; then
  fail "a SEC-040 code block dumps option values"
fi

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
