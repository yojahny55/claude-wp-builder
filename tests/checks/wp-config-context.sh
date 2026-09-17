#!/usr/bin/env bash
# .claude/CLAUDE.md is read in 17 places for `i18n strategy` alone. Agents keep reading
# it exactly as before; what changes is that it is rendered from the manifest, so it
# can no longer disagree. Text OUTSIDE the markers is the operator's and is never touched.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

cfg="node bin/wp-config.mjs"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cp -r tests/fixtures/manifests/valid "$tmp/p"
mkdir -p "$tmp/p/.claude"

printf '# Fixture Site\n\nHand written guidance the operator added.\n' > "$tmp/p/.claude/CLAUDE.md"
$cfg render-context "$tmp/p" >/dev/null 2>&1 || fail "render-context did not exit 0"

grep -q 'Hand written guidance' "$tmp/p/.claude/CLAUDE.md" || fail "render-context destroyed hand-written text outside the markers"
grep -q '<!-- wp-create:begin -->' "$tmp/p/.claude/CLAUDE.md" || fail "the generated block has no begin marker"
grep -q 'i18n strategy' "$tmp/p/.claude/CLAUDE.md" || fail "the generated block does not carry the i18n strategy"

# --- Rendering twice changes nothing. ---------------------------------------
before=$(sha256sum "$tmp/p/.claude/CLAUDE.md" | cut -d" " -f1)
$cfg render-context "$tmp/p" >/dev/null 2>&1
after=$(sha256sum "$tmp/p/.claude/CLAUDE.md" | cut -d" " -f1)
[ "$before" = "$after" ] || fail "render-context is not idempotent"

# --- A hand-edited block is REPORTED, not silently overwritten. -------------
sed -i 's|i18n strategy:\*\* suffix|i18n strategy:** polylang|' "$tmp/p/.claude/CLAUDE.md"
set +e
$cfg validate "$tmp/p" >"$tmp/out" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "a hand-edited generated block exited $code, want 1"
grep -q 'wp-create:begin' "$tmp/out" || fail "the drift message does not name the generated block"
grep -q 'polylang' "$tmp/p/.claude/CLAUDE.md" || fail "validate overwrote the hand edit instead of reporting it"

# --- Outcome 1, explicitly: a VALID existing block is REPLACED (not appended) when
# the manifest changes, stays at exactly one marker pair, and operator text survives.
cp -r tests/fixtures/manifests/valid "$tmp/replace"
mkdir -p "$tmp/replace/.claude"
printf '# Replace Fixture\n\nOperator guidance before.\n' > "$tmp/replace/.claude/CLAUDE.md"
$cfg render-context "$tmp/replace" >/dev/null 2>&1 || fail "outcome-1 setup render-context did not exit 0"
node -e '
  const fs = require("fs");
  const file = process.argv[1];
  const m = JSON.parse(fs.readFileSync(file, "utf8"));
  m["i18n strategy"] = "polylang";
  fs.writeFileSync(file, JSON.stringify(m, null, 2) + "\n");
' "$tmp/replace/.wp-create.json"
$cfg render-context "$tmp/replace" >/dev/null 2>&1 || fail "outcome-1 replace render-context did not exit 0"
begins=$(grep -c '<!-- wp-create:begin -->' "$tmp/replace/.claude/CLAUDE.md")
ends=$(grep -c '<!-- wp-create:end -->' "$tmp/replace/.claude/CLAUDE.md")
[ "$begins" = "1" ] && [ "$ends" = "1" ] || fail "outcome 1: replace left $begins begin / $ends end markers, want exactly one each"
grep -q '\*\*i18n strategy:\*\* polylang' "$tmp/replace/.claude/CLAUDE.md" || fail "outcome 1: replace did not pick up the changed manifest"
grep -q 'Operator guidance before' "$tmp/replace/.claude/CLAUDE.md" || fail "outcome 1: replace destroyed operator text"

