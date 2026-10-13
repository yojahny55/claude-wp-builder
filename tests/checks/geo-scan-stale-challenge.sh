#!/usr/bin/env bash
# bin/geo-scan.sh read two kinds of report as the site's current score when they were not:
# a report scanned days ago (it printed whatever existed, exit 0, whatever its age), and a
# report of a bot-challenge interstitial the scanner was served instead of the site (the
# brand search was "One moment, please...", the JSON-LD and sitemap "not found"). Both fed
# a score into the audit that described neither the site nor the fix just applied.
# Tested by behavior: a fake curl on PATH serves fixture reports.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fresh_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
old_ts=$(date -u -d '2 days ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-2d +%Y-%m-%dT%H:%M:%SZ)
mk() { printf '{"score":%s,"scanned_at":"%s","issues":[{"id":"brand-search","detail":"%s"}]}' "$1" "$2" "$3" > "$4"; }
mk 80 "$old_ts"   "ok" "$tmp/old.json"
mk 82 "$fresh_ts" "ok" "$tmp/fresh.json"
mk 28 "$fresh_ts" 'searched your brand name alone for \"One moment, please...\"' "$tmp/challenge.json"
mk 28 "$fresh_ts" 'script /cdn-cgi/challenge-platform/h/b _cf_chl_opt' "$tmp/challenge2.json"
# A healthy site behind Cloudflare: the injected challenge-platform script alone is no challenge.
mk 82 "$fresh_ts" 'script /cdn-cgi/challenge-platform/scripts/jsd/main.js' "$tmp/benign.json"

# First report fetch answers $REPORT; once the scan stream has run, it answers $AFTER.
cat > "$tmp/curl" <<'SHIM'
#!/usr/bin/env bash
o=""; a=("$@")
for ((i=0;i<${#a[@]};i++)); do [ "${a[i]}" = -o ] && o=${a[i+1]}; done
case "$*" in
  *scan/stream*) touch "$SCANNED"; printf 'data: {"type": "scan_complete"}\n' > "$o" ;;
  *) if [ -e "$SCANNED" ]; then cp -f "$AFTER" "$o"; else cp -f "$REPORT" "$o"; fi; printf 200 ;;
esac
SHIM
chmod +x "$tmp/curl"
run() { # report after args... ; sets out, err, status
  rm -f "$tmp/scanned"
  REPORT="$1" AFTER="$2" SCANNED="$tmp/scanned" PATH="$tmp:$PATH" \
    bash bin/geo-scan.sh example.com "${@:3}" >"$tmp/out" 2>"$tmp/err" && status=0 || status=$?
  out=$(cat "$tmp/out"); err=$(cat "$tmp/err")
}

run "$tmp/fresh.json" "$tmp/fresh.json" --start
[ "$status" -eq 0 ] || fail "a fresh report must exit 0 (got $status)"
grep -q "scanned_at $fresh_ts" <<<"$err" || fail "the report's age must always be printed on stderr"
grep -q '"score":82' <<<"$out" || fail "a fresh report must be printed"

run "$tmp/old.json" "$tmp/fresh.json" --start
[ "$status" -eq 0 ] && grep -q '"score":82' <<<"$out" && [ -e "$tmp/scanned" ] \
  || fail "a stale report with --start must trigger a scan and print the fresh report (status $status)"

run "$tmp/old.json" "$tmp/old.json" --start
[ "$status" -eq 4 ] || fail "a stale report that could not be refreshed must exit 4 (got $status)"
grep -q '^STALE:' <<<"$err" || fail "a stale report must be marked with a STALE: line on stderr"
grep -q "scanned $old_ts" <<<"$err" || fail "the STALE line must name the report's scan time"
grep -q '"score":80' <<<"$out" || fail "the old report must still be printed when it cannot be refreshed"

run "$tmp/old.json" "$tmp/old.json"
[ "$status" -eq 4 ] && [ ! -e "$tmp/scanned" ] \
  || fail "without --start a stale report is marked (exit 4) and no scan is requested"

run "$tmp/old.json" "$tmp/old.json" --max-age-hours 100
[ "$status" -eq 0 ] || fail "--max-age-hours must raise the limit (got $status)"

for c in challenge challenge2; do
  run "$tmp/$c.json" "$tmp/$c.json" --start
  [ "$status" -eq 2 ] || fail "a challenged report ($c) must exit 2 (got $status)"
  grep -q 'CHALLENGED' <<<"$out" || fail "a challenged report ($c) must say CHALLENGED"
  ! grep -q '"score"' <<<"$out" || fail "a challenged report ($c) must not print its score as valid"
done

run "$tmp/benign.json" "$tmp/benign.json" --start
[ "$status" -eq 0 ] && grep -q '"score":82' <<<"$out" \
  || fail "a lone challenge-platform script must not make a healthy report CHALLENGED (got $status)"

# The docs name the new exit and the report line.
grep -Fq '| `4` |' skills/wp-audit-geo-standards/SKILL.md || fail "GEO skill exit table lacks exit 4"
grep -Fq '| `4` |' skills/wp-audit-run/references/fix.md || fail "fix.md exit table lacks exit 4"
grep -Fq 'challenged by a bot interstitial' skills/wp-audit-run/references/fix.md || fail "fix.md lacks the challenged Live scan wording"
grep -Fq 'stale: scanned' skills/wp-audit-run/references/fix.md || fail "fix.md lacks the stale Live scan wording"

echo PASS
