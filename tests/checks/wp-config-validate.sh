#!/usr/bin/env bash
# The manifest has about thirty readers and, before this, no writer contract: only
# /wp-audit knew manifest_version existed and /wp-create never wrote it. A malformed
# manifest therefore failed thirty different ways, late, inside whichever command
# happened to read it first. These assertions pin the single early failure instead.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

cfg="node bin/wp-config.mjs"
fx=tests/fixtures/manifests

# --- A valid manifest passes and says nothing alarming. ---------------------
out=$($cfg validate "$fx/valid" 2>&1) || fail "a valid manifest did not exit 0: $out"

# --- A missing manifest is exit 3, distinct from invalid. -------------------
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
set +e
$cfg validate "$tmp" >"$tmp/out" 2>&1; code=$?
set -e
[ "$code" = "3" ] || fail "a missing manifest exited $code, want 3"
grep -q '.wp-create.json' "$tmp/out" || fail "the missing-manifest message does not name the file"

# --- A malformed manifest is exit 1 and names the problem field. ------------
set +e
$cfg validate "$fx/malformed" >"$tmp/bad" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "a malformed manifest exited $code, want 1"
grep -q 'project.slug' "$tmp/bad" || fail "the invalid-manifest message does not name the missing field"

# --- Every field the generated block renders is also required. ---------------
# REQUIRED and renderContext's field list used to be two lists that had to agree and
# did not: a manifest without `theme` or `languages` rendered "- **Theme slug:** " and
# "- **Primary language:** " as blanks into the authoritative block and validate exited
# 0 -- and reading that block is every agent's first mandatory action. Both lists are
# now derived from CONTEXT_FIELDS, so this asserts the derivation, one field at a time.
for path in theme.slug languages.primary plugins.profile; do
  top=${path%%.*}
  cp -r "$fx/valid" "$tmp/missing-$top"
  node -e '
    const f=process.argv[1], k=process.argv[2], fs=require("fs");
    const m=JSON.parse(fs.readFileSync(f,"utf8")); delete m[k];
    fs.writeFileSync(f, JSON.stringify(m,null,2)+"\n");
  ' "$tmp/missing-$top/.wp-create.json" "$top"
  set +e
  $cfg validate "$tmp/missing-$top" >"$tmp/missing-$top.out" 2>&1; code=$?
  set -e
  if [ "$path" = "plugins.profile" ]; then
    # The one rendered field with a documented absent meaning ("none"), so it is
    # rendered without being required -- the exemption the `fallback` column encodes.
    [ "$code" = "0" ] || fail "a manifest without plugins.profile exited $code, want 0: it renders as \"none\""
  else
    [ "$code" = "1" ] || fail "a manifest without $path exited $code, want 1: the block would render it blank"
    grep -Fq "$path" "$tmp/missing-$top.out" || fail "the refusal for a missing $path does not name it"
  fi
done

# --- The absent-value defaults have one definition, and `get` reads it. -------
# STEPS[1], renderContext and getKey each used to spell 'suffix'/'plain' for
# themselves, and only the first two were tested: inverting getKey's two-entry
# ternary left the whole suite green while `get i18n-strategy` returned "plain",
# which is not even a valid i18n strategy.
cp -r "$fx/valid" "$tmp/no-decisions"
node -e '
  const f=process.argv[1], fs=require("fs");
  const m=JSON.parse(fs.readFileSync(f,"utf8"));
  delete m["i18n strategy"]; delete m["demo mode"];
  fs.writeFileSync(f, JSON.stringify(m,null,2)+"\n");
' "$tmp/no-decisions/.wp-create.json"
out=$($cfg get "$tmp/no-decisions" i18n-strategy 2>/dev/null) || fail "get i18n-strategy on an absent key did not exit 0"
[ "$out" = "suffix" ] || fail "an absent i18n strategy read back as $out, want suffix"
out=$($cfg get "$tmp/no-decisions" demo-mode 2>/dev/null) || fail "get demo-mode on an absent key did not exit 0"
[ "$out" = "plain" ] || fail "an absent demo mode read back as $out, want plain"
$cfg render-context "$tmp/no-decisions" >/dev/null 2>&1 || fail "render-context on a manifest with no decision keys did not exit 0"
grep -Fq -e '- **i18n strategy:** suffix' "$tmp/no-decisions/.claude/CLAUDE.md" \
  || fail "the generated block does not render the absent-means-suffix default"
grep -Fq -e '- **demo mode:** plain' "$tmp/no-decisions/.claude/CLAUDE.md" \
  || fail "the generated block does not render the absent-means-plain default"

# --- CURRENT_VERSION cannot disagree with the migration table. ---------------
# It is derived from STEPS rather than typed beside it: bumping the constant without
# writing the step used to produce an uncaught Error and a raw Node stack trace.
grep -Fq 'Math.max(...Object.keys(STEPS).map(Number)) + 1' bin/lib/manifest.mjs \
  || fail "CURRENT_VERSION is no longer derived from STEPS and can be bumped without a migration step"

echo PASS
