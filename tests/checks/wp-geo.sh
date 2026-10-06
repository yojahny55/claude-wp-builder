#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $1"; exit 1; }

skill=skills/wp-audit-geo-standards/SKILL.md
agent=agents/wp-audit-geo.md
fixer=agents/wp-agentic-surfaces.md
audit=commands/wp-audit.md
yolo=commands/wp-yolo.md
finalize=commands/wp-finalize.md
# The catalog, the surface specs and the citability rubric live in references/; SKILL.md keeps
# the scoring model, applicability, the crawler allowlist and the verification loop.
refs=skills/wp-audit-geo-standards/references
catalog=$refs/check-catalog.md
surfaces=$refs/surface-templates.md
citability=$refs/citability.md
for f in "$catalog" "$surfaces" "$citability"; do [ -f "$f" ] || fail "$f is missing"; done

for f in "$skill" "$agent" "$fixer"; do [ -f "$f" ] || fail "$f is missing"; done

# Skill: ORA layers as exact table rows. Bare '20'/'30'/'40'/'10' also match the
# citability weights, so they never proved the layer table; require the row shape.
for row in '| Discovery | 20 |' '| Access | 30 |' '| Usability | 40 |' '| Payments | 10 |'; do
  grep -qF "$row" "$skill" || fail "$skill missing layer row '$row'"
done
for t in required recommended emerging; do
  grep -q "$t" "$skill" || fail "$skill missing '$t'"
done
grep -qF 'share an **80**-point' "$skill" || fail "$skill missing the Essential-pool 80-point line"
grep -q 'ora.ai/api/checks' "$skill" || fail "$skill missing the ORA catalog endpoint"
grep -qE 'GEO-[DAUP]' "$skill" || fail "$skill missing GEO layer codes"

# Skill: AI crawler allowlist.
for bot in GPTBot OAI-SearchBot ChatGPT-User ClaudeBot PerplexityBot Google-Extended Applebot-Extended Amazonbot FacebookBot Bytespider; do
  grep -q "$bot" "$skill" || fail "$skill missing crawler $bot"
done

# Skill: citability rubric + site types + required mechanisms.
for t in '30%' '25%' '20%' '15%' '10%' '134-167' merchant 'local business' SaaS 'Content-Signal' 'text/markdown'; do
  grep -q "$t" "$skill" "$citability" "$surfaces" || fail "none of $skill, $citability, $surfaces contains '$t'"
done

# Auditor: model tier, report path, DOM parsing not regex.
grep -q '^model: sonnet' "$agent" || fail "$agent must be sonnet"
grep -q 'audit-results/geo.json' "$agent" || fail "$agent must write the GEO report"
grep -q 'DOMXPath' "$agent" || fail "$agent must parse the DOM, not regex the markup"

# Auditor: schema @id referential integrity. GEO-A07 only counts identity blocks, so a
# graph whose publisher points at an @id no node declares passes every other schema check
# while the engine falls back to the bare domain. Pin the rule, not just the code.
grep -qE '^\| GEO-A25 \|' "$agent" || fail "$agent must tabulate GEO-A25"
grep -qF 'appear in the declared set' "$agent" || fail "$agent GEO-A25 must resolve references against the declared @id values"
grep -q 'no ORA check id' "$agent" || fail "$agent must say GEO-A25 is outside the ORA score"
grep -qF '| GEO-A25 ' "$catalog" || fail "$catalog must catalog GEO-A25"

# Fixer: model tier and the theme file it owns.
grep -q '^model: sonnet' "$fixer" || fail "$fixer must be sonnet"
grep -q 'inc/agentic.php' "$fixer" || fail "$fixer must own inc/agentic.php"

# Auditor: local-business probe reads the ACF options-page value, never a raw option key.
grep -qE "get_field\('business_address','option'\)|options_business_address" "$agent" || fail "$agent must probe business_address via ACF options"
grep -q '<prefix>_business_address' "$agent" && fail "$agent must not look up <prefix>_business_address as an option"

# Fixer: the detected site type is baked into the theme constant.
grep -q 'AGENTIC_SITE_TYPE' "$fixer" || fail "$fixer must bake AGENTIC_SITE_TYPE"

# Live scanner: timeout wrapper is portable (GNU timeout / gtimeout / none).
grep -q 'gtimeout' bin/geo-scan.sh || fail "bin/geo-scan.sh must fall back to gtimeout"

