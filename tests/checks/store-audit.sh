#!/usr/bin/env bash
# /wp-audit's store category (N01 piece 5, first half): wp-audit-store and its STORE-NNN
# catalog, measured by bin/store-audit.mjs with bin/woo-verify.mjs and
# skills/wp-woocommerce/scripts/store-audit.php. This pins what keeps it honest -- the catalog
# and the tool agree id for id, a site without WooCommerce is never scored for a store, a
# report-only run writes nothing -- and the wiring; tests/checks/store-audit-integration.sh
# runs it on a real store.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh
require_tool node php python3

agent=agents/wp-audit-store.md
tool=bin/store-audit.mjs
php=skills/wp-woocommerce/scripts/store-audit.php
for f in "$agent" "$tool" "$php"; do [ -f "$f" ] || fail "$f is missing"; done
node --check "$tool" || fail "$tool does not parse"
php -l "$php" >/dev/null || fail "$php does not lint"

# The catalog: 14 table rows, each id once, and the tool reports exactly those ids.
rows=$(grep -oE '^\| STORE-[0-9]{3} \|' "$agent" | sed 's/[| ]//g')
[ "$(printf '%s\n' "$rows" | grep -c .)" = 14 ] || fail "$agent tabulates $(printf '%s\n' "$rows" | grep -c .) STORE rows, not 14"
[ -z "$(printf '%s\n' "$rows" | sort | uniq -d)" ] || fail "$agent tabulates a STORE id twice"
need_token "$tool" "const IDS = Array.from({ length: 14 }, (_, i) => \`STORE-\${String(i + 1).padStart(3, '0')}\`);"
for id in STORE-001 STORE-002 STORE-003 STORE-004; do need_token "$tool" "'$id'"; done
for n in 005 006 007 008 009 010 011 012 013 014; do
  grep -F "'STORE-$n'" "$php" >/dev/null || fail "$php never reports STORE-$n"
done
node --input-type=module -e '
import { readCatalog, canonicalCategory, classifyUnmeasured } from "./bin/lib/audit-schema.mjs";
const ids = readCatalog("store");
if (ids.length !== 14) { console.error("readCatalog(store) read " + ids.length + " ids"); process.exit(1); }
if (canonicalCategory("wp-audit-store") !== "store") { console.error("wp-audit-store is not the store category"); process.exit(1); }
if (classifyUnmeasured("report-only run: the cart check opens a Store API cart session, a write this run may not make") !== "report-only") process.exit(1);
// The fifth reason names the run and the write: the mode alone is not a reason.
if (classifyUnmeasured("report-only") !== null) { console.error("a bare report-only is accepted as a reason"); process.exit(1); }
' || fail "the audit schema does not read the store catalog, or accepts the wrong report-only reasons"
node --input-type=module -e 'import { AUDIT_CATEGORIES } from "./bin/lib/manifest.mjs"; process.exit(AUDIT_CATEGORIES.includes("store") ? 0 : 1);' \
  || fail "bin/lib/manifest.mjs does not offer the store category"

# The tool writes nothing it does not delete, and nothing at all with --read-only.
need_token "$tool" "if (readOnly) vArgs.push('--read-only');"
need_token "$tool" "unmeasured('STORE-004', 'report-only run: the cart check opens a Store API cart session, a write this run may not make');"
need_token "$tool" "if (engine !== 'native') nothing("
# A check passes only on a woo-verify row that says so: a run that crashed printed none, and
# only exit 0 or 1 is a run that reported its checks.
need_token "$tool" "const verifyRan = v.status === 0 || v.status === 1;"
for id in STORE-001 STORE-002 STORE-003 STORE-004; do need_token "$tool" "passOrUnmeasured('$id'"; done
if grep -E "^\s*(\} )?else pass\('STORE-00[1-4]'\)" "$tool" >/dev/null; then fail "$tool passes a woo-verify check with no row for it"; fi
if grep -E "update_option|delete_option|wp_insert_post|wp_update_post|->save\(|->delete\(|set_transient|->query\(" "$php" >/dev/null; then
  fail "$php writes to the store; it only reads"
fi
code=0; node "$tool" >/dev/null 2>&1 || code=$?
[ "$code" = 64 ] || fail "$tool with no project exited $code, not 64"

# The gate: a site without WooCommerce is never scored for a store.
. tests/checks/lib/expand-command.sh; expand_command commands/wp-audit.md
c=$EXPANDED
need_token "$c" '**`store` applies only to a WooCommerce site.**'
need_token "$c" 'prints `store: N/A (no WooCommerce)`'
need_token "$c" 'On a site without WooCommerce the store category is not
offered: it is never reported `NEVER RUN`'
need_token "$c" '`STORE-*` in
`agents/wp-audit-store.md`'
need_token "$c" '- `wp-audit-store` — store checks, only when `site.commerce` is `woocommerce`'
need_token "$c" '**Store fixes:** none are applied here.'
need_token "$c" '| needs a write a report-only run may not make |'
need_token "$agent" "--read-only\` when the prompt says \`Report-only: yes\`"

# Wiring.
need_token .github/workflows/ci.yml 'bash tests/checks/store-audit-integration.sh'
need_token BACKLOG.md 'tests/checks/store-audit-integration.sh'
need_token README.md '| `--store` |'

echo "PASS: the store audit's catalog and tool agree, it skips a site without WooCommerce, and report-only writes nothing"
