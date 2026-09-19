#!/usr/bin/env bash
# /wp-clone imported a database and uploads, rewrote URLs, and checked that WordPress
# loaded -- every check it ran asked "does it work", none asked "is it contained". A clone
# of a live store therefore arrived with the source site's mail settings, live payment
# credentials, production webhook URLs and a due cron queue, and the summary's closing
# instruction was "Visit <local-url> to verify the site": the page load that fires all of it.
#
# This pins the properties of the isolation step that are load-bearing, and especially its
# ORDER -- isolation that runs after the site has been loaded is not isolation, it is a
# report on what already happened.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

f=commands/wp-clone.md
[ -f "$f" ] || fail "$f is missing"
need() { grep -Fq "$1" "$f" || fail "$f $2"; }

need 'Step 5.5: Isolate the Clone' 'has no isolation step'

# Order. Step 6 loads WordPress and then tells the operator to visit the site; anything
# that must not happen has to be prevented before that, not reported after it.
iso=$(grep -n '^## Step 5.5: Isolate the Clone' "$f" | head -1 | cut -d: -f1 || true)
ver=$(grep -n '^## Step 6: Post-Clone Verification' "$f" | head -1 | cut -d: -f1 || true)
[ -n "$iso" ] || fail "$f no longer declares Step 5.5 as a heading"
[ -n "$ver" ] || fail "$f no longer declares Step 6 as a heading"
[ "$iso" -lt "$ver" ] \
  || fail "$f puts isolation (line $iso) AFTER verification (line $ver) -- Step 6 loads the site, so isolation past it reports what already happened"

# BOTH paths must reach it. Path A and Path B each end with their own hand-off, and a
# clone that skipped straight to Step 6 from either one would be uncontained.
skips=$(grep -c 'Skip to \*\*Step 5.5: Isolate the Clone\*\*' "$f" || true)
[ "${skips:-0}" -ge 2 ] \
  || fail "$f routes only ${skips:-0} path(s) to Step 5.5; Path A and Path B must both arrive there"
if grep -Fq 'Skip to **Step 6: Post-Clone Verification**' "$f"; then
  fail "$f still lets a path skip straight to Step 6, bypassing isolation"
fi

# The mail seam. A plugin-level fix does not hold: core falls back to PHP mail(), so the
# site keeps sending and merely stops logging where anyone would look.
need 'pre_wp_mail' 'does not intercept mail at pre_wp_mail'
need 'a mail plugin is not' 'does not explain why the filter, and not an SMTP plugin, is the seam'
need 'falls back to PHP `mail()`' 'does not say what happens if an SMTP plugin is disabled instead'

# Returning true is not incidental: it keeps every caller on its success path, so the clone
# behaves like the original everywhere except at the wire.
need 'Returning `true` matters' 'does not explain why the filter reports success to the caller'

# must-use, so it cannot be clicked off, and named so nobody ships it.
need 'mu-plugins/00-clone-isolation.php' 'does not write the isolation mu-plugin'
need 'cannot be deactivated from wp-admin' 'does not say why the isolation is a must-use plugin'
need 'delete this file if this site ever becomes real' 'the mu-plugin header does not warn against shipping it'

need 'DISABLE_WP_CRON' 'does not disable cron -- a store clone would run the source site due queue'
need 'blog_public' 'does not keep the clone out of search results'

# Report, do not mutate. The reasoning has to travel with the rule or someone "finishes"
# it later by auto-disabling the gateway.
need 'do not silently change them' 'does not state that live integrations are reported rather than edited'
need 'Reporting is the action here' 'does not defend reporting over auto-disabling'
need 'makes that bug disappear' 'does not say what an auto-switch costs the session that needed the clone'
need 'real customer data' 'does not tell the operator that live customer records are now on this machine'

# A failed isolation must stop, not warn. Continuing to Step 6 loads the site.
need 'Any line reporting a failure stops the clone here' \
  'does not stop on a failed isolation -- continuing to Step 6 loads the site it failed to contain'

# Visible every run. A success line nobody sees is a success nobody can rely on.
need 'Isolation:' 'the clone summary does not report what was isolated'
need 'Still live — reported, not changed' 'the clone summary does not report what remains live'
# Needle kept to a single line on purpose: the sentence in the command wraps, and grep -F
# matches within a line, so a longer phrase would fail on formatting rather than on meaning.
need 'collapsed to one line' \
  'lets the isolation report shrink on success -- the one run where it silently failed is the run that needed it'

echo "PASS: the clone is isolated before anything loads it, on both paths, and says so"