# Security: the scanner must not download and execute npm packages unattended.
! grep -q 'npx' bin/geo-scan.sh || fail "bin/geo-scan.sh must not run npx (supply-chain risk)"
grep -q 'is-agentic.com/api/v1/report' bin/geo-scan.sh || fail "bin/geo-scan.sh must call the public report API"
# --start triggers a missing scan through the same HTTP endpoint the npm CLI uses, not the package.
grep -q 'is-agentic.com/api/scan/stream' bin/geo-scan.sh || fail "bin/geo-scan.sh --start must start a scan through /api/scan/stream"
# An SSE stream never closes on its own: the scan needs a limit that does not depend on a `timeout` binary.
grep -q -- '--max-time' bin/geo-scan.sh || fail "bin/geo-scan.sh --start must cap the scan stream with curl --max-time"
out=$(bash bin/geo-scan.sh example.com --bogus 2>&1) && status=0 || status=$?
[ "$status" -eq 1 ] || fail "bin/geo-scan.sh must reject an unknown flag with exit 1 (got $status)"
printf '%s\n' "$out" | grep -q 'usage:' || fail "bin/geo-scan.sh must print usage for an unknown flag"
# --start against a fake curl: the report API answers 404, the scan stream answers $STREAM.
geo_tmp=$(mktemp -d); trap 'rm -rf "$geo_tmp"' EXIT
cat > "$geo_tmp/curl" <<'SHIM'
#!/usr/bin/env bash
case "$*" in
  *scan/stream*) while [ $# -gt 0 ]; do [ "$1" = -o ] && o=$2; shift; done; printf '%b' "$STREAM" > "$o" ;;
  *) printf 404 ;;
esac
SHIM
chmod +x "$geo_tmp/curl"
geo_start() { STREAM="$1" PATH="$geo_tmp:$PATH" bash bin/geo-scan.sh example.com --start 2>/dev/null; }
out=$(geo_start ': {"type": "scan_complete"}\ndata: {"type": "progress"}\n') && status=0 || status=$?
[ "$status" -eq 2 ] && printf '%s' "$out" | grep -q 'did not complete' \
  || fail "geo-scan.sh --start must not read a completion event outside an SSE data: line"
out=$(geo_start 'data: {"type": "error", "message": "target unreachable"}\n') && status=0 || status=$?
[ "$status" -eq 2 ] && printf '%s' "$out" | grep -q 'target unreachable' \
  || fail "geo-scan.sh --start must report the server's error event when the scan fails"
out=$(geo_start 'event: x\ndata: {"type": "scan_complete"}\n') && status=0 || status=$?
[ "$status" -eq 2 ] && printf '%s' "$out" | grep -q 'report is not available yet' \
  || fail "geo-scan.sh --start must say the report is not ready after a completed scan"

# Fixer: the RFC 8288 Link header belongs on send_headers — wp_headers filters request headers.
grep -q 'send_headers' "$fixer" || fail "$fixer must emit the Link header on send_headers"
grep -qE "add_filter\\( *'wp_headers'" "$fixer" && fail "$fixer must not build the Link header on wp_headers"

# Fixer: Content-Signal must match the training-capable allowlist, not contradict it.
grep -q 'ai-train=yes' "$fixer" || fail "$fixer must declare ai-train=yes to match its allowlist"
grep -qE 'Content-Signal: *ai-train=no' "$fixer" && fail "$fixer must not emit ai-train=no while allowing training crawlers"

# Fixer: trust-anchor seeding calls the copy function; quoting it makes wp eval fatal.
grep -q "'<prefix>_trust_anchor_copy" "$fixer" && fail "$fixer must not quote the trust-anchor copy call"

# Fixer: llms-full is capped; an unbounded dump can exhaust memory on a large site.
grep -q "'posts_per_page' => 200" "$fixer" || fail "$fixer must cap llms-full.txt at 200 posts"
grep -q 'Never answer an empty 200' "$fixer" || fail "$fixer must 404 a missing area llms builder"

# Scanner: a full URL must be reduced to a bare host before building the API query.
grep -qF 'host="${host#*@}"' bin/geo-scan.sh || fail "bin/geo-scan.sh must strip userinfo/query/fragment from the host"

# Finalize: JS/CSS must not inflate the GEO-A01 count, and GEO-A02 parses robots.
grep -qF 's/<(script|style)' "$finalize" || fail "$finalize GEO-A01 must strip script/style before counting"
grep -qF 'BLOCKED ' "$finalize" || fail "$finalize GEO-A02 must detect a site-wide Disallow for a named bot"

# Wiring: --geo flag, dispatch names, and the live verifier in the finish phase.
grep -q -- '--geo' "$audit" || fail "$audit missing --geo"
grep -q 'wp-audit-geo' "$audit" || fail "$audit must dispatch wp-audit-geo"
grep -q 'wp-agentic-surfaces' "$audit" || fail "$audit must dispatch wp-agentic-surfaces"
grep -q -- '--geo' "$yolo" || fail "$yolo missing --geo"
grep -q 'geo-scan.sh' "$yolo" || fail "$yolo must run the live scan"
grep -q 'GEO & agent-readiness' "$finalize" || fail "$finalize missing the GEO readiness check"

