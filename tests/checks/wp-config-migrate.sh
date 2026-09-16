#!/usr/bin/env bash
# For a legacy project the prose line in .claude/CLAUDE.md is the ONLY record of the
# i18n strategy. A migration that does not read it silently re-decides the project's
# language model, which is the one thing every downstream command branches on.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

cfg="node bin/wp-config.mjs"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# --- A v1 project migrates and carries the prose decision across. -----------
cp -r tests/fixtures/manifests/legacy-v1 "$tmp/p"
$cfg migrate "$tmp/p" >/dev/null 2>&1 || fail "migrating a v1 project did not exit 0"

v=$(node -e 'const m=require("'"$tmp"'/p/.wp-create.json");console.log(m.manifest_version)')
[ "$v" = "3" ] || fail "migrated manifest is version $v, want 3"

strat=$(node -e 'const m=require("'"$tmp"'/p/.wp-create.json");console.log(m["i18n strategy"])')
[ "$strat" = "polylang" ] || fail "migration did not carry the prose i18n strategy across: got $strat"

mode=$(node -e 'const m=require("'"$tmp"'/p/.wp-create.json");console.log(m["demo mode"])')
[ "$mode" = "plain" ] || fail "migration did not apply the absent-means-plain fallback: got $mode"

keep=$(node -e 'const m=require("'"$tmp"'/p/.wp-create.json");console.log(m.unknown_future_key||"")')
[ "$keep" = "keep-me" ] || fail "migration dropped an unknown key instead of preserving it"

# --- The backup is versioned, not .bak, which /wp-create already uses. ------
[ -f "$tmp/p/.wp-create.json.v1.bak" ] || fail "migration did not write a versioned backup"
if [ -f "$tmp/p/.wp-create.json.bak" ]; then fail "migration wrote .wp-create.json.bak and would clobber /wp-create's Overwrite backup"; fi

# --- Migrating twice is a no-op. --------------------------------------------
before=$(sha256sum "$tmp/p/.wp-create.json" | cut -d" " -f1)
$cfg migrate "$tmp/p" >/dev/null 2>&1 || fail "the second migrate did not exit 0"
after=$(sha256sum "$tmp/p/.wp-create.json" | cut -d" " -f1)
[ "$before" = "$after" ] || fail "migrate is not idempotent: the second run rewrote the manifest"

# --- A future version is refused and left completely intact. ----------------
cp -r tests/fixtures/manifests/future "$tmp/f"
sum_before=$(sha256sum "$tmp/f/.wp-create.json" | cut -d" " -f1)
set +e
$cfg migrate "$tmp/f" >"$tmp/fout" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "a future manifest_version exited $code, want 1"
grep -qi 'newer' "$tmp/fout" || fail "the refusal does not say the manifest is newer than this plugin"
sum_after=$(sha256sum "$tmp/f/.wp-create.json" | cut -d" " -f1)
[ "$sum_before" = "$sum_after" ] || fail "a refused migration modified the file anyway"

echo PASS
