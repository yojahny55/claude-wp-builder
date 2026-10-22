- **CI fails, instead of warning, when a script accepts hostile input.** The contract-checks
  job now sets `WP_HOSTILE_STRICT=1`, so `tests/checks/hostile-input-env-setup.sh` no longer
  reports XFAIL for a `--domain` value that reaches a destructive call: it fails the job, and
  a later regression of the input validation cannot hide behind XFAIL.