# --- The skill restates what bin/geo-scan.sh and the fixer do, and it had drifted from both.
skill_flat=$(cat "$skill" "$catalog" "$surfaces" "$citability" | tr '\n' ' ' | sed 's/  */ /g')
agent_flat=$(tr '\n' ' ' < "$agent" | sed 's/  */ /g')
in_skill_docs() { case "$skill_flat" in *"$1"*) return 0 ;; *) return 1 ;; esac; }
skill_md_flat=$(tr '\n' ' ' < "$skill" | sed 's/  */ /g')
in_skill_md() { case "$skill_md_flat" in *"$1"*) return 0 ;; *) return 1 ;; esac; }

# A dev host exits 3, not 2: the skill told the auditor a localhost legitimately yields 2,
# which is the benign-skip reading geo-scan.sh split exit 3 off to prevent. And --start, which
# /wp-audit and /wp-yolo both pass, was never mentioned.
grep -q 'exit 3' bin/geo-scan.sh || fail "bin/geo-scan.sh no longer exits 3 for a non-public host -- update the skill and this check"
in_skill_docs '| `3` | the host is not publicly reachable' || fail "the GEO skill docs do not document geo-scan.sh exit 3"
in_skill_docs 'geo-scan.sh <domain|url> [--start]' || fail "the GEO skill docs do not give geo-scan.sh's real arguments"
in_skill_docs 'Pass `--start` only for a host the operator confirmed as public' || fail "the GEO skill docs do not say when --start is allowed"
in_skill_docs 'non-public URL legitimately yields exit `2`' && fail "the GEO skill docs still say a non-public host exits 2"

# Content-Signal is an HTTP header. The skill asked for a per-User-agent block in robots.txt as
# well -- the one line the fixer refuses to write, because it makes the whole file invalid.
in_skill_docs 'a per-`User-agent` block' && fail "the GEO skill docs still ask for Content-Signal inside robots.txt"
in_skill_docs 'Send the policy signal as an HTTP response header, and never as a line of `robots.txt`' \
  || fail "the GEO skill docs do not say Content-Signal is a header only"
case "$agent_flat" in *'carries a consistent `Content-Signal`'*) fail "$agent GEO-D02 still looks for Content-Signal inside robots.txt" ;; esac
grep -Eq '^\| GEO-D02 \|.*`Content-Signal` HTTP response header' "$agent" \
  || fail "$agent GEO-D02 does not read the Content-Signal header"

# A catalog store takes no payment: the payment codes are N/A on it, in the skill as in the auditor.
in_skill_docs 'site.store_tier` = `catalog`' || fail "the GEO skill docs do not read the recorded store tier"
in_skill_docs 'GEO-P01 to GEO-P05 are `N/A ("catalog: nothing purchasable")`' \
  || fail "the GEO skill docs score a catalog store for payment protocols it deliberately lacks"
in_skill_docs '`unknown` is not `catalog`' || fail "the GEO skill docs do not say an unknown tier audits as a store"

# The citability rubric has no GEO code; the skill claimed the auditor scored it.
in_skill_docs 'the auditor scores each page' && fail "the GEO skill docs still claim the auditor scores the citability rubric"

# The minimum robots body is the table's ALLOW rows, and the fixer writes the same list.
allow=$(grep -oE '^\| `[A-Za-z-]+` \|[^|]*\| ALLOW \|' "$skill" | sed -E 's/^\| `([A-Za-z-]+)`.*/\1/' | sort)
[ -n "$allow" ] || fail "$skill has no ALLOW rows in its crawler table"
for bot in $allow; do
  grep -qx "User-agent: $bot" "$surfaces" || fail "$skill allows $bot in its table but $surfaces leaves it out of the robots body"
done
fixer_bots=$(grep -oE '\$bots = array\([^)]*\)' "$fixer" | grep -oE "'[A-Za-z-]+'" | tr -d "'" | sort)
[ "$allow" = "$fixer_bots" ] || fail "the skill's ALLOW list and the fixer's robots \$bots list differ:
skill: $(echo $allow)
fixer: $(echo $fixer_bots)"
in_skill_docs 'alias of ClaudeBot' && fail "the GEO skill docs still call anthropic-ai an alias while the fixer called it training-only"
grep -Fq 'training-only, unlike `ClaudeBot`' "$fixer" && fail "$fixer still contradicts the skill on anthropic-ai"

