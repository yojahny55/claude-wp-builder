- **`/wp-create` reads each long step when it reaches it.** `commands/wp-create.md` was 37 KB,
  and every run paid for all of it up front, including the plugin-profile install and the
  manifest shape. It is now a 26 KB map: every step keeps its heading, entry condition and
  order, and three long parts send the run to one file each in the new `wp-create-run` skill —
  Step 4.3 (environment config templates), Step 4.10 (plugin profile install) and Step 5 (the
  `.wp-create.json` manifest). No step's wording changed. The checks that read `/wp-create`
  now read it with its references expanded in place, and `tests/checks/wp-create-run.sh` fails
  when a reference is not pointed to at its step or not listed in the skill.
