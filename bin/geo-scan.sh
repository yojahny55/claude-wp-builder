#!/usr/bin/env bash
# Live GEO/agent-readiness scan via the public is-agentic report API.
# Exit 0 = report returned, 1 = request failed, 2 = skipped (no curl / no report / no
# network), 3 = the host is not publicly reachable, so no scan is possible for it.
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
# only for a host the operator confirmed as public this run.
set -euo pipefail

usage() { echo "usage: geo-scan.sh <domain|url> [--start]"; exit 1; }
target=""; start=0
for arg in "$@"; do
  case "$arg" in
    --start) start=1 ;;
    -*) usage ;;
    *) [ -z "$target" ] || usage; target="$arg" ;;
  esac
done
[ -n "$target" ] || usage

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
trap 'rm -f "$body" "$stream"' EXIT

# `--get --data-urlencode` builds ?url=<encoded> without a hand-rolled encoder. `-w` gives
# the status even when the body is an error document; `|| true` keeps `set -e` out of it.
fetch_report() {
  $TIMEOUT curl -sS -o "$body" -w '%{http_code}' \
    --get --data-urlencode "url=https://$host" \
    https://is-agentic.com/api/v1/report 2>/dev/null || true
}

# Start a scan and wait for it. The stream ends with a `scan_complete` or `scan_archived`
# event when the report exists, or an `error` event when it does not. The limit stays under
# the 120 s a caller's tool call gets by default, so a slow scan ends here as exit 2 and
# not as a killed process with no message.
start_scan() {
  local limit=""
  if command -v timeout >/dev/null 2>&1; then limit="timeout 100"
  elif command -v gtimeout >/dev/null 2>&1; then limit="gtimeout 100"; fi
  $limit curl -sS -N -o "$stream" \
    -H 'Accept: text/event-stream' -H 'Cache-Control: no-store' \
    --get --data-urlencode "target=https://$host" \
    https://is-agentic.com/api/scan/stream 2>/dev/null || true
  grep -Eq '"type" *: *"(scan_complete|scan_archived)"' "$stream"
}

http=$(fetch_report)

if [ "$http" = "404" ] && [ "$start" -eq 1 ]; then
  echo "no report for $host yet — starting a scan at is-agentic.com (up to 100 s)" >&2
  if start_scan; then
    http=$(fetch_report)
  else
    echo "SKIP: the is-agentic scan for $host did not complete — retry, or scan once at https://is-agentic.com"
    exit 2
  fi
fi

case "$http" in
  200)
    out=$(cat "$body")
    if [ -z "$out" ]; then
      echo "SKIP: live GEO scan returned an empty report"
      exit 2
    fi
    printf '%s\n' "$out"
    exit 0
    ;;
  000|"")
    echo "SKIP: live GEO scan unavailable (no network or service down)"
    exit 2
    ;;
  404)
    echo "SKIP: no completed report for $host — re-run with --start, or scan it once at https://is-agentic.com"
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
