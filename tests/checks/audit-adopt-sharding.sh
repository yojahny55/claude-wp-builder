#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
. tests/checks/lib/expand-command.sh; expand_command commands/wp-audit.md
a=$EXPANDED
has() { grep -Fq -- "$2" "$1" || fail "$1 lacks: $2"; }
has $a "wp-config.mjs drift"
has $a "Validation checks the manifest's shape, not whether it is true."
has $a "Exit \`4\`"
has $a "Re-adopt it"
has $a "Quiet WP-CLI:"
has $a "bin/wp-quiet.sh"
has $a "it is never written into \`.wp-create.json\`"
has $a "**One defect is one finding.**"
has $a "Root cause:"
has $a "**Shard by surface when the read-only scope is large.**"
has $a "the union"
has $a "\$WP option get category_base"
has commands/wp-adopt.md "--replace"
has commands/wp-adopt.md "<<WPCB-PROBE>>"
has commands/wp-adopt.md "--persist-wrapper"
echo PASS
