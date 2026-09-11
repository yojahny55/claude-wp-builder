#!/usr/bin/env bash
# Live GEO/agent-readiness scan via the public is-agentic report API.
# Exit 0 = report returned, 2 = skipped (no network/tool), 1 = error.
set -euo pipefail

target="${1:-}"
[ -n "$target" ] || { echo "usage: geo-scan.sh <domain|url>"; exit 1; }

# Normalise to a bare host for the CLI.
host="${target#http://}"; host="${host#https://}"; host="${host%%/*}"

if ! command -v npx >/dev/null 2>&1; then
  echo "SKIP: npx not available — cannot run the live GEO scan"
  exit 2
fi

if ! out=$(npx --yes is-agentic "$host" --json 2>/dev/null); then
  if npx --yes ax score "$host" --json >/dev/null 2>&1; then
    out=$(npx --yes ax score "$host" --json)
  else
    echo "SKIP: live GEO scan unavailable (no network or service down)"
    exit 2
  fi
fi

printf '%s\n' "$out"
