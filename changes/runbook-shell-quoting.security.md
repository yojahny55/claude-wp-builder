- **Runbook shell lines quote every path taken from the replay record.** File names and
  theme slugs were interpolated bare into the `git ls-files`, `git grep`, `ls` and `wp`
  lines the operator pastes, so a name with spaces or shell metacharacters broke the line or
  ran extra commands. `bin/audit-runbook.mjs` now single-quotes any value that is not a
  plain path word.
