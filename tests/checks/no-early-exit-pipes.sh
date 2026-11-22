#!/usr/bin/env bash
# No check, and no shipped shell script, may end a pipeline with a reader that stops
# reading early.
#
# `producer | grep -q pattern` under `set -o pipefail` is a race. grep -q exits at the first
# match; if the producer still has output to write, its next write hits a closed pipe and it
# dies of SIGPIPE (or, with SIGPIPE ignored, fails with EPIPE). pipefail makes that the
# pipeline's status, so a check whose pattern WAS found reports it missing -- or, under
# set -e inside a command substitution, exits 141 with no output at all. It depends on
# scheduling: a producer that writes everything before the reader is scheduled always wins,
# which is why every local run passed while a loaded 4-core CI runner failed
# wp-section-tailwind.sh, then wp-clone-isolation.sh ("sed: couldn't flush stdout: Broken
# pipe"), on unrelated PRs.
#
# grep -m N stops after N matches and awk with `exit` stops at once: the same race.
#
# The fix is a reader that consumes all of its input: `grep >/dev/null -c pattern` has the
# exit status of `grep -q` and reads to EOF, and `sed -n 1p` replaces `head -1`. A reader
# that must stop early (awk with `exit`) takes its input from a here-string or a process
# substitution, `awk '...' < <(producer)`, where the producer is not part of the pipeline's
# status.
#
# Single-quoted text is removed before matching, so a check may still assert that a command
# document contains `git status --short | head -20` as a needle; an awk program is read
# from the raw line instead. What this cannot see is an early `exit` inside a multi-line awk
# program fed by a pipe; those were fixed by hand.
#
# Shipped scripts carry the same race with a worse outcome than a red check.
# skills/wp-robin/scripts/robin-fix.sh asked `echo "$EXISTING_HASHES" | grep -qF "$hash"`
# whether a queue hash was already taken: once the list outgrows the 64 KiB pipe buffer
# (about a thousand rows), a hash that IS present, anywhere but the list's tail, read as
# absent every time, so the collision branch never ran and the row was inserted again.
# bin/*.sh and skills/*/scripts/*.sh are scanned too -- those that set pipefail, and the
# sourced lib-*.sh files that inherit it from their caller.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

# One program for the scan and for the self-test below, so the two cannot drift.
scan='
      /^[[:space:]]*#/ { next }
      {
        l = $0
        gsub(/\047[^\047]*\047/, "", l)          # drop single-quoted text
        gsub(/\|\|/, "", l)                      # || is not a pipe
        hit = 0
        if (l ~ /\|[[:space:]]*grep([[:space:]]+-[A-Za-z0-9]+)*[[:space:]]+-[A-Za-z0-9]*q/ \
            || l ~ /\|[[:space:]]*grep([[:space:]]+-[A-Za-z0-9]+)*[[:space:]]+(-[A-Za-z]*m|--max-count)/ \
            || l ~ /\|[[:space:]]*head[[:space:]]+-/)
          hit = 1
        # awk fed by a pipe whose (single-quoted, so stripped above) program exits early
        # (an `exit` in END is not early: awk has read everything by then).
        r = $0
        if (match(r, /\|[[:space:]]*awk([[:space:]]|$)/)) {
          r = substr(r, RSTART + RLENGTH)
          while (match(r, /\047[^\047]*\047/)) {
            prog = substr(r, RSTART, RLENGTH)
            r = substr(r, RSTART + RLENGTH)
            sub(/END[[:space:]]*\{.*/, "", prog)
            if (prog ~ /(^|[^A-Za-z0-9_])exit([^A-Za-z0-9_]|$)/) hit = 1
          }
        }
        if (hit) print f ":" NR ": " $0
      }'

bad=$(
  for f in tests/checks/*.sh tests/checks/lib/*.sh tests/lib/*.sh bin/*.sh skills/*/scripts/*.sh; do
    [ -f "$f" ] || continue
    case "$f" in
      */lib-*.sh) ;;
      *) grep -Eq 'set -[a-z]*o pipefail' "$f" || continue ;;
    esac
    awk -v f="$f" "$scan" "$f"
  done
)

if [ -n "$bad" ]; then
  printf 'FAIL: a pipeline under pipefail ends in a reader that exits early (grep -q, grep -m,\n'
  printf 'head, or awk with exit),\n'
  printf 'which races the producer into SIGPIPE. Use grep >/dev/null -c / sed -n 1p:\n%s\n' "$bad"
  exit 1
fi

# The rule must still see the shape it exists for, or a broken pattern above passes forever.
probe=$(mktemp -d)
trap 'rm -rf "$probe"' EXIT
# Each shape is a printf format (\047 is a quote), so this file's own scan strips it.
for shape in 'printf x | grep -Fq x' 'printf x | grep -m1 x' 'printf x | head -1' \
             'printf x | awk -F: \047{ print; exit }\047'; do
  # shellcheck disable=SC2059  # the shape IS a format: its \047 must become a quote
  printf "#!/usr/bin/env bash\nset -euo pipefail\n$shape\n" >"$probe/p.sh"
  hit=$(awk -v f=p "$scan" "$probe/p.sh")
  [ -n "$hit" ] || { echo "FAIL: the early-exit pattern no longer matches: $(sed -n 3p "$probe/p.sh")"; exit 1; }
done
# ...and must not flag an awk whose exit is in END (it has read all of its input by then).
printf '#!/usr/bin/env bash\nset -euo pipefail\nprintf x | awk \047{ n++ } END { exit !n }\047\n' >"$probe/p.sh"
hit=$(awk -v f=p "$scan" "$probe/p.sh")
[ -z "$hit" ] || { echo "FAIL: an awk exit inside END is flagged as early: $hit"; exit 1; }

echo "PASS: no pipeline under pipefail ends in grep -q, grep -m, head or awk exit (checks and shipped scripts)"
