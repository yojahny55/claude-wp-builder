# shellcheck shell=bash
# Shared by bin/prod-gate.sh and bin/audit-suite.sh: the one key a server is known by.
# host_key <url-or-host> prints it: scheme, path, query, fragment, userinfo and port are
# dropped, bracketed IPv6 literals keep their brackets, and the result is lower-cased. Both
# scripts must derive the key the same way, or the child of a gated run (which compares
# WP_AUDIT_GATE_HELD to its own key) re-takes the lock its parent holds.
host_key() {
  local h="${1#*://}"
  h="${h%%/*}"; h="${h%%\?*}"; h="${h%%#*}"; h="${h##*@}"
  case "$h" in \[*\]*) h="${h%%]*}]" ;; *) h="${h%%:*}" ;; esac
  printf '%s' "$h" | tr '[:upper:]' '[:lower:]'
}
