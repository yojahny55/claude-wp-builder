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
# Compared with === true, not truthiness: a string "false" is truthy in JS and would
# otherwise count as required.
for p in templates/profiles/*.json; do
  n=$(node -e 'const j=require("./'"$p"'");console.log(j.plugins.filter(x=>x.required===true).length)')
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

# --- A conflicts: edge pointing at a plugin the profile also lists is rejected. ---
set +e
$cfg validate-profile tests/fixtures/profiles/conflicts.json >"$tmp/conflicts" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "a profile with conflicting plugins exited $code, want 1"
grep -q 'w3-total-cache conflicts with wp-super-cache' "$tmp/conflicts" || fail "the conflicts message does not name both slugs"

# --- An unknown key on a plugin entry is rejected and named. ----------------
set +e
$cfg validate-profile tests/fixtures/profiles/unknown-key.json >"$tmp/unknown" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "a profile with an unknown plugin key exited $code, want 1"
grep -q 'unknown key on contact-form-7: version' "$tmp/unknown" || fail "the unknown-key message does not name the key"

# --- A source outside the wordpress.org/supplied enum is rejected. ----------
set +e
$cfg validate-profile tests/fixtures/profiles/bad-source.json >"$tmp/source" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "a profile with a bad source exited $code, want 1"
grep -q 'custom-plugin: source must be' "$tmp/source" || fail "the bad-source message does not name the plugin"

# --- A plugins entry that is not an object is rejected. ----------------------
set +e
$cfg validate-profile tests/fixtures/profiles/entry-not-object.json >"$tmp/entry" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "a profile with a non-object plugin entry exited $code, want 1"
grep -q 'every plugins entry must be an object' "$tmp/entry" || fail "the entry-not-object message is missing"

# --- A plugin entry with no slug is rejected. --------------------------------
set +e
$cfg validate-profile tests/fixtures/profiles/missing-slug.json >"$tmp/slug" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "a profile with a slugless plugin entry exited $code, want 1"
grep -q 'every plugins entry needs a slug' "$tmp/slug" || fail "the missing-slug message is missing"

# --- A profile with no name is rejected. -------------------------------------
set +e
$cfg validate-profile tests/fixtures/profiles/missing-name.json >"$tmp/name" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "a nameless profile exited $code, want 1"
grep -q 'name is required' "$tmp/name" || fail "the missing-name message is missing"

# --- A profile whose plugins is not an array is rejected. --------------------
set +e
$cfg validate-profile tests/fixtures/profiles/plugins-not-array.json >"$tmp/parr" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "a profile with non-array plugins exited $code, want 1"
grep -q 'plugins must be an array' "$tmp/parr" || fail "the plugins-not-array message is missing"

# --- A non-array requires is rejected with a message, not a raw stack trace. -
set +e
$cfg validate-profile tests/fixtures/profiles/requires-not-array.json >"$tmp/reqarr" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "a profile with a non-array requires exited $code, want 1"
grep -q 'requires must be an array' "$tmp/reqarr" || fail "the requires-not-array message is missing"
if grep -qi 'TypeError' "$tmp/reqarr"; then fail "a non-array requires produced a raw stack trace instead of a validation message"; fi

# --- A required that is present but not a boolean is rejected. --------------
set +e
$cfg validate-profile tests/fixtures/profiles/required-not-boolean.json >"$tmp/reqbool" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "a profile with a non-boolean required exited $code, want 1"
grep -q 'contact-form-7: required must be a boolean' "$tmp/reqbool" || fail "the required-not-boolean message does not name the plugin"

# --- A slug that is not already lowercase and trimmed is rejected. ----------
set +e
$cfg validate-profile tests/fixtures/profiles/slug-not-canonical.json >"$tmp/slugcanon" 2>&1; code=$?
set -e
[ "$code" = "1" ] || fail "a profile with a non-canonical slug exited $code, want 1"
grep -q 'Contact-Form-7: slug must already be lowercase and trimmed' "$tmp/slugcanon" || fail "the slug-not-canonical message does not name the slug"

echo PASS
