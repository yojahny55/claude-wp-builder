#!/usr/bin/env bash
# Live GEO/agent-readiness scan via the public is-agentic report API.
# Exit 0 = report returned, 1 = request failed, 2 = skipped (no curl / no report / no network).
#
# No package execution. The previous version downloaded and ran an npm CLI, which /wp-yolo
# runs unattended in its finish phase — a compromised package, alias or registry could
# execute code on the build host. The public report API is a read-only GET; curl executes
# nothing. A missing report starts with the site owner running one scan at
# https://is-agentic.com, which this script then reads.
set -euo pipefail

target="${1:-}"
[ -n "$target" ] || { echo "usage: geo-scan.sh <domain|url>"; exit 1; }

# Bare host.
host="${target#http://}"; host="${host#https://}"; host="${host%%/*}"

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
trap 'rm -f "$body"' EXIT

# `--get --data-urlencode` builds ?url=<encoded> without a hand-rolled encoder. `-w` gives
# the status even when the body is an error document; `|| true` keeps `set -e` out of it.
http=$($TIMEOUT curl -sS -o "$body" -w '%{http_code}' \
  --get --data-urlencode "url=https://$host" \
  https://is-agentic.com/api/v1/report 2>/dev/null || true)

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
    echo "SKIP: no completed report for $host — scan it once at https://is-agentic.com"
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
