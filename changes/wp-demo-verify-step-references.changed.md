- **`/wp-demo-verify` reads each long step when it reaches it.** `commands/wp-demo-verify.md`
  was 18 KB, and every run paid for the detector rules, the whole scroll walk and the catalogue
  of finding kinds up front. It is now a 7 KB map: every step heading, the target resolution,
  the inert-control grade, the sheet critique and the report stay, and three long parts send
  the run to one file each in the new `wp-demo-verify-run` skill — Step 2a (detector), Step 2b
  (walk) and Step 3 (reading the findings). No step's wording changed. The checks that read
  `/wp-demo-verify` now read it with its references expanded in place, and
  `tests/checks/wp-demo-verify-run.sh` fails when a reference is not pointed to at its step or
  not listed in the skill.
