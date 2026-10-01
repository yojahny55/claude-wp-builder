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
#   4 = the host is marked blocked; nothing was sent (stderr says why)
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
  localhost|*.localhost|*.local|*.local.com|*.test|\[::1\]|0.0.0.0) local_host=1 ;;
  # Private ranges apply to a dotted IPv4 address only, by octet: a prefix glob would also
  # pass `10.example.com` or `172.160.0.1` through ungated.
  *[!0-9.]*) ;;
  *.*.*.*)
    IFS=. read -r o1 o2 _ <<< "$host"
    case "$o1" in
      10|127) local_host=1 ;;
      192) [ "$o2" = 168 ] && local_host=1 ;;
      172) [ "${o2:-0}" -ge 16 ] && [ "${o2:-0}" -le 31 ] && local_host=1 ;;
    esac ;;
esac

mkdir -p "$dir" || { echo "cannot create $dir" >&2; exit 1; }
key="$(printf '%s' "$host" | tr -c 'a-z0-9.-' '_')"
blocked="$dir/$key.blocked" stamp="$dir/$key.last" lock="$dir/$key.lock"
# Write the blocked flag whole: --mark-blocked runs without the lock, so a reader must never
# see a truncated file. mv within one directory is atomic.
set_blocked() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$1" > "$blocked.$$" && mv -f "$blocked.$$" "$blocked"; }

case "$mode" in
  status)
    if [ -f "$blocked" ]; then echo "BLOCKED: $(cat "$blocked")"; exit 4; fi
    echo "open"; exit 0 ;;
  mark)
    reason="${1:-blocked}"
    set_blocked "$reason"
    echo "marked $host blocked: $reason" >&2; exit 0 ;;
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
  # Fixed-point: awk's default %.6g prints 5e-05, which some sleep builds reject, and a
  # failed sleep would send the command unpaced.
  wait_s="$(awk -v l="$last" -v d="$delay" -v n="$(now)" 'BEGIN { w = l + d - n; printf "%.6f\n", (w > 0 ? w : 0) }')"
  # An interrupted sleep would send the command early, so a failed sleep sends nothing.
  sleep "$wait_s" || { echo "prod-gate: pacing sleep interrupted. Nothing sent; call again." >&2; exit 1; }
  # --mark-blocked does not take the lock, so a ban recorded during the sleep must stop this send.
  if [ -f "$blocked" ]; then
    echo "BLOCKED: $host -- $(cat "$blocked"). Nothing sent; report this check UNMEASURED." >&2
    exit 4
  fi
fi
# The child must not inherit fd 9: a process it leaves behind (a browser, `cmd &`) would
# otherwise hold the host's lock after the command returns.
"$@" 9>&-
rc=$?
now > "$stamp"
# The command is curl when it is the program run, directly or through any nesting of
# `timeout`/`env`; an argument that merely ends in /curl (a URL, a path) does not count.
# Those two are the only wrappers the audit's callers use. Any other wrapper (nice, nohup)
# or an env option this loop does not know hides curl: its block signals are then missed,
# so callers send curl bare or through timeout/env.
is_curl=0 i=1
while [ "$i" -le $# ]; do
  case "${!i}" in
    timeout|gtimeout|*/timeout|*/gtimeout)
      i=$((i + 1))
      while [ "$i" -le $# ]; do
        case "${!i}" in
          -s|-k|--signal|--kill-after) i=$((i + 2)) ;;  # options that take a separate value
          -*) i=$((i + 1)) ;;
          *) break ;;
        esac
      done
      i=$((i + 1)) ;;  # the duration
    env|*/env)
      i=$((i + 1))
      while [ "$i" -le $# ]; do
        case "${!i}" in
          -u|-C|-S|--unset|--chdir|--split-string) i=$((i + 2)) ;;  # options that take a separate value
          -*|*=*) i=$((i + 1)) ;;
          *) break ;;
        esac
      done ;;
    curl|*/curl) is_curl=1; break ;;
    *) break ;;
  esac
done
if [ "$is_curl" -eq 1 ]; then
  timeouts="$dir/$key.timeouts"
  case "$rc" in
    7|35|52|56)
      set_blocked "connection refused or reset (curl $rc) -- possible IP ban"
      echo "prod-gate: $host marked blocked (curl $rc). No further requests will be sent." >&2 ;;
    28)
      n=$(( $(cat "$timeouts" 2>/dev/null || echo 0) + 1 )); printf '%s\n' "$n" > "$timeouts.$$" && mv -f "$timeouts.$$" "$timeouts"
      if [ "$n" -ge 2 ]; then
        set_blocked "two curl timeouts in a row -- possible DROP ban"
        echo "prod-gate: $host marked blocked (two timeouts in a row). No further requests will be sent." >&2
      fi ;;
    *) rm -f "$timeouts" ;;
  esac
else
  # Two timeouts count only when consecutive; any other command in between breaks the run.
  rm -f "$dir/$key.timeouts"
fi
exit "$rc"