# GEO-D04 is the /agents.md route the fixer serves; an auditor looking for a physical AGENTS.md
# reported the fix as missing.
grep -Eq '^\| GEO-D04 \|.*`/agents.md`' "$catalog" || fail "$catalog GEO-D04 does not name the /agents.md route"
grep -Eq '^\| GEO-D04 \|.*`GET /agents.md`' "$agent" || fail "$agent GEO-D04 does not request /agents.md"
grep -Fq "home_url( '/agents.md' )" "$fixer" || fail "$fixer no longer serves /agents.md -- update GEO-D04"

# GEO-A07 to GEO-A10 are fixable only when no SEO plugin owns the graph, as the fixer's Rule 4 says.
for code in GEO-A07 GEO-A08 GEO-A09 GEO-A10; do
  grep -Eq "^\| $code \|.*when no SEO plugin owns the graph" "$catalog" \
    || fail "$catalog marks $code fixable with no condition, though the fixer returns early under an SEO plugin"
done

# --- Contracts the skill carries that nothing pinned -----------------------------------------
# The plugin-added codes, reported outside the ORA score so it stays reproducible.
for code in GEO-A25 GEO-A26 GEO-A27 GEO-A28; do
  grep -qF "| $code " "$catalog" || fail "$catalog lost the $code row"
done
in_skill_docs 'are **plugin-added**' || fail "the GEO skill no longer says GEO-A25 to GEO-A28 sit outside the ORA score"
# A registered REST namespace marked every Rank Math site as SaaS.
in_skill_docs 'A registered REST namespace is **not** a signal' || fail "the GEO skill docs lost the REST-namespace rule"
# The signal must match the allowlist.
in_skill_docs 'the matching signal is `ai-train=yes`' || fail "the GEO skill docs lost the Content-Signal / allowlist consistency rule"
# A deliberate block is the owner's answer: reported, never rewritten to the default.
in_skill_docs 'it never rewrites a deliberate block back to the default' || fail "the GEO skill docs let the fixer overwrite a deliberate crawler block"
grep -Fq 'deliberate block' "$fixer" || fail "$fixer Step 4 overwrites an owner's deliberate crawler block"
grep -Fq 'deliberate block' "$agent" || fail "$agent reports an owner's deliberate crawler block as a failure"
# The verification loop stops, and a pre-fix report is never read as resolved.
in_skill_docs 'A report whose scan time precedes the fix is the old report' || fail "the GEO skill docs read a stale scan as the post-fix result"
in_skill_docs 'Stop after that one re-scan' || fail "the GEO skill docs' verification loop has no stop"
# A reader of the installed plugin cannot resolve the gitignored design spec. Scoped to SKILL.md,
# the file these rules were written against: a reference may use the words in another sense.
in_skill_md 'design spec' && fail "$skill cites the design spec, which does not ship"
in_skill_md 'spec §7.3' && fail "$skill cites the design spec, which does not ship"
in_skill_md 'for WooCommerce today' && fail "$skill dates its payment rule instead of giving the reason"
# The citability rubric carries a worked rewrite.
grep -Fq '## A rewrite, weak to strong' "$citability" || fail "$citability has no before/after passage"
# The two commands that apply the rubric point at where it lives now.
for c in commands/wp-seed.md commands/wp-section.md; do [ -f "$c" ] || fail "$c is missing"; done
for c in commands/wp-seed.md commands/wp-section.md; do
  grep -Fq 'skills/wp-audit-geo-standards/references/citability.md' "$c" || fail "$c does not point at the citability rubric"
  grep -Fq 'skills/wp-audit-geo-standards/SKILL.md` §5' "$c" && fail "$c still points at the rubric's old place"
done

# --- One answer to "is this a store": WooCommerce active, the same test /wp-audit Step 2.3 records.
# Scoped to the three GEO files: elsewhere is-installed is right (install it if missing), and a
# sentence that forbids it ("is-active, not is-installed") is not a detection. Case- and
# backtick-tolerant, and reported by line, because a capital letter defeated the literal before.
stale=$(grep -niE 'is-installed[[:space:]]+`?woocommerce' "$agent" "$fixer" "$skill" | grep -v 'is-active' || true)
[ -z "$stale" ] || fail "a GEO file still detects a merchant with is-installed:
$stale"
for f in "$agent" "$fixer" "$skill"; do
  grep -Fq 'is-active woocommerce' "$f" || fail "$f does not detect a merchant with is-active"
  grep -Fq 'site.commerce' "$f" || fail "$f does not read site.commerce from /wp-audit Step 2.3, so it keeps a second answer to 'is this a store'"
done

echo PASS
