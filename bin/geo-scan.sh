#!/usr/bin/env bash
# Live GEO/agent-readiness scan via the public is-agentic report API.
# Exit 0 = report returned, 1 = tool error, 2 = skipped (no npx / no network / no report).
set -euo pipefail

target="${1:-}"
[ -n "$target" ] || { echo "usage: geo-scan.sh <domain|url>"; exit 1; }

# Normalise to a bare host for the CLI.
host="${target#http://}"; host="${host#https://}"; host="${host%%/*}"

if ! command -v npx >/dev/null 2>&1; then
  echo "SKIP: npx not available — cannot run the live GEO scan"
  exit 2
fi

err=$(mktemp)
trap 'rm -f "$err"' EXIT

# GNU `timeout` is absent on stock macOS; `gtimeout` (coreutils) covers that, and with
# neither present run unwrapped rather than misreport a 127 as a clean skip.
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT="timeout 60"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT="gtimeout 60"
else
  TIMEOUT=""
fi

# `is-agentic` and its `ax` alias are the same package. One 60s timeout per attempt so
# an offline run cannot hang the mandatory finish step.
if out=$($TIMEOUT npx --yes is-agentic "$host" --json 2>"$err"); then
  printf '%s\n' "$out"
  exit 0
fi

if out=$($TIMEOUT npx --yes ax score "$host" --json 2>"$err"); then
  printf '%s\n' "$out"
  exit 0
fi

# No output at all, or a network-looking failure, is a clean skip; anything else is a
# tool error the caller should surface.
if [ -z "$out" ] || grep -qiE 'ENOTFOUND|EAI_AGAIN|ECONNREFUSED|ETIMEDOUT|ENETUNREACH|getaddrinfo|network|fetch failed' "$err"; then
  echo "SKIP: live GEO scan unavailable (no network or service down)"
  exit 2
fi

echo "ERROR: live GEO scan failed: $(head -n 1 "$err")"
exit 1
