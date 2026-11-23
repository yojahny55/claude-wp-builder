#!/usr/bin/env bash
# /wp-woo-launch (N01 piece 5b): a store taken live by bin/woo-launch.mjs, with
# skills/wp-woocommerce/scripts/woo-launch.php on the WordPress side. This pins the contract that
# keeps it safe -- production only, keys checked and never written, a typed host, a backup before
# any write, coming soon off last, back to coming soon when the live store fails verify, and
# /wp-woo-setup never writing launch state again -- and the wiring;
# tests/checks/woo-launch-integration.sh runs it on a real store.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh
require_tool node php

cmd=commands/wp-woo-launch.md
tool=bin/woo-launch.mjs
php=skills/wp-woocommerce/scripts/woo-launch.php
setup=skills/wp-woocommerce/scripts/woo-setup.php
for f in "$cmd" "$tool" "$php"; do [ -f "$f" ] || fail "$f is missing"; done
node --check "$tool" || fail "$tool does not parse"
php -l "$php" >/dev/null || fail "$php does not lint"

# The command: gate, check, typed host, never from another command.
need_token "$cmd" 'argument-hint: "[project-path] [--url <base-url>] [--backup-out <dir>] [--revert]"'
need_token "$cmd" "bash -c 'node \"\$1/bin/wp-config.mjs\" validate \"\$2\"' _ \"\${CLAUDE_PLUGIN_ROOT}\" '\${PROJECT_PATH}'"
need_token "$cmd" "bash -c 'node \"\$1/bin/woo-launch.mjs\" \"\$2\"' _ \"\${CLAUDE_PLUGIN_ROOT}\" '\${PROJECT_PATH}'"
need_token "$cmd" "bash -c 'node \"\$1/bin/woo-launch.mjs\" \"\$2\" --confirm \"\$3\"' _ \"\${CLAUDE_PLUGIN_ROOT}\" '\${PROJECT_PATH}' '<typed host>'"
need_token "$cmd" '**type the site'"'"'s host
exactly**'
need_token "$cmd" '**Never run from `/wp-yolo`, nor from any other command.**'
need_token "$cmd" 'Do not ask the operator for a key, and never print one.'
need_token "$cmd" '4. coming soon off — last, so a step that does not land leaves a store no visitor reaches'
for c in commands/*.md; do
  [ "$c" = "$cmd" ] && continue
  if grep -F 'woo-launch.mjs' "$c" >/dev/null; then fail "$c runs woo-launch.mjs: only the operator launches a store"; fi
done

# The tool: refusals before any write, backup before apply, verify after, revert on failure.
need_token "$tool" "if (confirm !== host) refuse("
need_token "$tool" "const BLOCKING = ['STORE-005', 'STORE-007'];"
need_token "$tool" "(f.severity === 'CRITICAL' && f.check !== 'STORE-014') || BLOCKING.includes(f.check)"
need_token "$tool" "if (confirm !== null && block.launch && !block.launch.reverted_at) {"
need_token "$tool" "run('bash', [BACKUP, project, '--label', 'pre-launch'"
need_token "$tool" "const r = php('revert');"
need_token "$tool" "reverted_at: new Date().toISOString()"
host_at=$(grep -n "if (confirm !== host) refuse(" "$tool" | sed -n 1p | cut -d: -f1)
backup_at=$(grep -n "run('bash', \[BACKUP" "$tool" | sed -n 1p | cut -d: -f1)
apply_at=$(grep -n "php('apply', block.tier)" "$tool" | sed -n 1p | cut -d: -f1)
record_at=$(grep -n "setLaunch({ at: new Date().toISOString(), backup })" "$tool" | sed -n 1p | cut -d: -f1)
[ -n "$host_at" ] && [ -n "$backup_at" ] && [ -n "$apply_at" ] && [ -n "$record_at" ] \
  && [ "$host_at" -lt "$backup_at" ] && [ "$backup_at" -lt "$apply_at" ] && [ "$apply_at" -lt "$record_at" ] \
  || fail "$tool must check the host, then back up, then apply, then record (lines $host_at $backup_at $apply_at $record_at)"
code=0; node "$tool" /nonexistent --revert --confirm x >/dev/null 2>&1 || code=$?
[ "$code" = 64 ] || fail "$tool accepted --revert with --confirm (exit $code, not 64)"

# The PHP: production, live prefixes, real Turnstile keys, never a key written, coming soon last.
need_token "$php" "'production' === \$env"
need_token "$php" "foreach ( array( 'secret_key', 'publishable_key', 'webhook_secret' ) as \$field ) {"
need_token "$php" "const WOOLAUNCH_TURNSTILE_TEST_KEY = '/^[123]x0{20,}[A-F]{2}\$/';"
for k in 1x00000000000000000000AA 2x00000000000000000000AB 1x00000000000000000000BB 3x00000000000000000000FF 1x0000000000000000000000000000000AA; do
  php -r 'exit( preg_match( "/^[123]x0{20,}[A-F]{2}$/", $argv[1] ) ? 0 : 1 );' "$k" || fail "Cloudflare's test key $k passes as a real one"
done
need_token "$tool" "const unknown = report.unmeasured.filter((u) => u.check !== 'STORE-004');"
need_token "$php" "woolaunch_refuse( \"\$woolaunch_fail precondition(s) fail: nothing was written\" );"
if grep -E "update_option\( *'cfturnstile_(key|secret)'|WPConfigTransformer|define\( *'(STORE_KIT_STRIPE|CF_TURNSTILE)" "$php" >/dev/null; then
  fail "$php writes a key: launch checks the keys in wp-config.php and never writes one"
fi
last=$(grep -n "woolaunch_option( 'coming-soon', 'woocommerce_coming_soon', 'no' )" "$php" | sed -n 1p | cut -d: -f1)
for step in "'stripe:testmode'" "'stripe:enabled'" "'cod:enabled'" "'turnstile:checkout'"; do
  at=$(grep -n "$step" "$php" | sed -n 1p | cut -d: -f1)
  [ -n "$at" ] && [ -n "$last" ] && [ "$at" -lt "$last" ] || fail "$php must turn coming soon off after $step"
done

# Setup never writes launch state on a launched store, and the block still only says "test".
need_token "$setup" "\$held     = 'launch' === \$kind && ( \$c['orders'] || \$c['launched'] );"
need_token "$setup" "'launched' => isset( \$wooset_store['launch'] ) && is_array( \$wooset_store['launch'] ),"
need_token bin/lib/manifest.mjs "if (store.payments.mode !== 'test') p.push("
need_token bin/lib/manifest.mjs "unknownKeys(launch, ['at', 'backup', 'reverted_at'], 'store.launch', p);"

# Docs: the store skill no longer says no command launches; the live payment is a ceiling.
need_token skills/wp-woocommerce/SKILL.md '`/wp-woo-launch`'
need_token docs/known-ceilings.md '**A launch is never proven with a real payment.**'

echo "PASS: /wp-woo-launch checks before it writes, backs up, launches in order, and setup keeps out"
