- **Contract checks no longer fail at random on a busy runner.** Hundreds of checks piped a
  producer into `grep -q` or `head` under `set -o pipefail`. Those readers stop at the first
  match, so a producer still writing died of SIGPIPE and the pipeline reported failure for a
  pattern that was found, or, inside a command substitution under `set -e`, the check exited
  141 with no output. It only happened when the reader won the race, so local runs passed and
  CI failed unrelated pull requests. The readers now consume their whole input
  (`grep >/dev/null -c`, `sed -n 1p`), awk programs that exit early read a here-string or a
  process substitution, `tests/run.sh` prints the exit status of every failed check, and
  `tests/checks/no-early-exit-pipes.sh` refuses the pattern from coming back.
