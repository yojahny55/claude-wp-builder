- **The composition gate answers impeccable's new `kicker-above-heading` rule.** A newer
  impeccable 4.x release flags the small label above the section title in ten non-hero
  compositions, which turned `tests/checks/wp-craft-composition-gate.sh` red on `main`
  and on every open PR. The rule is now ignored only in those ten compositions, through a
  new per-composition `IGNORED_AT` list in `bin/composition-gate.sh`, so a new composition
  that adds a kicker still fails the gate. Removing the kickers
  changes how every craft build looks, so it waits for a measured design PR. The detector
  still follows the newest 4.x.
