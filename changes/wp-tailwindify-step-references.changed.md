- **`/wp-tailwindify` reads its two long steps when it reaches them.** `commands/wp-tailwindify.md`
  was 15.4 KB, and every run paid for the agent dispatch context and the verification detail up
  front. It is now a 5.8 KB map: every step heading, the argument parse, the already-Tailwind
  check and the next-steps report stay, and Step 3 (the context handed to the `wp-tailwind` agent
  and the temporary-path write contract) and Step 4 (structural checks, the rendering parity gate
  and the checked move) send the run to one file each in the new `wp-tailwindify-run` skill. No
  step's wording changed. The checks that read `/wp-tailwindify` now read it with its references
  expanded in place, and `tests/checks/wp-tailwindify-run.sh` fails when a reference is not
  pointed to at its step or not listed in the skill.
