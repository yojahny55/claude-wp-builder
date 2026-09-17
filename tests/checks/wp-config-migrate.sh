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

# --- The migrated project states each decision exactly once. ----------------
# migrate calls render-context, which appends the generated block BESIDE the legacy
# prose line it just read. contextDrift only compares inside the markers, so the file
# could state polylang on line 4 and suffix on line 12 with validate exiting 0 -- the
# disagreement this branch exists to remove, reintroduced by its own migration, for
# exactly the population migration targets. Each block-owned label must now have one
# live line, and the retired one must survive as a comment rather than be deleted.
md="$tmp/p/.claude/CLAUDE.md"
for label in 'i18n strategy' 'Theme slug'; do
  n=$(grep -c "^[[:space:]]*-[[:space:]]*\*\*$label:\*\*" "$md" || true)
  [ "$n" = "1" ] || fail "$label is asserted on $n lines of .claude/CLAUDE.md, want exactly 1"
done
grep -Fq 'superseded by the wp-create:begin block' "$md" \
  || fail "migration deleted the legacy prose decision lines instead of superseding them"
grep -Fq 'superseded by the wp-create:begin block below: - **i18n strategy:** polylang' "$md" \
  || fail "the superseded comment does not preserve the pre-migration value"
# Not commented out of the block itself -- the generated lines carry the same labels.
grep -Fq -e '- **i18n strategy:** polylang' "$md" \
  || fail "the generated block lost its own i18n strategy line to the superseding pass"

# The two disagreeing values in one file, the way the review measured it: flip the
# manifest and re-render. Only the block may move.
node -e '
 const f="'"$tmp"'/p/.wp-create.json", fs=require("fs");
 const m=JSON.parse(fs.readFileSync(f,"utf8")); m["i18n strategy"]="suffix";
 fs.writeFileSync(f, JSON.stringify(m,null,2)+"\n");
'
$cfg render-context "$tmp/p" >/dev/null 2>&1 || fail "re-rendering after a manifest edit did not exit 0"
$cfg validate "$tmp/p" >/dev/null 2>&1 || fail "the migrated project does not validate after a manifest edit"
n=$(grep -c "^[[:space:]]*-[[:space:]]*\*\*i18n strategy:\*\*" "$md" || true)
[ "$n" = "1" ] || fail "after a manifest edit the file asserts i18n strategy on $n lines, want exactly 1"
grep -Fq -e '- **i18n strategy:** suffix' "$md" || fail "the one live i18n strategy line is not the manifest's value"

# --- The backup is versioned, not .bak, which /wp-create already uses. ------
[ -f "$tmp/p/.wp-create.json.v1.bak" ] || fail "migration did not write a versioned backup"
if [ -f "$tmp/p/.wp-create.json.bak" ]; then fail "migration wrote .wp-create.json.bak and would clobber /wp-create's Overwrite backup"; fi

# --- Migrating twice is a no-op: the entry is unchanged AND no new file (e.g.
# a stray backup) appears. A content-only sha256 of .wp-create.json can't see a
# regression that writes an extra file alongside it, so this also snapshots the
# whole directory's file listing before and after.
before=$(sha256sum "$tmp/p/.wp-create.json" | cut -d" " -f1)
before_files=$(find "$tmp/p" -type f | sort)
$cfg migrate "$tmp/p" >/dev/null 2>&1 || fail "the second migrate did not exit 0"
after=$(sha256sum "$tmp/p/.wp-create.json" | cut -d" " -f1)
after_files=$(find "$tmp/p" -type f | sort)
[ "$before" = "$after" ] || fail "migrate is not idempotent: the second run rewrote the manifest"
[ "$before_files" = "$after_files" ] || fail "migrate is not idempotent: the second run left a new file behind (e.g. a stray backup)"

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
