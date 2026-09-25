#!/usr/bin/env bash
# templates/profiles/full.json has marked secure-custom-fields required since it was
# written, and Step 4.10 ignored the flag: "warn about the missing plugin, skip it,
# continue" applied to every plugin equally. A build could therefore finish "successfully"
# with no field engine, and fatal on the first template that called prefix_get_field().
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

c=commands/wp-create.md
i=commands/wp-init.md

# --- Required and optional are different outcomes, in writing. --------------
# A bare grep for 'required' was already true before any Task 6 edit -- section 3.7's
# pre-existing profile-JSON example ("required": true) satisfies it on its own, so it
# protects nothing about Step 4.10 specifically. Assert the actual outcome table instead.
grep -Fq '| Outcome | `required: true` | `required: false` |' "$c" \
  || fail "$c does not show the required-vs-optional outcome table"
grep -Fqi 'blocks the dependent' "$c" || fail "$c does not say a required plugin failure blocks dependent steps"
grep -Fq 'plugins.degraded' "$c" || fail "$c does not record optional failures in plugins.degraded"
grep -Fq 'license_missing' "$c" || fail "$c does not name the licensed-plugin outcome"

# license_missing used to be the single reason recorded for every supplied-package failure:
# a licence nobody bought, a zip nobody handed over, and a zip that was handed over and
# would not install all reported the same word. The operator reading it was sent to buy a
# plugin they may already own, or to debug an install that never started.
for r in package_not_supplied install_failed activation_failed; do
  grep -Fq "$r" "$c" || fail "$c does not distinguish $r from license_missing -- three causes, three different next steps"
done
grep -Fq 'blocks the build' "$c" \
  || fail "$c no longer says the new reasons still count against the entry's required flag"

grep -Fq 'plugins.resolved' "$c" || fail "$c does not record resolved plugin versions"

# --- The step is no longer non-critical wholesale. --------------------------
grep -Fq 'non-critical per plugin' "$c" || fail "$c still treats step 4.10 as non-critical as a whole"

