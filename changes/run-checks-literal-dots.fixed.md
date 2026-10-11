- **The `*-run.sh` checks match a step title's dots literally again.** Moving them to the
  `^## ${step}( |:)` regex let the `.` in a title like `Step 4.4` match any character, so a
  renamed heading such as `## Step 4X4:` still read as the step. Dots are now passed as `[.]`,
  which means the same thing to `grep -E` and to `awk` (an escaped `\.` in `awk -v` loses its
  backslash).
