# The fingerprint gate

Adapted from nateherkai/scroll-craft (MIT).

**v3 restores the structural axes v2 retired.** v2 kept one job for the gate —
stop two clients getting the same palette and type pair — on the reasoning that
the composition library makes the structural choice per role, so structure did
not need fingerprinting. That reasoning was wrong, and the way it was wrong is
worth keeping: **a library that offers one good answer per role gives every build
the same answer**, and fingerprinting structure is exactly what catches that.
With only the palette compared, two structurally identical sites passed the gate
because their fonts differed, and the report that followed was "all the pages are
almost the same thing."

The dimensions and the 4-of-7 rule live in
[uniqueness.md §5](uniqueness.md). This file owns the registry: where the row
goes, what is written into it, and the rules that are about records rather than
about shapes.

## The row

`~/.claude/wp-builder/FINGERPRINTS.md` holds one row per shipped craft build. It
is per-user and starts empty; create the header row when it is absent.

| client | grammar | chrome | hero | sequence | close | signature | display | text | accent | canvas | date |
|---|---|---|---|---|---|---|---|---|---|---|---|

## The gate

A planned build must differ from **every** existing row on at least
**4 of the 7 dimensions** in [uniqueness.md §5](uniqueness.md) — four against each row
individually, not four on average across the table.

On top of the count, one absolute rule: a new `demo/DESIGN.md` fails outright
when, against any existing row, **all three** hold — same display family, same
text family, accent hue within 15 degrees on the colour wheel. Two brands sharing a
canvas or one of two faces is coincidence; sharing the pair and the accent is the
same site twice. Change the type pair or the accent. Do not touch the registry.

**If the planned build fails the gate, change the plan, not the log.** Rewriting a
row to make a new build fit is the one thing that makes this file worthless: it
is a record of what exists, not a description of what you wish existed.

## Where the row goes

Append it to the registry after shipping, and write the same row into the
project's `.wp-create.json` under `"fingerprint"`, so the project carries its own
record alongside the per-user file.

A build that fails the verify rubric after three rounds records no row anywhere.
The registry is a list of what was shipped; a page that did not pass was not
shipped, and logging it would make the gate refuse a palette no client ever saw.

## v1 and v2 rows

Rows written under v1 carry all six structural axes and are compared in full.
Rows written under v2 carry only the palette and type columns; they are compared
on those, and their missing structural columns count as **no match** — a v2 row
cannot clear a structural dimension it never recorded. Backfilling a v2 row from
the shipped demo is allowed and is better than leaving it blind, as long as it
records what was built rather than what would be convenient.

## The same-client rule

When a row already exists for this `client`, the new build must
differ in grammar and in the hero composition, and the
composition plan must say how. This is two sentences of judgement on top of the
gate, not a replacement for it.

The gate was otherwise blind twice over for a repeat client under v2: structure
was not compared at all, and a build that failed the rubric records no row — so a
rejected demo was invisible on every axis including palette. The rule therefore
reads the plan rather than the registry alone, which is what lets a deleted
predecessor still constrain its successor.

A client rejected a demo, had it deleted, and received a rebuild whose header
silhouette reproduced the recorded fingerprint of the rejected one almost
exactly: "a slim top bar holds the wordmark, EN/ES and Client login".
