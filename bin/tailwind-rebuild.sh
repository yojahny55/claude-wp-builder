#!/usr/bin/env bash
# Recompile a Tailwind theme's assets/css/dist/main.css after an agent has written new
# utility classes into its templates. functions.php enqueues ONLY the compiled file, so
# without this the live site keeps serving the CSS built at /wp-init time — before any
# section existed — and /wp-yolo's parity gate diffs the demo against an unstyled page.
# Usage: bin/tailwind-rebuild.sh <theme-dir>
# Exit 0 and print nothing on a non-Tailwind theme (no package.json / no tailwindcss src).
#
# Two writers must never touch dist/main.css at once, or it is served torn:
#  - another builder for the SAME theme    → serialized by flock below
#  - the user's `npm run preview` watcher  → detected, and we skip rather than fight it
set -euo pipefail

theme="${1:?usage: tailwind-rebuild.sh <theme-dir>}"

[ -f "$theme/package.json" ] && [ -d "$theme/assets/css/src/tailwindcss" ] || exit 0

theme_abs=$(cd "$theme" && pwd -P)
out_abs="$theme_abs/assets/css/dist/main.css"

proc_cwd() {
  # Linux first; lsof for macOS. Empty when neither can tell.
  readlink -f "/proc/$1/cwd" 2>/dev/null \
    || lsof -a -p "$1" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' \
    || true
}

# The watcher's own -o argument is the ground truth for which theme it compiles: cwd alone
# misses `npm --prefix wp-content/themes/acme run preview`, whose cwd is the parent. Read
# the command line, resolve its -o relative to that cwd, and compare output files.
watcher_output() {
  local pid=$1 cwd out
  cwd=$(proc_cwd "$pid") || return 1
  [ -n "$cwd" ] || return 1
  out=$(tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null \
        | awk '$0 == "-o" || $0 == "--output" { getline; print; exit }') || return 1
  [ -n "$out" ] || return 1
  case "$out" in
    /*) printf '%s\n' "$out" ;;
    *)  printf '%s\n' "$cwd/$out" ;;
  esac
}

for pid in $(pgrep -f 'tailwindcss.*--watch' 2>/dev/null || true); do
  # Either signal is enough: an output path that resolves to ours, or a cwd that is ours
  # (the fallback when /proc is unreadable, e.g. macOS, where cmdline is not available).
  w_out=$(watcher_output "$pid" || true)
  if [ -n "$w_out" ] && [ "$(readlink -f "$w_out" 2>/dev/null || echo "$w_out")" = "$out_abs" ]; then
    echo "tailwind: watcher running for this theme (npm run preview) — dist/main.css is live, skipping build"
    exit 0
  fi
  if [ -z "$w_out" ] && [ "$(proc_cwd "$pid")" = "$theme_abs" ]; then
    echo "tailwind: watcher running for this theme (npm run preview) — dist/main.css is live, skipping build"
    exit 0
  fi
done
# ponytail: a watcher we cannot identify at all is treated as absent and we build anyway —
# a possible torn write the watcher immediately redoes beats silently never compiling.

build() {
  if [ ! -d "$theme/node_modules" ]; then
    echo "tailwind: node_modules missing — running npm install once"
    # Bounded: a hung registry must not hold the lock (and every parallel builder behind
    # it) forever. `timeout` is GNU coreutils; without it the install runs unbounded.
    if command -v timeout >/dev/null 2>&1; then
      (cd "$theme" && timeout "${TAILWIND_REBUILD_INSTALL_TIMEOUT:-600}" npm install --silent)
    else
      (cd "$theme" && npm install --silent)
    fi
  fi
  # ponytail: tailwindbuild only, never the starter's `build` — that also runs wp-scripts
  # and takes 10x longer; JS is untouched by the section/header/footer/page builders.
  (cd "$theme" && npm run --silent tailwindbuild)
  echo "tailwind: rebuilt assets/css/dist/main.css"
}

# /wp-yolo dispatches section builders in parallel, so two can land here at once for the
# same theme: concurrent `npm install` corrupts node_modules and concurrent compiles tear
# dist/main.css. One lock per theme, in the theme, so separate projects never block.
#
# The lock file is NEVER deleted. flock locks the inode, not the path: removing the file
# while a third process is about to open it leaves that process locking an unlinked inode
# while a fourth creates a fresh file, and two builds run at once. An empty leftover file
# is the price of a lock that holds; the starter's .gitignore lists it.
lock="$theme_abs/.tailwind-rebuild.lock"
if command -v flock >/dev/null 2>&1; then
  exec 9>>"$lock"
  # Bounded wait: a crashed or hung holder must not wedge every later builder.
  if ! flock -w "${TAILWIND_REBUILD_LOCK_TIMEOUT:-900}" 9; then
    echo "tailwind: timed out waiting for the build lock ($lock) — another build is still running" >&2
    exit 1
  fi
  build
  exec 9>&-
else
  # ponytail: no flock (macOS ships none) — build unlocked rather than not at all.
  build
fi
