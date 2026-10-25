- **One exit-3 policy instead of eight copies.** `/wp-audit`, `/wp-debug`, `/wp-adopt`,
  `/wp-init`, `/wp-seed`, `/wp-robin`, `/wp-s3`, `/wp-update` and the two `/wp-clone` paths each
  carried a hand-written "Amending the exit `3` row above" paragraph, and they had drifted. They
  now name one policy defined in the new `wp-manifest-gate` skill (`stop`, `adopt-or-stop`,
  `adopt-or-bare-wp`, `bare-wp-fallback`, `scaffold`, `register`, `destination-adopt`);
  `tests/checks/wp-config-gate.sh` pins the table and refuses the inline paragraph.
