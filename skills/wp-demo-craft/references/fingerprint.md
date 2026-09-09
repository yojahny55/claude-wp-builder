# The fingerprint gate

Adapted from nateherkai/scroll-craft (MIT).

v2 keeps one job for the gate: stop two clients from getting the same palette and
type pair. Structure is no longer fingerprinted. The composition library makes
structure a choice per role rather than a signature, and fingerprinting it only
pushed builds into shapes chosen to clear the log instead of to suit the client —
which is how a credit-repair firm ended up with a split stage.

## The row

`~/.claude/wp-builder/FINGERPRINTS.md` holds one row per shipped craft build. It
is per-user and starts empty; create it with the header row when it is absent.

| client | display | text | accent | canvas | date |
|---|---|---|---|---|---|

## The gate

A new `demo/DESIGN.md` fails the gate when, against any existing row, **all
three** hold: the same display family, the same text family, and an accent hue
within 15 degrees of each other on the colour wheel. Two brands sharing a canvas or one of the
two faces is coincidence; sharing the pair and the accent is the same site twice.

Change the type pair or the accent. Do not touch the registry. **If the planned
build fails the gate, change the plan, not the log.** Rewriting a row to make a
new build fit is the one thing that makes this file worthless: it is a record of
what exists, not a description of what you wish existed.

## Where the row goes

Append it to the registry after shipping, and write the same row into the
project's `.wp-create.json` under `"fingerprint"`, so the project carries its own
record alongside the per-user file.

A build that fails the verify rubric after three rounds records no row anywhere.
The registry is a list of what was shipped; a page that did not pass was not
shipped, and logging it would make the gate refuse a palette no client ever saw.

## v1 rows

Rows written under v1 (six structural axes: grammar, nav, hero, sequence, close,
signature move) stay in the file untouched. Only the four palette and type
columns are compared, and a v1 row that does not carry them is skipped.
