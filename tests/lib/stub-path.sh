#!/usr/bin/env bash
# Source me. A hostile-input harness for shell scripts that shell out to sudo, rm, sed, wp
# or mysql: it builds a temporary directory of stand-in binaries, prepends it to PATH, and
# records every call, so a test can run a script with a hostile argument and assert what it
# would have done -- without touching the system.
#
#   . tests/lib/stub-path.sh
#   stub_path_init                      # sets STUB_DIR, STUB_LOG; PATH now starts with the stubs
#   run_stubbed bash bin/x.sh --domain='../x'   # runs with the stubs, sets STUB_RC and STUB_OUT
#   stub_called sudo                    # true when any stubbed sudo was invoked
#   stub_destructive_calls              # prints the calls that would have changed the system
#
# Stubs: sudo, rm, mysql, mysqldump, wp, tee, systemctl, chown, chmod, ln, mv, cp, mkdir,
# openssl, install and security only
# LOG (they never execute their arguments, and `sudo` never runs the command it wraps).
# `sed` logs and then runs the real sed, except with -i/--in-place, where it only logs: the
# script's own text processing keeps working, in-place edits of real files do not.
#
# Limits, so nobody mistakes this for a sandbox: a script that calls a binary by absolute
# path (/usr/bin/rm) or builds a command with `eval` bypasses the stubs. Run only scripts
# whose destructive calls go through PATH, and review that before adding a script here.

STUB_NAMES="sudo rm mysql mysqldump wp tee systemctl chown chmod ln mv cp mkdir openssl install security"

stub_path_init() {
  STUB_DIR=$(mktemp -d)
  STUB_LOG="$STUB_DIR/calls.log"
  : > "$STUB_LOG"
  local n real_sed
  STUB_REAL_RM=$(command -v rm)
  real_sed=$(command -v sed)
  for n in $STUB_NAMES; do
    case "$n" in ''|*[!a-zA-Z0-9_-]*) echo "bad stub name: $n" >&2; return 1 ;; esac
    printf '#!/bin/sh\nprintf "%%s" "%s" >> "$STUB_LOG"\nfor a in "$@"; do printf " [%%s]" "$(printf %%s "$a" | tr "\\n" " ")" >> "$STUB_LOG"; done\nprintf "\\n" >> "$STUB_LOG"\nexit 0\n' "$n" > "$STUB_DIR/$n"
    chmod +x "$STUB_DIR/$n"
  done
  cat > "$STUB_DIR/sed" <<SED
#!/bin/sh
inplace=0
for a in "\$@"; do case "\$a" in -i*|--in-place*) inplace=1 ;; esac; done
if [ "\$inplace" = 1 ]; then
  printf 'sed' >> "\$STUB_LOG"; for a in "\$@"; do printf ' [%s]' "\$(printf %s "\$a" | tr '\\n' ' ')" >> "\$STUB_LOG"; done; printf '\n' >> "\$STUB_LOG"
  exit 0
fi
exec "$real_sed" "\$@"
SED
  chmod +x "$STUB_DIR/sed"
  export STUB_LOG
  PATH="$STUB_DIR:$PATH"
}

stub_path_cleanup() { [ -n "${STUB_DIR:-}" ] && "$STUB_REAL_RM" -rf "$STUB_DIR"; return 0; }

# run_stubbed CMD... : run with the stubs on PATH; never aborts the caller.
run_stubbed() {
  : > "$STUB_LOG"
  STUB_OUT=$("$@" 2>&1) && STUB_RC=0 || STUB_RC=$?
}

stub_called() { grep -Eq "^$1( |\$)" "$STUB_LOG"; }

# Calls that would have changed something. A bare `sed` never appears here (only in-place
# sed is logged); `wp` and `mysql` count, since both write to a live site.
stub_destructive_calls() { grep -E '^(sudo|rm|mysql|mysqldump|wp|tee|systemctl|chown|chmod|ln|mv|cp|mkdir|openssl|install|security|sed)( |$)' "$STUB_LOG" || true; }
