# shellcheck shell=bash
# Shared by bin/prod-gate.sh, bin/audit-suite.sh and bin/geo-scan.sh: is this host a
# development host? host_is_local <url-or-host> returns 0 when it is, 1 otherwise.
#
# A host is local when ONE of these holds:
#   - its name ends in a suffix reserved for non-public use: localhost, .localhost, .test,
#     .local, .internal, .lan, .home.arpa, .example, .invalid;
#   - it is an IP literal in a loopback or private range, judged by octet (so
#     `10.example.com` and `172.32.0.1` are public) or ::1 / fc00::/7 / fe80::/10;
#   - it is any other name (this tool's own `<slug>.local.com` vhosts included, `local.com`
#     is a real public domain) AND it resolves, and EVERY address it resolves to is loopback
#     or private. A name that does not resolve, or resolves to anything public, is NOT
#     local: the safe side, because a local verdict skips the production gate.
# Resolution reads WP_HOSTS_FILE (hosts-file format) when set, so a test needs no network;
# otherwise `getent ahosts`/`getent hosts`, otherwise /etc/hosts.
. "$(dirname "${BASH_SOURCE[0]}")/host-key.sh"

# local_addr_private <ip>: 0 when the address is loopback or private.
local_addr_private() {
  local a="$1" o1 o2 _r
  case "$a" in
    '') return 1 ;;
    ::1|0.0.0.0) return 0 ;;
    *:*)
      case "$a" in
        ::ffff:*) local_addr_private "${a#::ffff:}"; return ;;
        [fF][cCdD]*|[fF][eE][89aAbB]*) return 0 ;;
      esac
      return 1 ;;
    *[!0-9.]*) return 1 ;;
    *.*.*.*)
      IFS=. read -r o1 o2 _r <<< "$a"
      case "$o1" in
        10|127) return 0 ;;
        192) [ "$o2" = 168 ] && return 0 ;;
        172) [ "${o2:-0}" -ge 16 ] && [ "${o2:-0}" -le 31 ] && return 0 ;;
      esac ;;
  esac
  return 1
}

# local_host_addrs <name>: the addresses the name resolves to, one per line (maybe none).
local_host_addrs() {
  local n="$1"
  if [ -n "${WP_HOSTS_FILE:-}" ]; then
    awk -v n="$n" '{ sub(/#.*/, "") } NF > 1 { for (i = 2; i <= NF; i++) if (tolower($i) == n) print $1 }' "$WP_HOSTS_FILE" 2>/dev/null
  elif command -v getent >/dev/null 2>&1; then
    getent ahosts "$n" 2>/dev/null | awk '{ print $1 }' | sort -u
  elif [ -r /etc/hosts ]; then
    awk -v n="$n" '{ sub(/#.*/, "") } NF > 1 { for (i = 2; i <= NF; i++) if (tolower($i) == n) print $1 }' /etc/hosts 2>/dev/null
  fi
}

host_is_local() {
  local h addr found=0
  h="$(host_key "$1")"
  [ -n "$h" ] || return 1
  case "$h" in
    localhost|*.localhost|*.test|*.local|*.internal|*.lan|*.home.arpa|*.example|*.invalid) return 0 ;;
    \[*\]) h="${h#\[}"; h="${h%\]}"; local_addr_private "$h"; return ;;
  esac
  case "$h" in
    *[!0-9.]*) ;;
    *.*.*.*) local_addr_private "$h"; return ;;
  esac
  while IFS= read -r addr; do
    [ -n "$addr" ] || continue
    found=1
    local_addr_private "$addr" || return 1
  done < <(local_host_addrs "$h")
  [ "$found" -eq 1 ]
}
