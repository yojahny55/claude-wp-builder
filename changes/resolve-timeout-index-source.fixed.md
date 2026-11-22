- **A hung resolver no longer hangs the production gate, and the design-md index keeps
  its hand corrections.** `bin/lib/local-host.sh` runs `getent ahosts` under `timeout 3`
  when `timeout` exists; a lookup that times out resolves to nothing, which is the
  not-local side. `bin/design-md-index.sh` reads hand corrections from
  `references/design-md/INDEX.overrides` (`<domain> <industry> [<tone>]` per line) and
  applies them after its keyword heuristic, so regenerating `INDEX.md` no longer erases
  the twelve rows that had been fixed by hand. An override naming a domain with no
  DESIGN.md fails the run, and a check fails when the versioned `INDEX.md` differs from a
  regeneration.
