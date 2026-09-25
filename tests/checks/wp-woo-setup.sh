#!/usr/bin/env bash
# /wp-woo-setup is prose that runs a script, so this pins what the prose must keep saying and
# the order the script must keep doing things in:
#   - a dry run comes before the real run;
#   - flags reach eval-file as bare words, because WP-CLI refuses an unknown --flag;
#   - the Stripe keys never enter the transcript -- the command never reads them;
#   - store-kit is synced before the script runs;
#   - the script turns HPOS on before it touches pages or payments;
#   - it keeps its Polylang step and names the audit checks it satisfies;
#   - no report line ever prints a key.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
cmd=commands/wp-woo-setup.md
script=skills/wp-woocommerce/scripts/woo-setup.php
for f in "$cmd" "$script"; do [ -r "$f" ] || fail "$f is missing or unreadable"; done

line_of() { grep -n -- "$1" "$2" | head -1 | cut -d: -f1 || true; }
dry=$(line_of '^## Step 5: Dry run first' "$cmd"); apply=$(line_of '^## Step 6: Apply' "$cmd")
[ -n "$dry" ] && [ -n "$apply" ] && [ "$dry" -lt "$apply" ] || fail "$cmd must show the dry run (Step 5) before applying (Step 6)"
sync=$(line_of 'store-kit-sync.sh' "$cmd")
[ -n "$sync" ] && [ "$sync" -lt "$dry" ] || fail "$cmd must sync store-kit before the first run of the script"
grep -q "woo-setup.php' '\${PROJECT_PATH}' dry-run" "$cmd" || fail "$cmd does not pass dry-run as a bare word"
if grep -E 'eval-file.*--(dry-run|force)' "$cmd" >/dev/null; then fail "$cmd passes a --flag to eval-file, which WP-CLI refuses"; fi
if grep -Fq "get '\${PROJECT_PATH}' stripe_" "$cmd"; then fail "$cmd reads a Stripe key into the transcript"; fi
grep -Fq '| `0` | the store matches the block' "$cmd" || fail "$cmd lost its exit 0 row"
grep -Fq '| `1` | refused' "$cmd" || fail "$cmd lost its exit 1 row"
grep -Fq 'launch state' "$cmd" || fail "$cmd does not carry the launch-state exception to force"
grep -Fq 'WP_CREATE_STRIPE_TEST_WEBHOOK_SECRET' "$cmd" || fail "$cmd never mentions the Stripe webhook secret"
# Recording a store block adds the Store tier row to a generated CLAUDE.md block, and validate
# then exits 1 on drift: Step 3 must regenerate an existing block, or the command fails its gate.
step3=$(awk '/^## Step 3:/{f=1} /^## Step 4:/{f=0} f' "$cmd")
grep -Fq "wp-config.mjs render-context '\${PROJECT_PATH}'" <<<"$step3" \
  || fail "$cmd Step 3 does not regenerate the generated CLAUDE.md block after recording the store block"
# store-kit, woo-setup.php and .wp-create.json are host paths: no container engine sees them,
# so the command reads the environment and stops before the sync, not at plugin activate.
engine=$(line_of "get '\${PROJECT_PATH}' environment.engine" "$cmd")
[ -n "$engine" ] && [ "$engine" -lt "$sync" ] && grep -Fq 'store profiles need native WP-CLI' "$cmd" \
  || fail "$cmd must read environment.engine and stop on anything but native before syncing store-kit"

h=$(grep -nE '^\s*wooset_step_hpos\(' "$script" | cut -d: -f1)
pg=$(grep -nE '^\s*wooset_step_pages\(' "$script" | cut -d: -f1)
pay=$(grep -nE '^\s*wooset_step_payments\(' "$script" | cut -d: -f1)
[ -n "$h" ] && [ -n "$pg" ] && [ -n "$pay" ] && [ "$h" -lt "$pg" ] && [ "$pg" -lt "$pay" ] \
  || fail "$script must turn HPOS on before it touches pages, and pages before payments"
grep -Fq "WP_CLI::runcommand( 'wc hpos enable'" "$script" || fail "$script no longer enables HPOS through WooCommerce's own command"
grep -Fq 'pll_set_post_language' "$script" || fail "$script lost the Polylang language step"
for id in SEC-040 SEC-039 PERF-061 PERF-062; do grep -Fq "$id" "$script" || fail "$script no longer names $id in its report"; done
if grep -nE "(WP_CLI::(line|log|warning|error)|printf|echo).*\\\$keys\[" "$script" >/dev/null; then
  fail "$script prints a Stripe key value"
fi
echo PASS