# --- Outcome 3, begin-without-end: a truncated write/botched merge leaves an orphan
# BEGIN with no END. render-context must refuse, not append past the orphan (the
# Critical bug: an ordinary render-context afterward would then pair that orphan
# BEGIN with the real END and delete everything the operator wrote between them). ---
cp -r tests/fixtures/manifests/valid "$tmp/orphan-begin"
mkdir -p "$tmp/orphan-begin/.claude"
printf '# Orphan Begin Fixture\n\nOperator text before.\n\n<!-- wp-create:begin -->\nOperator text after, never closed.\n' > "$tmp/orphan-begin/.claude/CLAUDE.md"
before=$(sha256sum "$tmp/orphan-begin/.claude/CLAUDE.md" | cut -d" " -f1)
set +e
$cfg render-context "$tmp/orphan-begin" >"$tmp/orphan-begin.out" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "begin-without-end: render-context exited $code, want 1"
grep -qi 'malformed' "$tmp/orphan-begin.out" || fail "begin-without-end: the refusal does not name the malformed marker state"
after=$(sha256sum "$tmp/orphan-begin/.claude/CLAUDE.md" | cut -d" " -f1)
[ "$before" = "$after" ] || fail "begin-without-end: render-context wrote to a malformed file"
grep -q 'Operator text before' "$tmp/orphan-begin/.claude/CLAUDE.md" || fail "begin-without-end: operator text was lost"
grep -q 'Operator text after, never closed' "$tmp/orphan-begin/.claude/CLAUDE.md" || fail "begin-without-end: operator text was lost"
# validate refuses the same way, and does not try to regenerate it for the operator.
set +e
$cfg validate "$tmp/orphan-begin" >"$tmp/orphan-begin-validate.out" 2>&1; vcode=$?
set -e
[ "$vcode" = "1" ] || fail "begin-without-end: validate exited $vcode, want 1"
grep -qi 'malformed' "$tmp/orphan-begin-validate.out" || fail "begin-without-end: validate did not name the malformed marker state"
grep -qi 'by hand' "$tmp/orphan-begin-validate.out" || fail "begin-without-end: validate still points at render-context instead of a by-hand fix"

# --- Outcome 3, end-before-begin: the Minor bug -- an END that appears earlier in
# the file than the BEGIN used to permanently take the append branch, growing a new
# duplicate block on every render-context call. Must refuse instead. --------------
cp -r tests/fixtures/manifests/valid "$tmp/end-before-begin"
mkdir -p "$tmp/end-before-begin/.claude"
printf '# End Before Begin Fixture\n\nOperator text before.\n<!-- wp-create:end -->\nOperator text between.\n<!-- wp-create:begin -->\nOperator text after.\n' > "$tmp/end-before-begin/.claude/CLAUDE.md"
before=$(sha256sum "$tmp/end-before-begin/.claude/CLAUDE.md" | cut -d" " -f1)
set +e
$cfg render-context "$tmp/end-before-begin" >"$tmp/end-before-begin.out" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "end-before-begin: render-context exited $code, want 1"
grep -qi 'malformed' "$tmp/end-before-begin.out" || fail "end-before-begin: the refusal does not name the malformed marker state"
after=$(sha256sum "$tmp/end-before-begin/.claude/CLAUDE.md" | cut -d" " -f1)
[ "$before" = "$after" ] || fail "end-before-begin: render-context wrote to a malformed file"
grep -q 'Operator text before' "$tmp/end-before-begin/.claude/CLAUDE.md" || fail "end-before-begin: operator text was lost"
grep -q 'Operator text between' "$tmp/end-before-begin/.claude/CLAUDE.md" || fail "end-before-begin: operator text was lost"
grep -q 'Operator text after' "$tmp/end-before-begin/.claude/CLAUDE.md" || fail "end-before-begin: operator text was lost"

# --- Outcome 3, two begin markers: e.g. documentation showing the block as an
# example. More than one of either marker must refuse, not guess which pair is real.
cp -r tests/fixtures/manifests/valid "$tmp/two-begin"
mkdir -p "$tmp/two-begin/.claude"
printf '# Two Begin Fixture\n\nOperator text before.\n<!-- wp-create:begin -->\nOperator text between begins.\n<!-- wp-create:begin -->\nOperator text after.\n<!-- wp-create:end -->\n' > "$tmp/two-begin/.claude/CLAUDE.md"
before=$(sha256sum "$tmp/two-begin/.claude/CLAUDE.md" | cut -d" " -f1)
set +e
$cfg render-context "$tmp/two-begin" >"$tmp/two-begin.out" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "two-begin: render-context exited $code, want 1"
grep -qi 'malformed' "$tmp/two-begin.out" || fail "two-begin: the refusal does not name the malformed marker state"
after=$(sha256sum "$tmp/two-begin/.claude/CLAUDE.md" | cut -d" " -f1)
[ "$before" = "$after" ] || fail "two-begin: render-context wrote to a malformed file"
grep -q 'Operator text before' "$tmp/two-begin/.claude/CLAUDE.md" || fail "two-begin: operator text was lost"
grep -q 'Operator text between begins' "$tmp/two-begin/.claude/CLAUDE.md" || fail "two-begin: operator text was lost"
grep -q 'Operator text after' "$tmp/two-begin/.claude/CLAUDE.md" || fail "two-begin: operator text was lost"

echo PASS
