#!/usr/bin/env bash
# Serialize and pace every request an audit sends to a production host, across all the
# audit agents running in parallel, without changing what any of them measures.
#
# Why this exists: production servers sit behind fail2ban, CrowdSec and ModSecurity. An
# audit dispatched seven agents in parallel against one production host. Each was allowed
# 4 requests in flight, so up to 28 ran at once, plus Lighthouse and Playwright loads, while
# the security agent probed readme.html, ?author=1 and /wp-json/wp/v2/users in a burst.
# Leaky-bucket scenarios (CrowdSec http-probing and http-crawl, fail2ban rate jails) count
# requests per window, so the burst filled them, not the paths themselves. The host banned
# the auditing machine's IP within five minutes, every live check of the run was lost, and
# one agent's retries lengthened the ban.
#
# The gate changes the pace, never the measurement. The wrapped command (curl, lighthouse,
# a Playwright run, link-sweep) is the same command the agent would have run, against the
# same URL, with the same headers and user agent.
#   - One wrapped command at a time per host, across every agent (flock on a per-host lock).
#   - At least --delay seconds (default 2) between the end of one command and the start of
#     the next. Pass a longer delay (10) for reconnaissance-shaped paths: readme, license,
#     ?author=, the users REST route, xmlrpc, login, backups.
#   - Once any command saw a block, the host is marked blocked, and every later call exits
#     4 without sending anything. A retry against a ban extends the ban. The command's own
#     exit code is checked for curl's refused or reset codes (7, 35, 52, 56), and two curl
#     timeouts (28) in a row also count: a firewall bouncer that DROPs packets shows up as a
#     timeout, not a refusal. Anything else the caller recognises (HTTP 429, a 403 with a
#     WAF signature, ERR_CONNECTION_REFUSED in a browser, link-sweep exit 4) it reports
#     with --mark-blocked.
#   - A call waits at most --wait seconds (default 300) for another agent's command to
#     finish, then exits 5 without sending anything. Call it again later; a wait is not a
#     retry, since nothing was sent.
#   - A development host is not gated: a local site runs exactly as it did before.
#
# Usage:
#   prod-gate.sh [--dir <state-dir>] [--delay <s>] [--wait <s>] <url-or-host> -- <command> [args...]
#   prod-gate.sh [--dir <state-dir>] --mark-blocked <url-or-host> "<reason>"
#   prod-gate.sh [--dir <state-dir>] --status <url-or-host>
# State dir: --dir, else $WP_AUDIT_GATE_DIR, else ${TMPDIR:-/tmp}/wp-audit-gate. All the
# agents of one run must share it; /wp-audit passes it in every dispatch prompt.
#
# Exit: the wrapped command's own exit code, or
#   4 = the host is marked blocked; nothing was sent (stdout says why)
#   5 = another command held the host longer than --wait; nothing was sent
#   1 = usage error, or flock is unavailable (the gate refuses to run unserialized)
set -uo pipefail

dir="${WP_AUDIT_GATE_DIR:-${TMPDIR:-/tmp}/wp-audit-gate}" delay=2 wait_max=300 mode=run
need() { [ $# -ge 2 ] && [ -n "$2" ] || { echo "$1 needs a value" >&2; exit 1; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) need "$@"; dir="$2"; shift 2 ;;
    --delay) need "$@"; delay="$2"; shift 2 ;;
    --wait) need "$@"; wait_max="$2"; shift 2 ;;
    --mark-blocked) mode=mark; shift ;;
    --status) mode=status; shift ;;
    *) break ;;
  esac
done
# BSD date has no %N and prints a literal N; fall back to whole seconds there.
now() { local t; t="$(date +%s.%N 2>/dev/null)"; case "$t" in ''|*N*) date +%s ;; *) printf '%s\n' "$t" ;; esac; }

target="${1:-}"
[ -n "$target" ] || { echo "usage: prod-gate.sh [--dir d] [--delay s] <host> -- <command...>" >&2; exit 1; }
shift
case "$delay" in ''|*[!0-9.]*|*.*.*|.) echo "--delay must be a number" >&2; exit 1 ;; esac
case "$wait_max" in ''|*[!0-9]*) echo "--wait must be an integer" >&2; exit 1 ;; esac

