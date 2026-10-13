#!/usr/bin/env bash
# Live GEO/agent-readiness scan via the public is-agentic report API.
# Exit 0 = report returned, 1 = request failed, 2 = skipped (no curl / no report / no
# network), 3 = the host is not publicly reachable, so no scan is possible for it.
#
# 4 = a report came back and is printed, but it is older than the age limit (24 h; see
# --max-age-hours) and could not be refreshed: the score describes the site as it was, not
# as it is. A `STALE:` line on stderr says how old.
#
# A report whose body is a CDN/hosting bot-challenge page (the scanner was served an
# interstitial, not the site) exits 2 with a `SKIP: CHALLENGED` line: its score describes the
# challenge page, so it is neither a pass nor a failure of the site.
#
# 3 is separated from 2 on purpose. A dev host is a configuration problem with a fix --
# pass the public URL -- while 2 is a genuine absence of a report. Collapsing them, as
# this script used to, makes every project whose manifest still holds a .local URL look
# like a site nobody has scanned yet, and the audit reports it as a benign skip forever.
#
# No package execution. The previous version downloaded and ran an npm CLI, which /wp-yolo
# runs unattended in its finish phase — a compromised package, alias or registry could
# execute code on the build host. The public report API is a read-only GET; curl executes
# nothing. A missing report starts with the site owner running one scan at
# https://is-agentic.com, which this script then reads.
#
# --start closes that gap without the package: when no report exists, it asks the same
# endpoint the npm CLI calls (GET /api/scan/stream, a server-sent-event stream), waits for
# the scan to finish, and reads the report. Still a GET, still curl, still nothing executed
# here. It is opt-in because a scan makes is-agentic fetch the site: the caller passes it
# only for a host the operator confirmed as public this run. The same call refreshes a
# report that already exists but is older than the age limit: is-agentic offers no separate
# re-scan endpoint, so a stale report is re-requested through this one and, if the scan does
# not produce a newer report, printed marked STALE.
set -euo pipefail

usage() { echo "usage: geo-scan.sh <domain|url> [--start] [--max-age-hours N]"; exit 1; }
target=""; start=0; max_age="${GEO_SCAN_MAX_AGE_HOURS:-24}"
while [ $# -gt 0 ]; do
  case "$1" in
    --start) start=1 ;;
    --max-age-hours) [ $# -ge 2 ] || usage; max_age="$2"; shift ;;
    -*) usage ;;
    *) [ -z "$target" ] || usage; target="$1" ;;
  esac
  shift
done
[ -n "$target" ] || usage
case "$max_age" in ''|*[!0-9]*) usage ;; esac
[ "$max_age" -gt 0 ] || usage

# Bare host: strip scheme, userinfo, path, query and fragment so a full URL cannot
# produce a malformed `url=` value.
host="${target#http://}"; host="${host#https://}"; host="${host%%/*}"
host="${host#*@}"; host="${host%%\?*}"; host="${host%%#*}"
[ -n "$host" ] || usage

# A scan of a host the scanner cannot reach is not a scan. Catch it here, with its own exit
# code, rather than letting it arrive as a 404 that reads as "nobody has scanned this yet".
case "$host" in
  localhost|localhost:*|*.localhost|*.local|*.test|*.localhost:*|*.local:*|*.test:*)
    echo "NOT PUBLIC: $host is a development host — pass the public URL with --host"
    exit 3 ;;
  *.local.com|*.local.com:*)
    # This plugin's own default local domain shape: /wp-create offers <slug>.local.com
    # (commands/wp-create.md Step 3.3) and /wp-clone's placeholder domain follows the
    # same shape -- every project this plugin scaffolds locally can live under this
    # suffix, and it is not covered by the generic *.local pattern above.
    echo "NOT PUBLIC: $host is a development host — pass the public URL with --host"
    exit 3 ;;
  127.*|10.*|192.168.*|[::1]|[::1]:*|0.0.0.0*)
    echo "NOT PUBLIC: $host is a private address — pass the public URL with --host"
    exit 3 ;;
  172.1[6-9].*|172.2[0-9].*|172.3[01].*)
    echo "NOT PUBLIC: $host is a private address — pass the public URL with --host"
    exit 3 ;;
