- **`shellcheck` is now a blocking CI gate.** It ran as informational (`continue-on-error`)
  because the scripts had never been linted. The `Shell scripts` job now fails on any
  finding at warning severity. The three intentionally split `$(...)` package lists in
  `bin/wp-env-setup.sh` carry an inline `# shellcheck disable=SC2046` with the reason, and
  `tests/checks/ci-shell-lint.sh` now fails if the step regains `continue-on-error`.
