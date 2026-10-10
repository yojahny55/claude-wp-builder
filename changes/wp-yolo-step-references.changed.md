- **`/wp-yolo` reads each long step when it reaches it.** `commands/wp-yolo.md` was 76 KB, and
  every run paid for all of it up front, including the Tailwind conversion on a basic-template
  build and the build ledger on a run that never resumes. It is now a 32 KB map: every step
  keeps its heading, entry condition and order, and eight long steps send the run to one file
  each in the new `wp-yolo-run` skill. Steps 1, 4 and 5 stay whole, because they are the gates
  and the dispatch order. No step's wording changed. The checks that read `/wp-yolo` now read
  it with its references expanded in place, and `tests/checks/wp-yolo-run.sh` fails when a
  reference is not pointed to at its step or not listed in the skill.
