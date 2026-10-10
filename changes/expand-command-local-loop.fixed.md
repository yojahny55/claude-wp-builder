- **`tests/checks/lib/expand-command.sh` no longer overwrites a caller's `r`.** Its loop
  variable was not declared `local`, so a check that held a path in `r` and then expanded a
  command grepped the wrong file. `wp-behaviour-gates.sh` was the first check to hit it.
