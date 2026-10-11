- **`/wp-header` reads its long step when it reaches it.** `commands/wp-header.md` was 18 KB,
  and every run paid up front for the whole `wp-template` prompt, the CSS routing and the
  `wp-tailwind` author-mode prompt. It is now a 7.5 KB map: every step heading, the argument
  handling and Steps 5 to 8 stay, and Step 4 sends the run to two files in the new
  `wp-header-run` skill. No step's wording changed. The checks that read `/wp-header` now read
  it with its references expanded in place, and `tests/checks/wp-header-run.sh` fails when a
  reference is not pointed to at its step or not listed in the skill.
