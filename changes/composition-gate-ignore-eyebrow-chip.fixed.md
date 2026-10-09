- **The composition gate ignores `hero-eyebrow-chip` for now, and keeps following the newest
  `impeccable` 4.x.** impeccable 4.5.1 and 4.5.2 added a `hero-eyebrow-chip` rule that flags the
  kicker above the title in `hero-bleed`, `hero-split`, `hero-type` and `page-head`, so
  `tests/checks/wp-craft-composition-gate.sh` and `Contract checks` failed on `main` and on every
  open PR with no change in the repository. Restyling those kickers is a design change that needs
  measuring and approval, so it is a separate PR. Until then `bin/composition-gate.sh` lists the
  rule in `IGNORED`, prints how many findings it skipped on every run, and still blocks on every
  other slop rule, new ones included. The check fails if the gate is pinned to one version or the
  ignore list changes without it. `/wp-demo-verify` is unchanged and still reports the rule on a
  built demo.
