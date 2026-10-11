- **The `*-run.sh` checks now fail clearly on an empty `references/` and bound each step at any `##` heading.**
  With no reference files, the loop ran once on the literal `*.md` glob and failed with "never
  sends the run to *.md"; each check now sets `nullglob` and says the directory has no references.
  The "pointer sits under its step" test reset only on `## Step` (or `Step|Path`, `Step|Phase`)
  headings, so a pointer moved under a later heading such as `## Report` in `/wp-tailwind-migrate`
  still read as inside the last step; any `##` heading now ends the step. The checks that matched
  `## Step N:` literally also accept `## Step N ` now, like the others.
