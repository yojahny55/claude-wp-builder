- **`/wp-finalize` reads each long check when it reaches it.** `commands/wp-finalize.md` was
  36 KB, and every run paid for all of it up front, including the WP-CLI runtime validation, the
  GEO scan and the three demo-parity layers on a project that needed none of them. It is now an
  11 KB map: every step and check keeps its heading, entry condition and order, and seven long
  checks send the run to one file each in the new `wp-finalize-run` skill — Check 2 (bilingual
  coverage), Check 4 (theme structure), Check 7 (WP-CLI runtime validation), Check 8 (GEO and
  agent-readiness) and demo-parity Layers 1 to 3. No check's wording changed. The checks that read
  `/wp-finalize` now read it with its references expanded in place, and
  `tests/checks/wp-finalize-run.sh` fails when a reference is not pointed to at its check or not
  listed in the skill.