esac
# A name with no dot is a LAN hostname, not a registrable domain.
case "$host" in
  *.*) ;;
  *) echo "NOT PUBLIC: $host is not a registrable domain — pass the public URL with --host"
     exit 3 ;;
esac

if ! command -v curl >/dev/null 2>&1; then
  echo "SKIP: curl not available — cannot run the live GEO scan"
  exit 2
fi

# GNU `timeout` is absent on stock macOS; `gtimeout` (coreutils) covers that, and with
# neither present run unwrapped rather than misreport a 127.
TIMEOUT=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT="timeout 60"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT="gtimeout 60"
fi

body=$(mktemp)
stream=$(mktemp)
scan_err=$(mktemp)
old_body=""
trap 'rm -f "$body" "$stream" "$scan_err" ${old_body:+"$old_body"}' EXIT

# `--get --data-urlencode` builds ?url=<encoded> without a hand-rolled encoder. `-w` gives
# the status even when the body is an error document; `|| true` keeps `set -e` out of it.
# $1 is curl's --max-time: the --start path splits one time budget across its three calls.
fetch_report() {
  $TIMEOUT curl -sS --max-time "${1:-60}" -o "$body" -w '%{http_code}' \
    --get --data-urlencode "url=https://$host" \
    https://is-agentic.com/api/v1/report 2>/dev/null || true
}

# Start a scan and wait for it. The stream ends with a `scan_complete` or `scan_archived`
# event when the report exists, or an `error` event when it does not. An SSE stream stays
# open on its own, so the limit is curl's `--max-time`, which needs no `timeout` binary and
# always applies: curl checks it on its own timer, with no signal involved. With the 10 s
# report check before it and the 15 s fetch after it, --start stays within 110 s, under the 120 s a caller's tool call gets by default, so a slow scan ends here as
# exit 2 and not as a killed process with no message. curl's stderr is kept so a failed scan can say why (DNS, TLS, refused) instead of only "did not complete".
start_scan() {
  curl -sS -N --connect-timeout 15 --max-time 85 -o "$stream" \
    -H 'Accept: text/event-stream' -H 'Cache-Control: no-store' \
    --get --data-urlencode "target=https://$host" \
    https://is-agentic.com/api/scan/stream 2>"$scan_err" || true
  # Match the event only in an SSE `data:` line, not in a comment or another field. The
  # contract, as the is-agentic CLI reads it: each event is one `data: {"type": "<name>", ...}`
  # line, and a finished scan sends `scan_complete` or `scan_archived`. If that format
  # changes, this match fails closed: the scan reads as not completed, exit 2, never a pass.
  grep -Eq '^data:.*"type" *: *"(scan_complete|scan_archived)"' "$stream"
}

if [ "$start" -eq 1 ]; then http=$(fetch_report 10); else http=$(fetch_report); fi

scanned_now=0
if [ "$http" = "404" ] && [ "$start" -eq 1 ]; then
  echo "no report for $host yet — starting a scan at is-agentic.com (up to 85 s)" >&2
  if start_scan; then
    http=$(fetch_report 15); scanned_now=1
  else
    # curl's own error first (DNS, TLS, refused); else the server's `error` event.
    reason=$(tail -n 1 "$scan_err")
    [ -n "$reason" ] || reason=$(grep -E '^data:.*"type" *: *"error"' "$stream" | tail -n 1 | sed 's/^data: *//' || true)
    echo "SKIP: the is-agentic scan for $host did not complete${reason:+ ($reason)} — retry, or scan once at https://is-agentic.com"
    exit 2
  fi
fi

