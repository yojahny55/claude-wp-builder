- **`/wp-clone` reads each long step when it reaches it.** `commands/wp-clone.md` was 38 KB, and
  every run paid for both clone paths and the post-clone verification up front, though a run
  takes one path. It is now a 13 KB map: every step heading, entry condition and the step order
  stay, and three long parts send the run to one file each in the new `wp-clone-run` skill —
  Path A (SSH automated clone), Path B (manual import) and Step 6 (post-clone verification and
  summary). No step's wording changed. The checks that read `/wp-clone` now read it with its
  references expanded in place, and `tests/checks/wp-clone-run.sh` fails when a reference is
  not pointed to at its step or not listed in the skill.
