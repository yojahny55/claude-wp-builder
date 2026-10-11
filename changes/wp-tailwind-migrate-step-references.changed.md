- **`/wp-tailwind-migrate` reads its two long steps when it reaches them.**
  `commands/wp-tailwind-migrate.md` was 23 KB and every run paid for all of it up front. It is
  now a 14 KB map: the baseline gate, the Tailwind v4 check, the golden capture and the other
  steps keep their wording in place, and Step 4 (the author-mode dispatch) and Step 6 (the
  convention check and the before/after comparison) send the run to one file each in the new
  `wp-tailwind-migrate-run` skill. No step's wording changed. The checks that read the command
  now read it with its references expanded in place, and
  `tests/checks/wp-tailwind-migrate-run.sh` fails when a reference is not pointed to at its step
  or not listed in the skill.