# --- Step 4.10's validate-profile call carries its own Validation/On failure block,
# the same shape every sibling step already has -- not just the bare command. Scope
# tightly to the validate-profile block itself: Step 4.10 also has a later, unrelated
# "**Validation:**" line for the plugin-install loop, and a bare grep over the whole
# step would still pass with the validate-profile block's own line deleted. -----------
profile_validation=$(awk '
  /wp-config\.mjs validate-profile/ { insec = 1 }
  insec && /^Then install/ { exit }
  insec { print }
' "$c")
grep -Fq 'wp-config.mjs validate-profile' <<<"$profile_validation" \
  || fail "$c Step 4.10 does not call wp-config.mjs validate-profile"
grep -Fq '**Validation:**' <<<"$profile_validation" \
  || fail "$c Step 4.10 does not document a **Validation:** block for validate-profile"
grep -Fq '**On failure:**' <<<"$profile_validation" \
  || fail "$c Step 4.10 does not document an **On failure:** block for validate-profile"

# --- The manifest example is at the current version. ------------------------
grep -Fq '"manifest_version": 3' "$c" || fail "$c's manifest example does not carry manifest_version 3"
grep -Fq '.wp-create.local.json' "$c" || fail "$c does not name the local credential file"

# The absence check below must look only at the committable manifest example, not
# the whole file: Step 5 also shows .wp-create.local.json's own shape immediately
# afterward, and that file legitimately has a "password" key -- moving the secret
# there instead of the manifest is the entire point of this task. A whole-file grep
# for '"password"' would fail on that correct, required example.
manifest_example=$(awk '
  /^## Step 5: Generate/ { insec = 1 }
  insec && /^```json/ && !incode { incode = 1; next }
  insec && incode && /^```/ { exit }
  insec && incode { print }
' "$c")
if grep -Fq '"password"' <<<"$manifest_example"; then
  fail "$c's manifest example still contains a password field"
fi

# --- The manifest template itself carries plugins.resolved/plugins.degraded, not just
# Step 4.10's prose describing them. A grep for the dotted name anywhere in the file
# already passes off Step 4.10's own text, so assert the JSON keys inside the template. -
grep -Fq '"resolved":' <<<"$manifest_example" \
  || fail "$c's Step 5 manifest template does not carry a plugins.resolved key"
grep -Fq '"degraded":' <<<"$manifest_example" \
  || fail "$c's Step 5 manifest template does not carry a plugins.degraded key"

# --- Generated credentials, not fixed defaults. -----------------------------
# A bare grep for 'webmaster' also matches the admin *username* default (still
# 'webmaster', still correct -- a username is not a secret and was never asked to
# change). Only the fixed login pair proves the PASSWORD is still hardcoded.
if grep -Fq 'webmaster / webmaster' "$c"; then fail "$c still documents the fixed webmaster admin password"; fi

# --- The local credential file is gitignored at the PROJECT ROOT, not the theme
# directory. A bare grep for the filename passed against the broken version too --
# that version added it to <theme-dir>/.gitignore in Step 9.5, a repository that
# cannot ignore a path living above it. Assert the project-root path specifically. --
step96=$(awk '
  /^## Step 9\.6: Gitignore the local credentials file/ { insec = 1 }
  insec && /^## Step 10/ { exit }
  insec { print }
' "$i")
[ -n "$step96" ] || fail "$i has no Step 9.6 gitignoring the local credentials file"
grep -Fq 'cd ${PROJECT_PATH}' <<<"$step96" \
  || fail "$i Step 9.6 does not cd into \${PROJECT_PATH} before writing .gitignore"
grep -Fq '.wp-create.local.json' <<<"$step96" \
  || fail "$i Step 9.6 does not name the local credential file"

# A .gitignore whose last line has no trailing newline is CONCATENATED with the new
# entry, not extended: `*.log` + `.wp-create.local.json` becomes the single pattern
# `*.log.wp-create.local.json`, git check-ignore stops matching, and the next
# `git add -A` commits the database and admin passwords. Measured in a real repo.
grep -Fq 'tail -c1 .gitignore' <<<"$step96" \
  || fail "$i Step 9.6 appends without guaranteeing a leading newline, so a .gitignore with no trailing newline is corrupted and the secret is committed"

# Every sibling Validation block in this pipeline states an action for the failing
# case. This one stated only what success looks like, so a Claude that ran the check
# and saw no match had nothing telling it not to carry on to Step 10.
grep -Fq '**On failure:**' <<<"$step96" \
  || fail "$i Step 9.6's Validation line mandates no action on failure"

# Step 9.5's *theme* .gitignore must not have regressed back to also ignoring it there --
# that duplication is exactly how the project-root defect survived its first review.
step95=$(awk '
  /^## Step 9\.5: Initialize git repository/ { insec = 1 }
  insec && /^## Step 9\.6/ { exit }
  insec { print }
' "$i")
if grep -Fq '.wp-create.local.json' <<<"$step95"; then
  fail "$i Step 9.5 writes the local credential file into the theme's own .gitignore again"
fi

# --- No skill routes an agent back to the manifest for a secret. -------------
# wp-environments' placeholder->manifest table is a mapping an agent FOLLOWS at
# /wp-create Step 4.3, not an example: routing {{db_password}} to database.password
# hands it an empty value on every project written since the split, or a silent
# legacy read on every project that has not migrated. It must name the validator.
env=skills/wp-environments/SKILL.md
if grep -Fq 'database.password' "$env"; then
  fail "$env still maps a placeholder onto the manifest field the database password was moved out of"
fi
grep -Fq "wp-config.mjs get '\${PROJECT_PATH}' db_password" "$env" \
  || fail "$env does not route {{db_password}} through the validator"
if grep -Eq '^\| `\{\{db_password\}\}` \| `root` \|' "$env"; then
  fail "$env still documents the removed fixed default as the db_password example value"
fi

# --- Stores. ------------------------------------------------------------------------------
grep -Fq 'config set WP_ENVIRONMENT_TYPE local --type=constant' "$c" \
  || fail "$c does not mark a dev site local: WordPress reads an unset WP_ENVIRONMENT_TYPE as production"
grep -Fq '"source": "bundled"' "$c" || fail "$c does not say how a bundled plugin is installed"
grep -Fq 'bin/store-kit-sync.sh' "$c" || fail "$c does not install store-kit through bin/store-kit-sync.sh"
s55=$(grep -n '^## Step 5.5: Store setup' "$c" | cut -d: -f1 || true)
s5=$(grep -n '^## Step 5: Generate' "$c" | cut -d: -f1 || true)
s6=$(grep -n '^## Step 6: Chain' "$c" | cut -d: -f1 || true)
[ -n "$s55" ] && [ -n "$s5" ] && [ -n "$s6" ] && [ "$s5" -lt "$s55" ] && [ "$s55" -lt "$s6" ] \
  || fail "$c must run store setup after the manifest exists (Step 5) and before chaining to /wp-init"
sed -n "${s55},${s6}p" "$c" | grep -Fq '/wp-woo-setup' || fail "$c Step 5.5 does not run /wp-woo-setup"

echo PASS
