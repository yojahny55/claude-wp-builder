#!/usr/bin/env bash
# The plugin wrote working state (audit ledger, .wp-audit/ reports, manifest backups, Robin's
# runtime cache) into site roots without saying whether it goes to git, and /wp-adopt forbade
# editing .gitignore, so nothing ever proposed the ignore and the ledger got committed.
# Pins: the single list, the gitignore-check subcommand (run for real), the prose that calls
# it, and the configurable report directory.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
need() { grep -Fq -- "$2" "$1" || fail "$1 lacks: $2"; }

w=bin/wp-config.mjs
need $w 'const TOOL_STATE_PATHS'
for e in "'.wp-audit/'" "'.wp-audit-findings.json'" "'.wp-create.local.json'" "robin-image-optimizer"; do
  need $w "$e"
done

l=skills/wp-audit-run/references/ledger.md
need $l 'working state'
need $l 'is not versioned'
need $l 'wp-config.mjs gitignore-check'
need $l 'AskUserQuestion'
need $l "one exception"
need commands/wp-adopt.md 'wp-config.mjs gitignore-check'
need commands/wp-adopt.md 'sole exception'
need commands/wp-audit.md 'wp-config.mjs gitignore-check'
need commands/wp-robin.md 'wp-config.mjs gitignore-check'
need skills/wp-robin/SKILL.md 'gitignore-check'
need skills/wp-contributing/SKILL.md 'TOOL_STATE_PATHS'
d=skills/wp-audit-run/references/deliverable.md
need $d 'WP_AUDIT_OUT_DIR'
need $d 'audit.out_dir'
need $d 'absolute'
need $d 'new baseline'
need bin/audit-report.mjs 'WP_AUDIT_OUT_DIR'
! grep -Fq -- '--out .wp-audit' $d || fail "$d still hardcodes --out .wp-audit"

# Behavior: exit codes of the subcommand.
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
git -C "$t" init -q
set +e; out=$(node $w gitignore-check "$t"); rc=$?; set -e
[ "$rc" = 4 ] || fail "unignored root should exit 4, got $rc"
echo "$out" | grep -Fq 'missing: .wp-audit-findings.json' || fail "ledger not reported missing"
printf '.wp-audit/\n.wp-audit-findings.json\n.wp-create.local.json\n.wp-create.json.bak*\n.wp-create.json.v*.bak\n' > "$t/.gitignore"
node $w gitignore-check "$t" >/dev/null || fail "fully ignored root should exit 0"
n=$(mktemp -d); trap 'rm -rf "$t" "$n"' EXIT
node $w gitignore-check "$n" >/dev/null || fail "non-git root should exit 0"

# Behavior: out-dir precedence.
run='{"findings":[]}'; echo "$run" > "$t/run.json"
(cd "$t" && echo '{"audit":{"out_dir":"from-manifest"}}' > .wp-create.json \
  && node "$OLDPWD/bin/audit-report.mjs" --run run.json --format md >/dev/null \
  && [ -d from-manifest ]) || fail "audit.out_dir not honored"
(cd "$t" && WP_AUDIT_OUT_DIR=from-env node "$OLDPWD/bin/audit-report.mjs" --run run.json --format md >/dev/null \
  && [ -d from-env ]) || fail "WP_AUDIT_OUT_DIR does not beat the manifest"
(cd "$t" && WP_AUDIT_OUT_DIR=from-env node "$OLDPWD/bin/audit-report.mjs" --run run.json --format md --out from-flag | grep -q "wrote $t/from-flag/" \
  && [ -d from-flag ]) || fail "--out does not win, or paths are not absolute"
echo PASS
