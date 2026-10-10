- **`/wp-seed` reads each long phase when it reaches it.** `commands/wp-seed.md` was 45 KB, and
  every run paid for all of it up front, including the menu and bilingual detail while still
  parsing the demo. It is now an 18 KB map: every step and phase keeps its heading, entry
  condition and order, and six long parts send the run to one file each in the new
  `wp-seed-run` skill — Phase 1 (parse the demo), Phase 3 (import media), Phase 4 (ACF fields),
  Phase 5 (bilingual content), Phase 6 (menus) and Phase 7 (final setup). No phase's wording
  changed. The checks that read `/wp-seed` now read it with its references expanded in place,
  and `tests/checks/wp-seed-run.sh` fails when a reference is not pointed to at its phase or
  not listed in the skill.
