#!/usr/bin/env bash
# /wp-audit against production: seven agents ran in parallel against one host behind
# fail2ban, CrowdSec and ModSecurity, up to 28 requests in flight plus Lighthouse and
# Playwright, and the host banned the auditing IP within five minutes. Every live check of
# the run was lost, and an agent's retries lengthened the ban.
#
# bin/prod-gate.sh must serialize and pace what reaches a public host, refuse every call
# once the host is blocked, and leave a local host untouched. The audit must still measure
# the same things: the suite keeps its tests and only drops to one worker for a public URL,
# and link-sweep only gains an opt-in delay. This check runs the gate for real with fake
# commands, and greps the contract into every agent that sends live requests.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

gate=bin/prod-gate.sh
[ -x "$gate" ] || fail "$gate missing or not executable"
command -v flock >/dev/null 2>&1 || { echo "SKIP: flock not available"; echo PASS; exit 0; }
command -v timeout >/dev/null 2>&1 || { echo "SKIP: timeout not available"; echo PASS; exit 0; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export WP_AUDIT_GATE_DIR="$tmp/gate"

# 1. A local host is passed straight through: no lock, no pacing state.
out="$("$gate" http://site.local.com -- echo local-ok)"
[ "$out" = "local-ok" ] || fail "local host did not run the command"
[ ! -e "$WP_AUDIT_GATE_DIR/site.local.com.last" ] || fail "local host left pacing state"

# 2. Two concurrent calls to one public host run one after the other, --delay apart.
#    The timing needs sub-second clock reads; BSD date prints a literal N for %N.
case "$(date +%s.%N)" in *N*) echo "SKIP: date has no %N"; echo PASS; exit 0 ;; esac
log="$tmp/order.log"
job() { "$gate" --delay 1 https://example.org/x -- bash -c "echo start-$1 \$(date +%s.%N) >> '$log'; sleep 1; echo end-$1 \$(date +%s.%N) >> '$log'"; }
job a & job b & wait
starts=$(grep -c '^start-' "$log"); [ "$starts" -eq 2 ] || fail "expected 2 gated runs, got $starts"
first_end=$(awk '/^end-/{print $2; exit}' "$log")
second_start=$(awk '/^start-/{n++; if(n==2){print $2; exit}}' "$log")
awk -v e="$first_end" -v s="$second_start" 'BEGIN{exit !(s >= e + 0.9)}' \
  || fail "second call started before the first ended plus --delay (end $first_end, start $second_start)"

# 3. curl's connection-refused exit marks the host blocked; the next call sends nothing.
mkdir -p "$tmp/bin"
printf '#!/usr/bin/env bash\nexit 7\n' > "$tmp/bin/curl"; chmod +x "$tmp/bin/curl"
set +e
PATH="$tmp/bin:$PATH" "$gate" --delay 0 https://blocked.example -- curl -sS https://blocked.example/ 2>/dev/null
rc=$?
"$gate" --delay 0 https://blocked.example -- touch "$tmp/should-not-exist" >/dev/null
rc2=$?
set -e
[ "$rc" -eq 7 ] || fail "gate did not return curl's own exit code (got $rc)"
[ "$rc2" -eq 4 ] || fail "a blocked host did not exit 4 (got $rc2)"
[ ! -e "$tmp/should-not-exist" ] || fail "a blocked host still ran the command"

# 4. --mark-blocked and --status, for a 429 or a WAF 403 the caller recognised.
"$gate" --mark-blocked https://waf.example "HTTP 429" >/dev/null
set +e; "$gate" --status https://waf.example >/dev/null; rc3=$?; set -e
[ "$rc3" -eq 4 ] || fail "--status did not report a marked host as blocked"

# 4b. One key per server: a query, a fragment or a port must not escape the blocked flag.
set +e
"$gate" --delay 0 'https://waf.example?author=1' -- touch "$tmp/q" >/dev/null; rq=$?
"$gate" --delay 0 'https://waf.example:443/x' -- touch "$tmp/p" >/dev/null; rp=$?
set -e
[ "$rq" -eq 4 ] && [ ! -e "$tmp/q" ] || fail "a ?query URL escaped the blocked host"
[ "$rp" -eq 4 ] && [ ! -e "$tmp/p" ] || fail "a :port URL escaped the blocked host"

# 4c. A flag with no value exits 1 instead of looping.
set +e; timeout 5 "$gate" --delay >/dev/null 2>&1; rv=$?; set -e
[ "$rv" -eq 1 ] || fail "--delay with no value did not exit 1 (got $rv)"

# 4d. A background process left by the command does not keep the host locked.
"$gate" --delay 0 https://bg.example -- bash -c 'sleep 6 >/dev/null 2>&1 &'
t0=$(date +%s)
"$gate" --delay 0 --wait 3 https://bg.example -- true || fail "a leftover child held the host's lock"
[ $(( $(date +%s) - t0 )) -lt 3 ] || fail "the next call waited on a leftover child"

# 4e. Two curl timeouts in a row (a DROP ban) mark the host blocked.
printf '#!/usr/bin/env bash\nexit 28\n' > "$tmp/bin/curl"
set +e
PATH="$tmp/bin:$PATH" "$gate" --delay 0 https://drop.example -- timeout 30 curl https://drop.example/ 2>/dev/null
PATH="$tmp/bin:$PATH" "$gate" --delay 0 https://drop.example -- timeout 30 curl https://drop.example/ 2>/dev/null
"$gate" --status https://drop.example >/dev/null; rd=$?
set -e
[ "$rd" -eq 4 ] || fail "two curl timeouts (curl wrapped in timeout) did not mark the host blocked"

# 4e2. Any other result between two timeouts breaks the run: timeout, success, timeout is not a ban.
printf '#!/usr/bin/env bash\nexit "${FAKE_RC:-28}"\n' > "$tmp/bin/curl"
set +e
PATH="$tmp/bin:$PATH" "$gate" --delay 0 https://flaky.example -- curl https://flaky.example/ 2>/dev/null
FAKE_RC=0 PATH="$tmp/bin:$PATH" "$gate" --delay 0 https://flaky.example -- curl https://flaky.example/ 2>/dev/null
PATH="$tmp/bin:$PATH" "$gate" --delay 0 https://flaky.example -- curl https://flaky.example/ 2>/dev/null
"$gate" --status https://flaky.example >/dev/null; rf=$?; set -e
[ "$rf" -eq 0 ] || fail "a successful curl between two timeouts did not reset the timeout count"

# 4f. A command that is not curl is not judged as curl, even with an argument ending in /curl.
printf '#!/usr/bin/env bash\nexit 7\n' > "$tmp/bin/notcurl"
set +e; PATH="$tmp/bin:$PATH" "$gate" --delay 0 https://argcurl.example -- notcurl https://argcurl.example/api/curl 2>/dev/null
"$gate" --status https://argcurl.example >/dev/null; ra=$?; set -e
[ "$ra" -eq 0 ] || fail "a non-curl command with a /curl argument marked the host blocked"

# 4f2. Nested wrappers and timeout options with a separate value still reach curl.
set +e
PATH="$tmp/bin:$PATH" "$gate" --delay 0 https://nest.example -- timeout -s KILL 30 env FOO=1 curl https://nest.example/ 2>/dev/null
PATH="$tmp/bin:$PATH" "$gate" --delay 0 https://nest.example -- timeout -k 5 30 env FOO=1 curl https://nest.example/ 2>/dev/null
PATH="$tmp/bin:$PATH" "$gate" --delay 0 https://envu.example -- env -u HOME curl https://envu.example/ 2>/dev/null
PATH="$tmp/bin:$PATH" "$gate" --delay 0 https://envu.example -- env -u HOME curl https://envu.example/ 2>/dev/null
"$gate" --status https://envu.example >/dev/null; ru=$?
"$gate" --status https://nest.example >/dev/null; rn=$?; set -e
[ "$ru" -eq 4 ] || fail "curl under 'env -u HOME' was not judged as curl"
[ "$rn" -eq 4 ] || fail "curl under 'timeout -s KILL 30 env' was not judged as curl"

# 4g. Private ranges match a dotted IPv4 address only: a host name or a public address that
#     shares the prefix is gated.
for h in 10.example.com 172.160.0.1 192.168.example.com; do
  "$gate" --delay 0 "https://$h" -- true
  [ -e "$WP_AUDIT_GATE_DIR/$(printf '%s' "$h" | tr -c 'a-z0-9.-' '_').last" ] || fail "$h was treated as a local host"
done
for h in 10.0.0.5 172.20.1.1 192.168.1.10 127.0.0.1; do
  "$gate" --delay 0 "https://$h" -- true
  [ ! -e "$WP_AUDIT_GATE_DIR/$(printf '%s' "$h" | tr -c 'a-z0-9.-' '_').last" ] || fail "$h was not treated as a local host"
done


# 5. The measurement is unchanged: the suite keeps its tests and paces only a public URL,
#    and link-sweep's delay is opt-in.
grep -Fq 'pw_args=(--workers=1)' bin/audit-suite.sh || fail "audit-suite.sh no longer drops to one worker for a public URL"
grep -Fq '*.local.com|*.local.com:*' bin/audit-suite.sh || fail "audit-suite.sh lost the local-host exemption"
node bin/link-sweep.mjs --help | grep -Fq -- '--delay-ms' || fail "link-sweep.mjs does not accept --delay-ms"
grep -Fq 'delayMs: 0' bin/link-sweep.mjs || fail "link-sweep.mjs --delay-ms is no longer off by default"
grep -Fq 'stopOnBlock: false' bin/link-sweep.mjs || fail "link-sweep.mjs --stop-on-block is no longer opt-in"
grep -Fq 'if (o.stopOnBlock && (res.status === 429' bin/link-sweep.mjs \
  || fail "link-sweep.mjs reclassifies 429/403 even without --stop-on-block (a local sweep would measure differently)"

# 6. The contract reaches everyone who sends live requests.
grep -Fq '### Production sits behind a WAF: same measurements, one request at a time' skills/wp-audit-standards/SKILL.md \
  || fail "wp-audit-standards lost the production pacing rule"
grep -Fq 'the pace, never the measurement' skills/wp-audit-standards/SKILL.md \
  || fail "wp-audit-standards no longer says the gate leaves measurement unchanged"
grep -Fq 'prod-gate.sh' commands/wp-audit.md || fail "wp-audit.md does not pass the gate to its agents"
grep -Fq 'Gate dir: <scratch>/prod-gate' commands/wp-audit.md || fail "wp-audit.md dispatch prompt lost the gate dir"
for a in security seo a11y performance geo ux; do
  grep -Fq 'Requests to a production host go through `bin/prod-gate.sh`' "agents/wp-audit-$a.md" \
    || fail "agents/wp-audit-$a.md does not route production requests through the gate"
done

for bad in 1.2.3 ...  .; do
  set +e; "$gate" --delay "$bad" https://example.org/x -- true >/dev/null 2>&1; rd=$?; set -e
  [ "$rd" -eq 1 ] || fail "--delay $bad was accepted (exit $rd)"
done
# Run-mode diagnostics go to stderr, so a wrapped command's stdout stays parseable.
out="$("$gate" --delay 0 https://blocked.example -- true 2>/dev/null)" || true
[ -z "$out" ] || fail "a blocked run wrote to stdout: $out"

# Exit 5: a host whose lock is held longer than --wait is not sent to, and the command does not run.
"$gate" --delay 0 https://busy.example -- sleep 4 >/dev/null 2>&1 &
sleep 1
set +e; "$gate" --delay 0 --wait 1 https://busy.example -- touch "$tmp/busy" >/dev/null 2>&1; rb=$?; set -e
wait
[ "$rb" -eq 5 ] || fail "a held lock did not exit 5 after --wait (got $rb)"
[ ! -e "$tmp/busy" ] || fail "the command ran although the lock was held"

echo PASS
