#!/usr/bin/env bash
# A multi-currency plugin (CURCY/woocommerce-multi-currency is one shape of this) computes a
# per-currency price per request, usually from a cookie. A full-page or edge cache computes
# what to serve per cache key. When the key does not vary on the currency signal, the first
# visitor's currency is cached and served to everyone else — wrong prices, and the cached
# Product/Offer schema is wrong alongside them, since both come from the same response.
#
# Three defects this contract prevents, each one a false-clean audit on a store that has this
# plugin combination:
#   1. The risk check (PERF-065) fires on any store, whether or not it runs WooCommerce or a
#      multi-currency plugin, scoring a site for a cart or a plugin it never had. It must gate
#      on site.commerce and on a multi-currency plugin being active, same as every other
#      commerce check /wp-audit Step 2.3 already requires.
#   2. The live checks (PERF-066, PERF-067) get fired at the local clone, whose own server has
#      no CDN in front of it — a false PASS/"no cache" reading exactly like probing the clone
#      for response headers or paid-file reachability. They must target a confirmed production
#      host and read UNMEASURED without one.
#   3. The fix gets written as a code change (a performance.php cache-bypass rule) instead of
#      what it actually is: a setting on a cache plugin or an edge service this plugin does not
#      own. A code fix here is a no-op on a Cloudflare edge cache, which no .htaccess reaches.
#
# The wording IS the behavior, so assert both directions: the contract present, and the
# discarded shape (probing the clone, treating every combination as one flat severity, fixing
# it with code) named as wrong.
set -uo pipefail

fail() { echo "FAIL: $1"; exit 1; }

cd "$(dirname "$0")/../.." || fail "cannot cd to the repository root"

perf=agents/wp-audit-performance.md
seo=agents/wp-audit-seo.md
changelog=CHANGELOG.md

for f in "$perf" "$seo" "$changelog"; do
  [ -f "$f" ] || fail "$f is missing"
  [ -r "$f" ] || fail "$f exists but cannot be read"
done

# Flattened copies: several needles below cross a line wrap in the prose, which a per-line
# grep would miss even though the sentence reads fine to a human.
flat_perf=$(tr '\n' ' ' < "$perf" | sed 's/  */ /g')
flat_seo=$(tr '\n' ' ' < "$seo" | sed 's/  */ /g')

# --- Codes exist and are tabulated (audit-check-tables.sh's own rule, pinned here too so this
#     one test file tells the whole story on its own) ---
for code in PERF-065 PERF-066 PERF-067; do
  grep -qE "^\| ${code} \|" "$perf" || fail "$perf has no tabulated row for $code"
done
grep -qE '^\| SEO-069 \|' "$seo" || fail "$seo has no tabulated row for SEO-069"

# --- Direction 1: the commerce/multi-currency gate is present, both reasons ---
grep -Fq '"no WooCommerce"' "$perf" \
  || fail "$perf: PERF-065 does not give the N/A (no WooCommerce) reason"
grep -Fq '"no multi-currency plugin"' "$perf" \
  || fail "$perf: PERF-065 does not give the N/A (no multi-currency plugin) reason"
grep -Fq '"no WooCommerce"' "$seo" \
  || fail "$seo: SEO-069 does not give the N/A (no WooCommerce) reason"
grep -Fq '"no multi-currency plugin"' "$seo" \
  || fail "$seo: SEO-069 does not give the N/A (no multi-currency plugin) reason"
# Both directions on the gate: it must also be stated that these are commerce-only, not a
# blanket "always N/A" that would silently disable the check everywhere.
grep -Fq 'site.commerce' "$perf" \
  || fail "$perf does not read site.commerce, so PERF-065 cannot be commerce-gated at all"

# --- Direction 2: severity is NOT one flat value — cookie/session selection escalates ---
grep -Fq 'cookie- or session-selected currency is invisible' "$perf" \
  || fail "$perf: PERF-065 does not escalate to CRITICAL for cookie/session currency selection"
printf '%s' "$flat_perf" | grep -Fq 'that combination is the CRITICAL case' \
  || fail "$perf does not name the cookie/session case as CRITICAL, not merely WARNING"
grep -Fq 'WARNING/CRITICAL' "$perf" \
  || fail "$perf does not carry the WARNING/CRITICAL split for PERF-065/PERF-067"

# --- Direction 3: the live checks use the production-host contract, never the clone ---
grep -Fq 'cf-cache-status' "$perf" \
  || fail "$perf: PERF-066 does not read the cf-cache-status header"
grep -Fq 'server:' "$perf" \
  || fail "$perf: PERF-066 does not read the server response header"
grep -Fq 'never the local clone' "$perf" \
  || fail "$perf does not forbid probing the local clone for PERF-066/PERF-067"
grep -Fq 'Step 2.3' "$perf" \
  || fail "$perf does not point the live checks at /wp-audit Step 2.3's production-host contract"

