# The fingerprint gate

Adapted from nateherkai/scroll-craft (MIT).

## Contents

- The seven dimensions
- The row
- The gate
- Where the row goes
- Older rows
- The same-client rule

The gate compares **structure as well as palette**. A library that offers one good answer
per role gives every build the same answer, and fingerprinting structure is exactly what
catches that: with only the palette compared, two structurally identical sites passed
because their fonts differed, and the report that followed was "all the pages are almost
the same thing."

## The seven dimensions

| # | Dimension | What it records |
|---|---|---|
| 1 | Grammar | Which grammar from `grammars.md`, or a named new one |
| 2 | Chrome treatment | What the header and footer are, and what they are for |
| 3 | Hero device | What the first screen does |
| 4 | Section-sequence shape | The composition order on the home page, the section count, total viewport-heights |
| 5 | Close pattern | How the last screen behaves and what the CTA sits in |
| 6 | Signature move | The one bespoke interaction, in a phrase |
| 7 | Type and palette | Display face, text face, accent hue |

## The row

`~/.claude/wp-builder/FINGERPRINTS.md` holds one row per shipped craft build. It
is per-user and starts empty — the gate is about not repeating **yourself** — so
create the header row when it is absent.

| client | grammar | chrome | hero | sequence | close | signature | display | text | accent | canvas | date |
|---|---|---|---|---|---|---|---|---|---|---|---|

## The gate

Read the registry before the composition plan: every row is a shape that is now taken.
A planned build must differ from **every** existing row on at least
**4 of the 7 dimensions** above — four against each row individually, not four on
average across the table. Dimension 6 is free, because a signature move is unique by
definition.

On top of the count, one absolute rule: a new `demo/DESIGN.md` fails outright
when, against any existing row, **all three** hold — same display face, same
text face, accent hue within 15 degrees on the colour wheel. Two brands sharing a
canvas or one of two faces is coincidence; sharing the pair and the accent is the
same site twice. Change the type pair or the accent. Do not touch the registry.

**If the planned build fails the gate, change the plan, not the log.** Rewriting a
row to make a new build fit is the one thing that makes this file worthless: it
is a record of what exists, not a description of what you wish existed.

## Where the row goes

After shipping, append the row to the registry and say plainly what it shares with
prior rows: the shared columns are what the next build has to avoid. Write the same
row into the project's `.wp-create.json` under `"fingerprint"`, one key per column:

```json
"fingerprint": {
  "client": "…", "grammar": "…", "chrome": "…", "hero": "…", "sequence": "…",
  "close": "…", "signature": "…", "display": "…", "text": "…", "accent": "#…",
  "canvas": "#…", "date": "YYYY-MM-DD"
}
```

A build that fails the verify rubric after three rounds records no row anywhere.
The registry is a list of what was shipped; a page that did not pass was not
shipped, and logging it would make the gate refuse a palette no client ever saw.

## Older rows

Rows from before the structural columns carry only the palette and type columns.
They are compared on those, and their missing structural columns
count as **no match** — a row cannot clear a structural dimension it never recorded.
Backfilling one from the shipped demo is allowed and is better than leaving it blind,
as long as it records what was built rather than what would be convenient.

## The same-client rule

When a row already exists for this `client`, the new build must
differ in grammar and in the hero composition, and the
composition plan must say how. This is two sentences of judgement on top of the
gate, not a replacement for it.

It reads the plan rather than the registry alone because a build that failed the
rubric records no row, so a rejected predecessor is invisible to the registry on every
axis. The plan is what lets a deleted predecessor still constrain its successor.

A client rejected a demo, had it deleted, and received a rebuild whose header
silhouette reproduced the recorded fingerprint of the rejected one almost
exactly: "a slim top bar holds the wordmark, EN/ES and Client login".
