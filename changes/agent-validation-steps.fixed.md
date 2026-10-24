- **`wp-acf`, `wp-cf7` and `wp-normalize` end in a validation step they can run.** The
  first two generate PHP under fine-grained rules on the haiku tier and their tests only grep
  prose, so a generated file that did not parse shipped unnoticed; `wp-normalize` wrote the
  manifest the whole build follows with no Bash to check it. `wp-acf` and `wp-cf7` now finish
  with `php -l` on what they wrote plus `wp-config.mjs validate`, and `wp-normalize` gets
  Bash for one final manifest parse. The tiers are unchanged (the step is the cheaper fix);
  `model-routing.sh` records why and a new check pins the steps.
