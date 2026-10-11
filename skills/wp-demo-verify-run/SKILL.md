---
name: wp-demo-verify-run
description: "The step detail of the /wp-demo-verify run, split out of commands/wp-demo-verify.md so the command stays a short map — Step 2a (the impeccable detector and its gate), Step 2b (the scroll walk, Firefox pass, --no-motion, fractional widths and the exit-code 2 fallback) and Step 3 (reading every finding kind). Use when /wp-demo-verify reaches a step that names one of these reference files, or when changing how a /wp-demo-verify step behaves. Not for target resolution, the inert-control grade, the sheet critique or the report (they stay in the command), nor for building a demo (wp-demo-run)."
user-invocable: false
---

# /wp-demo-verify step detail

`commands/wp-demo-verify.md` owns the order of the run. Each step that needs more than a few
paragraphs keeps its heading and entry condition there and sends the run to one file here. The
command reads the file at that step, not before.

These files are the step itself, not background reading. When the command says to read one,
read it whole and follow it in order.

## References, by step

| Step | File | Covers |
|---|---|---|
| 2a | [references/detector.md](references/detector.md) | The `impeccable` detector: version pin, what its exit codes mean, "detector could not run", the `slop` plus `warning` gate, advisories and `quality` findings |
| 2b | [references/walk.md](references/walk.md) | The walk: positions and viewports, the Firefox pass, `--no-motion`, output layout, fractional widths and `--no-gaps`, and the fallback on exit code 2 |
| 3 | [references/findings.md](references/findings.md) | Every finding kind the walk reports, which ones block a round and how to fix each |

## Changing a step

Edit the reference file, not the command, unless the step order or the step's entry
condition changes. A check that guards a step's wording reads the command with these files
expanded in place (`tests/checks/lib/expand-command.sh`); `tests/checks/wp-demo-verify-run.sh`
asserts that every file here is named both in this table and at its step in
`commands/wp-demo-verify.md`.