# The report's own scan time, and its epoch seconds. The timestamp is read in the caller's
# shell (not a command substitution) so it survives to the STALE line; the epoch is empty when
# the timestamp is absent or unparseable (GNU date, then BSD date). The first "scanned_at" in
# the body is enough; no jq.
check_age() {
  SCANNED_AT=$(grep -o '"scanned_at" *: *"[^"]*"' "$body" | head -n 1 | sed 's/.*: *"\(.*\)"/\1/' || true)
  stale=0
  local epoch="" now age
  if [ -n "$SCANNED_AT" ]; then
    epoch=$(date -u -d "$SCANNED_AT" +%s 2>/dev/null \
      || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "${SCANNED_AT%%.*}Z" +%s 2>/dev/null || true)
  fi
  if [ -z "$epoch" ]; then
    echo "report age unknown (no readable scanned_at)" >&2
    return 0
  fi
  now=$(date -u +%s); age=$(( (now - epoch) / 3600 ))
  [ "$age" -ge 0 ] || age=0
  echo "report scanned_at $SCANNED_AT (${age} h old, limit ${max_age} h)" >&2
  [ "$age" -lt "$max_age" ] || stale=1
}

# Signatures of a CDN/hosting bot-challenge interstitial, as bin/link-sweep.mjs reads them,
# plus the page titles such pages carry. When the scanner was served one, every finding in
# the report describes the interstitial.
challenge_evidence() {
  local found
  found=$(grep -Eio 'one moment, please|just a moment|attention required|checking your browser|ddos protection by|challenge-platform|cf-chl-[a-z0-9_-]*|_cf_chl_opt|cf-mitigated' "$body" \
    | tr 'A-Z' 'a-z' | sort -u || true)
  # Cloudflare injects /cdn-cgi/challenge-platform/ scripts into ordinary pages, and a report
  # may quote them or a cf-mitigated header name: on their own they do not make a challenge.
  # They count only beside a second, distinct signal.
  if [ "$(printf '%s\n' "$found" | grep -c .)" -lt 2 ]; then
    case "$found" in challenge-platform|cf-mitigated|"") return 0 ;; esac
  fi
  printf '%s\n' "$found" | head -n 3 | paste -sd, -
}

stale=0
case "$http" in
  200)
    if [ ! -s "$body" ]; then
      echo "SKIP: live GEO scan returned an empty report"
      exit 2
    fi
    check_age
    if [ "$stale" -eq 1 ] && [ "$start" -eq 1 ] && [ "$scanned_now" -eq 0 ]; then
      echo "report is stale — requesting a fresh scan at is-agentic.com (up to 85 s)" >&2
      old_body=$(mktemp); cp -f "$body" "$old_body"
      if start_scan; then http=$(fetch_report 15); else http=""; fi
      if [ "$http" = "200" ] && [ -s "$body" ]; then
        check_age
      else
        cp -f "$old_body" "$body"; stale=1
        echo "could not get a fresher report; keeping the old one" >&2
      fi
      rm -f "$old_body"
    fi
    evidence=$(challenge_evidence)
    if [ -n "$evidence" ]; then
      echo "SKIP: CHALLENGED — the scan of $host read a bot-challenge page, not the site (evidence: $evidence); its score is not valid. Allow is-agentic through the host's bot protection, or scan once at https://is-agentic.com"
      exit 2
    fi
    printf '%s\n' "$(cat "$body")"
    if [ "$stale" -eq 1 ]; then
      echo "STALE: the report for $host was scanned ${SCANNED_AT:-at an unknown time}, over ${max_age} h ago — it does not measure the site as it is now" >&2
      exit 4
    fi
    exit 0
    ;;
  000|"")
    echo "SKIP: live GEO scan unavailable (no network or service down)"
    exit 2
    ;;
  404)
    if [ "$start" -eq 1 ]; then
      echo "SKIP: the scan of $host completed but its report is not available yet — retry in a minute, or check https://is-agentic.com"
    else
      echo "SKIP: no completed report for $host — re-run with --start, or scan it once at https://is-agentic.com"
    fi
    exit 2
    ;;
  429|503)
    echo "SKIP: live GEO scan temporarily unavailable (HTTP $http)"
    exit 2
    ;;
  *)
    echo "ERROR: live GEO scan failed (HTTP $http)"
    exit 1
    ;;
esac
