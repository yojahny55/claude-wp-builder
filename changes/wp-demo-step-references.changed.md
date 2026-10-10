- **`/wp-demo` reads each long step when it reaches it.** `commands/wp-demo.md` was 56 KB, and
  every run paid for all of it up front, including the craft brief, composition plan and craft
  build on a plain build that never uses them. It is now a 19 KB map: every step keeps its
  heading, entry condition and order, and four long parts send the run to one file each in the
  new `wp-demo-run` skill — Step 2.6 items 3 (brief), 5 (composition plan) and 6 (build), and
  Step 4.9 (section plan). No step's wording changed. The checks that read `/wp-demo` now read
  it with its references expanded in place, and `tests/checks/wp-demo-run.sh` fails when a
  reference is not pointed to at its step or not listed in the skill.