# One key per server: drop scheme, path, query, fragment, userinfo and port, so that
# `https://h?author=1`, `https://h:443/x` and `h` share one lock and one blocked flag.
host="${target#*://}"; host="${host%%/*}"; host="${host%%\?*}"; host="${host%%#*}"; host="${host##*@}"
case "$host" in \[*\]*) host="${host%%]*}]" ;; *) host="${host%%:*}" ;; esac
host="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')"
[ -n "$host" ] || { echo "cannot read a host from: $target" >&2; exit 1; }
local_host=0
case "$host" in
  localhost|*.localhost|*.local|*.local.com|*.test|127.*|10.*|192.168.*|\[::1\]|0.0.0.0|172.1[6-9].*|172.2[0-9].*|172.3[01].*) local_host=1 ;;
esac

mkdir -p "$dir" || { echo "cannot create $dir" >&2; exit 1; }
key="$(printf '%s' "$host" | tr -c 'a-z0-9.-' '_')"
blocked="$dir/$key.blocked" stamp="$dir/$key.last" lock="$dir/$key.lock"

case "$mode" in
  status)
    if [ -f "$blocked" ]; then echo "BLOCKED: $(cat "$blocked")"; exit 4; fi
    echo "open"; exit 0 ;;
  mark)
    reason="${1:-blocked}"
    printf '%s %s\n' "$(date -u +%FT%TZ)" "$reason" > "$blocked"
    echo "marked $host blocked: $reason"; exit 0 ;;
esac

[ "${1:-}" = "--" ] && shift
[ $# -gt 0 ] || { echo "usage: prod-gate.sh [--dir d] [--delay s] <host> -- <command...>" >&2; exit 1; }

# A development host keeps its old behaviour: no lock, no delay.
if [ "$local_host" -eq 1 ]; then exec "$@"; fi

command -v flock >/dev/null 2>&1 \
  || { echo "prod-gate: flock is unavailable; refusing to send to a production host unserialized" >&2; exit 1; }
exec 9>"$lock"
if ! flock -w "$wait_max" 9; then
  echo "prod-gate: $host busy for more than ${wait_max}s (another agent's command). Nothing sent; call again later." >&2
  exit 5
fi
if [ -f "$blocked" ]; then
  echo "BLOCKED: $host -- $(cat "$blocked"). Nothing sent; report this check UNMEASURED." >&2
  exit 4
fi
if [ -f "$stamp" ]; then
  last="$(cat "$stamp" 2>/dev/null || echo 0)"
  wait_s="$(awk -v l="$last" -v d="$delay" -v n="$(now)" 'BEGIN { w = l + d - n; print (w > 0 ? w : 0) }')"
  sleep "$wait_s"
fi
# The child must not inherit fd 9: a process it leaves behind (a browser, `cmd &`) would
# otherwise hold the host's lock after the command returns.
"$@" 9>&-
rc=$?
now > "$stamp"
is_curl=0
for a in "$@"; do case "$a" in curl|*/curl) is_curl=1; break ;; esac; done
if [ "$is_curl" -eq 1 ]; then
  timeouts="$dir/$key.timeouts"
  case "$rc" in
    7|35|52|56)
      printf '%s %s\n' "$(date -u +%FT%TZ)" "connection refused or reset (curl $rc) -- possible IP ban" > "$blocked"
      echo "prod-gate: $host marked blocked (curl $rc). No further requests will be sent." >&2 ;;
    28)
      n=$(( $(cat "$timeouts" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$timeouts"
      if [ "$n" -ge 2 ]; then
        printf '%s %s\n' "$(date -u +%FT%TZ)" "two curl timeouts in a row -- possible DROP ban" > "$blocked"
        echo "prod-gate: $host marked blocked (two timeouts in a row). No further requests will be sent." >&2
      fi ;;
    *) rm -f "$timeouts" ;;
  esac
fi
exit "$rc"
