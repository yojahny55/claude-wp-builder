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
grep -Fq 'plugins.resolved' "$c" || fail "$c does not record resolved plugin versions"

# --- The step is no longer non-critical wholesale. --------------------------
grep -Fq 'non-critical per plugin' "$c" || fail "$c still treats step 4.10 as non-critical as a whole"

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

# --- Generated credentials, not fixed defaults. -----------------------------
# A bare grep for 'webmaster' also matches the admin *username* default (still
# 'webmaster', still correct -- a username is not a secret and was never asked to
# change). Only the fixed login pair proves the PASSWORD is still hardcoded.
if grep -Fq 'webmaster / webmaster' "$c"; then fail "$c still documents the fixed webmaster admin password"; fi

# --- The project gitignore covers the local file. ---------------------------
grep -Fq '.wp-create.local.json' "$i" || fail "$i does not add the local credential file to .gitignore"

echo PASS
