#!/usr/bin/env bash
# A multi-currency plugin (CURCY/woocommerce-multi-currency is one shape of this) computes a
# per-currency price per request, usually from a cookie. A full-page or edge cache computes
# what to serve per cache key. When the key does not vary on the currency signal, the first
# visitor's currency is cached and served to everyone else — wrong prices, and the cached
# Product/Offer schema is wrong alongside them, since both come from the same response.
#
# Defects this contract prevents, each one a false-clean audit on a store that has this plugin
# combination:
#   1. The risk check (PERF-065) fires on any store, whether or not it runs WooCommerce or a
#      multi-currency plugin, scoring a site for a cart or a plugin it never had. All three
#      performance codes (PERF-065, PERF-066, PERF-067) and SEO-069 must gate on site.commerce
#      and on a multi-currency plugin being active, same as every other commerce check
#      /wp-audit Step 2.3 already requires — including PERF-066, a detection-only INFO code
#      whose live requests are still pointless work when PERF-065/PERF-067 are already N/A.
#   2. The live checks (PERF-066, PERF-067, SEO-069) get fired at the local clone, whose own
#      server has no CDN in front of it — a false PASS/"no cache" reading exactly like probing
#      the clone for response headers or paid-file reachability. They must target a confirmed
#      production host and read UNMEASURED without one.
#   3. The fix gets written as a code change (a performance.php cache-bypass rule) instead of
#      what it actually is: a setting on a cache plugin or an edge service this plugin does not
#      own. A code fix here is a no-op on a Cloudflare edge cache, which no .htaccess reaches.
#   4. Detecting "a multi-currency plugin" by a bare `currency` substring both false-positives
#      on decorative rate-display widgets and misses plugins (price-by-country) that produce
#      the same defect without the word "currency" in their slug. The check must use a
#      confirmed slug list, report a substring-only match as UNCONFIRMED, and document the gap.
#   5. SEO-069 has no mechanism to reuse PERF-067's live result (the two agents run
#      independently) and the rendered-head/json_ld snapshot it might be tempted to reuse
#      instead is a *local* self-fetch, not a production, cache-sensitive read. It must make
#      its own production request pair and say so, not claim to reuse someone else's.
#
# The wording IS the behavior, so assert both directions: the contract present, and the
# discarded shape (probing the clone, treating every combination as one flat severity, fixing
# it with code, a bare substring match, an impossible cross-agent reuse) named as wrong.
set -euo pipefail

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
# grep would miss even though the sentence reads fine to a human. Read with a herestring, not
# a `printf | grep -q` pipe: under `pipefail`, `grep -q` can close its end of the pipe as soon
# as it finds a match, and if the writer is still flushing output when that happens it gets
# SIGPIPE — pipefail then reports that as the pipeline's exit status even though the match was
# found, turning a passing check into a spurious failure. A herestring has no pipe to break.
flat_perf=$(tr '\n' ' ' < "$perf" | sed 's/  */ /g')
flat_seo=$(tr '\n' ' ' < "$seo" | sed 's/  */ /g')

# --- Codes exist and are tabulated (audit-check-tables.sh's own rule, pinned here too so this
#     one test file tells the whole story on its own) ---
for code in PERF-065 PERF-066 PERF-067; do
  grep -qE "^\| ${code} \|" "$perf" || fail "$perf has no tabulated row for $code"
done
grep -qE '^\| SEO-069 \|' "$seo" || fail "$seo has no tabulated row for SEO-069"

# --- Direction 1: the commerce/multi-currency gate is present, both reasons, on ALL THREE
#     performance codes individually — not just somewhere in the file ---
perf065_row=$(grep -E '^\| PERF-065 \|' "$perf")
perf066_row=$(grep -E '^\| PERF-066 \|' "$perf")
perf067_row=$(grep -E '^\| PERF-067 \|' "$perf")
seo069_row=$(grep -E '^\| SEO-069 \|' "$seo")

