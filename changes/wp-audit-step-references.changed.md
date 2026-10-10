- **`/wp-audit` reads each long step when it reaches it.** `commands/wp-audit.md` was 97 KB,
  and every run paid for all of it up front, including the fix phase on a report-only run and
  the adopted-site rules on a site this plugin built. It is now a 24 KB map: every step keeps
  its heading, entry condition and order, and fourteen long steps send the run to one file
  each in the new `wp-audit-run` skill. No step's wording changed. The checks that guard the
  audit read the command with its references expanded in place
  (`tests/checks/lib/expand-command.sh`), and `tests/checks/wp-audit-run.sh` fails when a
  reference is not pointed to at its step or not listed in the skill.
