- **The last early-exit readers under `pipefail` are gone, and the check now sees them.**
  `bin/clone-preflight.sh` read the `Server` header with `tr | awk '…exit'`, which died with
  141 under `set -e` when the headers outgrew the pipe buffer after that line;
  `bin/audit-suite.sh` reported a Playwright CLI that does not load with `| grep -m3 … ||
  tail -3`, so an early grep could SIGPIPE `printf` and print the tail after the matches; and
  `bin/tailwind-rebuild.sh` read a watcher's `-o` the same racy way. Each reader now
  consumes all of its input. `tests/checks/no-early-exit-pipes.sh` also flags `| grep -m`
  and a piped awk whose program exits outside `END`, and its self-test runs the same program
  as the scan.
