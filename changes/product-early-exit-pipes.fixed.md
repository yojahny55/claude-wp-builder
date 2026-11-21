- `robin-fix.sh` no longer reads a queue hash that is already taken as free once the
  WebP queue passes about a thousand rows. It asked `echo "$hashes" | grep -qF` under
  `pipefail`: once the list outgrew the pipe buffer, `grep -q` closed the pipe at its
  match, `echo` died of SIGPIPE and the pipeline reported the hash missing, so the
  collision branch never ran and the row was inserted again. Lookups now read a
  here-string and match whole lines. The same early-exit reader (`grep -q`, `head`) is
  gone from every other shipped script that runs under `pipefail` (`wp-env-setup.sh`,
  `geo-scan.sh`, `clone-preflight.sh`, the S3 mirror's error summary, `audit-suite.sh`'s
  refusal listing and others), and `tests/checks/no-early-exit-pipes.sh` now scans
  `bin/*.sh` and `skills/*/scripts/*.sh` as well as the checks.
