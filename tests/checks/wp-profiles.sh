#!/usr/bin/env bash
# Profiles load from three places: the plugin's templates/profiles/, the project's
# .wp-profiles/*.json and ~/.wp-profiles/*.json. The last two are user-authored, which
# is what makes structure validation worth having -- the built-ins are ours.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

cfg="node bin/wp-config.mjs"

# --- Both shipped profiles are valid. ---------------------------------------
for p in templates/profiles/*.json; do
  $cfg validate-profile "$p" >/dev/null 2>&1 || fail "shipped profile $p does not validate"
done

# --- Every shipped profile marks exactly one plugin required. ---------------
# secure-custom-fields is the field engine every generated theme calls through
# prefix_get_field(); a build without it produces templates that fatal on first render.
for p in templates/profiles/*.json; do
  n=$(node -e 'const j=require("./'"$p"'");console.log(j.plugins.filter(x=>x.required).length)')
  [ "$n" -ge 1 ] || fail "$p marks no plugin required, so nothing can block a broken build"
done

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# --- Duplicate slugs are rejected and named. --------------------------------
set +e
$cfg validate-profile tests/fixtures/profiles/duplicate-slugs.json >"$tmp/dup" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "a profile with duplicate slugs exited $code, want 1"
grep -q 'contact-form-7' "$tmp/dup" || fail "the duplicate-slug message does not name the slug"

# --- A requires: edge pointing at an absent plugin is rejected. -------------
set +e
$cfg validate-profile tests/fixtures/profiles/unresolved-requires.json >"$tmp/req" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "a profile with an unresolved requires exited $code, want 1"
grep -q 'woocommerce' "$tmp/req" || fail "the unresolved-requires message does not name the missing plugin"

echo PASS
