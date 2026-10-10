- **`/wp-init` reads each long step when it reaches it.** `commands/wp-init.md` was 49 KB, and
  every run paid for all of it up front, including the Demo-First Path and the font carry on a
  scaffold with no demo. It is now a 22 KB map: every step keeps its heading, entry condition
  and order, and five long parts send the run to one file each in the new `wp-init-run` skill —
  the Demo-First Path (Steps D1-D5), Step 4.5 (font carry), Step 5 (i18n), Step 7 (the project
  `.claude/CLAUDE.md`) and Step 9 (plugins, activation, site identity, Tailwind build). No
  step's wording changed. The checks that read `/wp-init` now read it with its references
  expanded in place, and `tests/checks/wp-init-run.sh` fails when a reference is not pointed to
  at its step or not listed in the skill.