# PERF-065, PERF-066 and SEO-069 spell the N/A reasons out; PERF-067 is allowed to point at
# them instead ("Same N/A/UNMEASURED gates as ...") rather than repeat the same two strings a
# fourth time — but it must still point somewhere, not drop the gate silently.
for pair in "PERF-065:$perf065_row" "PERF-066:$perf066_row" "SEO-069:$seo069_row"; do
  code=${pair%%:*}
  row=${pair#*:}
  grep -Fq '"no WooCommerce"' <<< "$row" \
    || fail "$code's own row does not give the N/A (no WooCommerce) reason"
  grep -Fq '"no multi-currency plugin"' <<< "$row" \
    || fail "$code's own row does not give the N/A (no multi-currency plugin) reason"
done
grep -Fq 'Same `N/A`/`UNMEASURED` gates as PERF-065/PERF-066' <<< "$perf067_row" \
  || fail "PERF-067's own row does not point at the gate it shares with PERF-065/PERF-066"
# Both directions on the gate: it must also be stated that these are commerce-only, not a
# blanket "always N/A" that would silently disable the check everywhere.
grep -Fq 'site.commerce' "$perf" \
  || fail "$perf does not read site.commerce, so PERF-065 cannot be commerce-gated at all"
# The procedure must say the gate covers all three codes, PERF-066 (INFO, detection-only)
# included, not just the two with a severity of their own.
grep -Fq 'PERF-066 included, even though it is a detection-only INFO code' <<< "$flat_perf" \
  || fail "$perf's procedure does not explicitly extend the gate to PERF-066"

# --- Direction 2: severity is NOT one flat value — cookie/session selection escalates ---
grep -Fq 'cookie- or session-selected currency is invisible' "$perf" \
  || fail "$perf: PERF-065 does not escalate to CRITICAL for cookie/session currency selection"
grep -Fq 'that combination is the CRITICAL case' <<< "$flat_perf" \
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
grep -Fq 'DYNAMIC`/`BYPASS` on the second request mean' <<< "$flat_perf" \
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
grep -Fq 'PERF-065, PERF-066 and PERF-067 are all `UNMEASURED`' <<< "$flat_perf" \
  || fail "$perf's procedure does not fall back all three multi-currency-cache checks to UNMEASURED without a confirmed production URL"
grep -Fq '`UNMEASURED` ("needs the public URL") without a confirmed production URL, never `PASS`' "$perf" \
  || fail "$perf: PERF-065's own row does not condition PASS on a confirmed production URL (it must read UNMEASURED, never PASS, without one)"

# --- Direction 4: PERF-067 requires a live CONFIRMATION, not just the config-level guess ---
grep -Eq 'cf-cache-status`.*is `HIT`' "$perf" \
  || fail "$perf: PERF-067 does not name the HIT + stale-price combination as the confirmed defect"

# --- Direction 5: the fix is a setting, never a code workaround ---
grep -Fq 'Multi-currency cache-key fix' "$perf" \
  || fail "$perf has no fix section for PERF-065/PERF-067"
# The fix section runs from its own heading to the "## Rules" heading that follows it today.
# Both ends are named, so a failure says which one moved: a heading of any level that shows up
# inside the extract means the section's shape changed and this end marker needs a look.
fix=$(awk '/^### Multi-currency cache-key fix/{f=1; next} f && /^## Rules/{exit} f{print}' "$perf")
[ -n "$fix" ] || fail "$perf's Multi-currency cache-key fix section is empty"
inner=$(grep -E '^#{1,6} ' <<< "$fix" || true)
[ -z "$inner" ] \
  || fail "the Multi-currency cache-key fix is no longer followed directly by ## Rules (found: $inner) — move this gate's end marker to the heading that now closes the section"
grep -Fq 'Owner: setting' <<< "$fix" \
  || fail "the PERF-065/PERF-067 fix does not state Owner: setting"
grep -Fq 'Never propose disabling the page cache' <<< "$fix" \
  || fail "the PERF-065/PERF-067 fix does not reject disabling the cache site-wide as a shortcut"
grep -Fq 'no WP-CLI command reaches this' <<< "$fix" \
  || fail "the PERF-065/PERF-067 fix does not say a Cloudflare edge rule is out of WP-CLI's reach"

# --- Direction 6: no code is defined twice. Sibling PRs add their own PERF-/SEO- rows to the
#     same agent files, so instead of banning specific numbers (a ban would fail as soon as a
#     sibling PR merges), every code the file mentions with its own prefix must have exactly one
#     defining row: a line whose first cell is that code. A mention in any other column or in
#     prose is a reference, not a definition. ---
for spec in "$perf:PERF" "$seo:SEO"; do
  f=${spec%%:*}
  prefix=${spec##*:}
  codes=$(grep -oE "${prefix}-[0-9]{3}" "$f" | sort -u || true)
  [ -n "$codes" ] || fail "$f mentions no ${prefix}- code at all"
  for code in $codes; do
    n=$(CODE="$code" awk -F'|' '/^\|/ { c = $2; gsub(/^[ \t]+|[ \t]+$/, "", c); if (c == ENVIRON["CODE"]) k++ } END { print k + 0 }' "$f")
    [ "$n" = 1 ] || fail "$f: $code has $n defining table rows, expected exactly 1"
  done
done
for code in PERF-065 PERF-066 PERF-067; do
  grep -Eq "^\| *$code *\|" "$perf" || fail "$perf: $code has no table row"
done
grep -Eq '^\| *SEO-069 *\|' "$seo" || fail "$seo: SEO-069 has no table row"

# --- Direction 7: multi-currency detection uses a confirmed slug list, not a bare `currency`
#     substring — the substring both false-positives (a decorative rate-display widget) and
#     misses plugins that produce the same defect without the word "currency" in their slug
#     (price-by-country) ---
for slug in 'woocommerce-multi-currency' 'woocommerce-currency-switcher' \
            'woocommerce-aelia-currencyswitcher' 'woocommerce-multilingual' \
            'woocommerce-payments'; do
  grep -Fq "$slug" "$perf" || fail "$perf's confirmed multi-currency slug list is missing $slug"
done
grep -Fq 'UNCONFIRMED' "$perf" \
  || fail "$perf does not report a bare currency-substring match as UNCONFIRMED"
grep -Fq 'never flagged as the multi-currency plugin outright' <<< "$flat_perf" \
  || fail "$perf does not say a substring match alone must not be flagged outright"
grep -Fq 'price by country or geography' <<< "$flat_perf" \
  || fail "$perf does not document the price-by-country detection gap"
grep -Fq 'confirmed multi-currency plugin slugs' "$perf" \
  || fail "$perf's PERF-065 row does not point at the confirmed slug list"

# --- SEO-069: makes its own live production request pair — it has no mechanism to reuse
#     PERF-067's result (separate agents), and the rendered-head/json_ld snapshot is a local
#     self-fetch that cannot stand in for a production, cache-sensitive read ---
grep -Fq 'json_ld' "$seo" \
  || fail "$seo has lost the json_ld snapshot field (still used by the other rendered-head checks)"
grep -Fq 'SEO-069' "$seo" || fail "$seo never mentions SEO-069 outside its table row"
grep -Fq 'SEO-069 is never auto-applied' "$seo" \
  || fail "$seo does not exclude SEO-069 from the auto-fix pass"
grep -Fq 'there is no theme code to' "$seo" \
  || fail "$seo does not explain why SEO-069 has no code fix of its own"
grep -Fq 'own request pair' "$seo" \
  || fail "$seo: SEO-069's table row does not say it makes its own request pair"
grep -Fq 'not a reuse' "$seo" \
  || fail "$seo does not say SEO-069 is not a reuse of PERF-067's result"
grep -Fq 'no mechanism' <<< "$flat_seo" \
  || fail "$seo does not explain that the two agents have no mechanism to share a live result"
grep -Fq 'that snapshot is' <<< "$flat_seo" \
  || fail "$seo's procedure does not explain why the rendered-head/json_ld snapshot cannot stand in for SEO-069's production read"

# --- CHANGELOG: an Unreleased entry exists and names the new codes ---
unreleased=$(awk '/^## \[Unreleased\]/{f=1; next} f && /^## \[/{exit} f{print}' "$changelog")
[ -n "$unreleased" ] || fail "$changelog has no content under [Unreleased]"
grep -Fq 'PERF-065' <<< "$unreleased" \
  || fail "$changelog's [Unreleased] section does not mention PERF-065"
grep -Fq 'SEO-069' <<< "$unreleased" \
  || fail "$changelog's [Unreleased] section does not mention SEO-069"

echo PASS