# --- Direction 3b: PERF-066 requires a confirmed HIT, not the header's mere presence, and
#     recognizes CDNs/proxies other than Cloudflare ---
grep -Fq 'not merely present' "$perf" \
  || fail "$perf: PERF-066 does not reject cf-cache-status's mere presence as detection"
printf '%s' "$flat_perf" | grep -Fq 'DYNAMIC`/`BYPASS` on the second request mean' \
  || fail "$perf does not explain that DYNAMIC/BYPASS mean Cloudflare is present but not caching"
grep -Fq 'x-varnish' "$perf" \
  || fail "$perf: PERF-066 has no generic non-Cloudflare CDN/proxy heuristic (x-varnish)"
grep -Fq 'x-cache: HIT' "$perf" \
  || fail "$perf: PERF-066 has no generic x-cache heuristic"
grep -Fq '`age:`' "$perf" \
  || fail "$perf: PERF-066 has no generic age: heuristic"
# The bare token `UNMEASURED` already existed in the base file for an unrelated Core Web
# Vitals check, so a plain `grep -Fq '`UNMEASURED`'` would pass even with every UNMEASURED
# fallback below deleted. Anchor on the specific sentences instead.
printf '%s' "$flat_perf" | grep -Fq 'PERF-065, PERF-066 and PERF-067 are all `UNMEASURED`' \
  || fail "$perf's procedure does not fall back all three multi-currency-cache checks to UNMEASURED without a confirmed production URL"
grep -Fq '`UNMEASURED` ("needs the public URL") without a confirmed production URL, never `PASS`' "$perf" \
  || fail "$perf: PERF-065's own row does not condition PASS on a confirmed production URL (it must read UNMEASURED, never PASS, without one)"

# --- Direction 4: PERF-067 requires a live CONFIRMATION, not just the config-level guess ---
grep -Eq 'cf-cache-status`.*is `HIT`' "$perf" \
  || fail "$perf: PERF-067 does not name the HIT + stale-price combination as the confirmed defect"

# --- Direction 5: the fix is a setting, never a code workaround ---
grep -Fq 'Multi-currency cache-key fix' "$perf" \
  || fail "$perf has no fix section for PERF-065/PERF-067"
fix=$(awk '/^### Multi-currency cache-key fix/{f=1; next} f && /^### /{exit} f{print}' "$perf")
[ -n "$fix" ] || fail "$perf's Multi-currency cache-key fix section is empty"
printf '%s' "$fix" | grep -Fq 'Owner: setting' \
  || fail "the PERF-065/PERF-067 fix does not state Owner: setting"
printf '%s' "$fix" | grep -Fq 'Never propose disabling the page cache' \
  || fail "the PERF-065/PERF-067 fix does not reject disabling the cache site-wide as a shortcut"
printf '%s' "$fix" | grep -Fq 'no WP-CLI command reaches this' \
  || fail "the PERF-065/PERF-067 fix does not say a Cloudflare edge rule is out of WP-CLI's reach"

# --- SEO-069: reuses the existing rendered-head/json_ld snapshot, is not a second fetch, and
#     is not auto-fixed as if it were a theme code defect ---
grep -Fq 'json_ld' "$seo" \
  || fail "$seo has lost the json_ld snapshot field SEO-069 depends on"
grep -Fq 'SEO-069' "$seo" || fail "$seo never mentions SEO-069 outside its table row"
grep -Fq 'SEO-069 is never auto-applied' "$seo" \
  || fail "$seo does not exclude SEO-069 from the auto-fix pass"
grep -Fq 'there is no theme code to' "$seo" \
  || fail "$seo does not explain why SEO-069 has no code fix of its own"

# --- Direction 6: no code is defined twice. Sibling PRs add their own PERF-/SEO- rows to the
#     same agent files, so this asserts uniqueness of every table row instead of banning
#     specific numbers (a ban would fail as soon as a sibling PR merges). ---
for f in "$perf" "$seo"; do
  dups=$(grep -oE '^\| *(PERF|SEO)-[0-9]{3} *\|' "$f" | tr -d '| ' | sort | uniq -d)
  [ -z "$dups" ] || fail "$f defines these codes more than once: $dups"
done
for code in PERF-065 PERF-066 PERF-067; do
  grep -Eq "^\| *$code *\|" "$perf" || fail "$perf: $code has no table row"
done
grep -Eq '^\| *SEO-069 *\|' "$seo" || fail "$seo: SEO-069 has no table row"

# --- CHANGELOG: an Unreleased entry exists and names the new codes ---
unreleased=$(awk '/^## \[Unreleased\]/{f=1; next} f && /^## \[/{exit} f{print}' "$changelog")
[ -n "$unreleased" ] || fail "$changelog has no content under [Unreleased]"
printf '%s' "$unreleased" | grep -Fq 'PERF-065' \
  || fail "$changelog's [Unreleased] section does not mention PERF-065"
printf '%s' "$unreleased" | grep -Fq 'SEO-069' \
  || fail "$changelog's [Unreleased] section does not mention SEO-069"

echo PASS
