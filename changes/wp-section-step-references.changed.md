- **`/wp-section` reads its dispatch detail when it reaches Step 5.** `commands/wp-section.md`
  was 33 KB, and every run paid for all of it up front, including the two-phase contact flow on
  a section that is not a contact section, and the other way round. It is now a 14 KB map: every
  step keeps its heading, entry condition and order, and Step 5 sends the run to one file each in
  the new `wp-section-run` skill — the dispatch rules every section shares (field naming, GEO
  citability, the `--transcribe` overlay, CSS agent routing, file ownership), the three-agent
  dispatch for an ordinary section, and the two-phase dispatch for a contact section. No step's
  wording changed. The checks that read `/wp-section` now read it with its references expanded in
  place, and `tests/checks/wp-section-run.sh` fails when a reference is not pointed to at its step
  or not listed in the skill.
