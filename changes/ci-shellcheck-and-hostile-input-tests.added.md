- **CI parses and lints the shell scripts, and a stub-PATH harness tests them with hostile
  input.** CI linted PHP and ES modules but never `bin/*.sh` or `skills/*/scripts/*.sh`,
  and their checks only grepped the script text, so nothing ran a script that calls `sudo`,
  `rm` or `sed` with a hostile argument. CI now runs `bash -n` on all of them (blocking)
  and `shellcheck` at warning severity (informational until the historical backlog is
  known; exclusions are documented in `.shellcheckrc`). `tests/lib/stub-path.sh` puts
  logging stand-ins for `sudo`, `rm`, `sed -i`, `wp`, `mysql` and friends on a temporary
  `PATH`, and `tests/checks/hostile-input-env-setup.sh` runs `wp-env-setup.sh` with
  traversal, separator and injection-shaped `--domain` values, expecting a refusal before
  anything would run. It fails if any hostile case reaches a destructive call, so removing
  the domain validation turns CI red.
