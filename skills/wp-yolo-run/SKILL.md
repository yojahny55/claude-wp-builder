---
name: wp-yolo-run
description: "The step detail of the /wp-yolo run, split out of commands/wp-yolo.md so the command stays a short map — the normalize dispatch and its refusals, the Tailwind demo conversion, the checkpoint, the build ledger and --resume, the @apply promotion pass, the font and behaviour carries, and the demo-parity gate. Use when /wp-yolo reaches a step that names one of these reference files, or when changing how a /wp-yolo step behaves. Not for the builders /wp-yolo dispatches, which own their own steps."
user-invocable: false
---

# /wp-yolo step detail

`commands/wp-yolo.md` owns the order of the run. Each step that needs more than a few
paragraphs keeps its heading and entry condition there and sends the run to one file here. The
command reads the file at that step, not before, so a run pays only for the steps it reaches.

These files are the step itself, not background reading. When the command says to read one,
read it whole and follow it in order.

## References, by step

| Step | File | Covers |
|---|---|---|
| 2 | [references/normalize.md](references/normalize.md) | The `demo/.original/` refusal, the `wp-normalize` dispatch, demo mode, client research, domain classification, the browser gate |
| 2.6 | [references/demo-conversion.md](references/demo-conversion.md) | In-place Tailwind conversion with a backup, per-page detection, repeated cards, failure handling |
| 3 | [references/checkpoint.md](references/checkpoint.md) | The build plan, approve / edit / abort, what follows an abort, `--resume` as the only continuation |
| 4.0 | [references/build-ledger.md](references/build-ledger.md) | The unit, the ledger file, a generated file someone else changed, `--resume`, verifying before skipping |
| 4.4 | [references/apply-promotion.md](references/apply-promotion.md) | The single author-mode `wp-tailwind` promotion pass after the walk |
| 4.5 | [references/font-carry.md](references/font-carry.md) | Collecting `section.fonts[]`, an empty collection, self-hosting each family |
| 4.6 | [references/behaviour-carry.md](references/behaviour-carry.md) | Porting every demo script and proving it runs before Step 5 |
| 5.5 | [references/parity-gate.md](references/parity-gate.md) | Auto-fixing mechanical parity findings per template, re-verifying, blocking |

## Changing a step

Edit the reference file, not the command, unless the step order or the step's entry
condition changes. A check that guards a step's wording reads the command with these files
expanded in place (`tests/checks/lib/expand-command.sh`); `tests/checks/wp-yolo-run.sh`
asserts that every file here is named both in this table and at its step in
`commands/wp-yolo.md`.
