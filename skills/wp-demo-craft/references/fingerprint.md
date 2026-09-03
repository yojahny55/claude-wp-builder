# The fingerprint gate

Adapted from nateherkai/scroll-craft (MIT).

A page's structure axis, not its palette, is what makes two builds feel
related. The fingerprint gate stops a new build from silently repeating a
prior one's shape.

## The six axes

| # | Axis | What it records |
|---|---|---|
| 1 | Grammar | Which grammar from `grammars.md`, or a named new one |
| 2 | Nav treatment | What the chrome is and what it is for |
| 3 | Hero device | What the first screen does |
| 4 | Sequence shape | Device order, section count, total viewport-heights |
| 5 | Close pattern | How the last screen behaves and what the CTA sits in |
| 6 | Signature move | The one bespoke interaction, in a phrase |

## The gate

A new build must differ from **every** existing row on at least 4 of the 6 axes, individually, not on average across the table.

Axis six (signature move) is free, because a signature move is unique by
definition. So the gate really asks for three more out of the remaining five,
against each row.

**If the planned build fails the gate, change the plan, not the log.**
Rewriting a fingerprint row to make a new build fit is the one thing that
makes this file worthless. It is a record of what exists, not a description
of what you wish existed.

## The registry

The registry lives at `~/.claude/wp-builder/FINGERPRINTS.md`. It is per-user
and starts empty.

- Read it before planning.
- Create it with a header row when it is absent.
- Append one row after shipping, filling all six axes.

Also write the project's own row into the project's `.wp-create.json` under a
`fingerprint` key, so the project carries its own record alongside the
per-user registry.

## The signature move

Every build invents one bespoke interaction that exists on that site alone,
coded in `assets/js/signature.js`, reading `--motion-p`. Not a device kit
parameter change.

**What counts:**

- A persistent trace rail the scroll draws, marking each section passed.
- A wordmark the pointer can pull apart and that settles back on release.
- An SVG technical drawing that draws itself from scroll.
- A running receipt that accumulates a line per real claim passed.
- One control that regrades the whole page at once (time of day, temperature,
  load level).

**What does not count:**

- A recoloured spotlight, or a spotlight at a different radius.
- A changed tilt angle (`data-motion-dir` swap, parameter tweaks).
- A different easing curve on kinetic lines.
- More of an existing device (a longer rail, a third wipe).

Test: describe the move to someone who has seen the other builds. If they
cannot tell it apart from something the kit already does, it is not a
signature move.
