# /wp-audit — Step 1.5

`commands/wp-audit.md` sends the run here at Step 1.5, after the flags are parsed and before
any of the up-front questions. Follow it in order; nothing in it is optional background.

## Contents

- Detect the baseline
- The single reuse prompt
- Scoped mode
- Labelling the run

## Detect the baseline

Read the `audit` block of `.wp-create.json` (skip this step when there is no manifest) and
look for a prior run in three places: `audit.last_run`, the findings ledger that
`audit.findings_ledger.path` points at, and the newest dated sidecar (`informe-*.json`) in the
report directory Step 8.5 resolves (`--out`, `WP_AUDIT_OUT_DIR`, `audit.out_dir`, then
`.wp-audit`). The baseline date is the newest of the three that exists. If none exists, this
is a first audit: skip the rest of this step and ask the Step 1 questions as usual.

When a baseline exists, print one line before anything else:

```
Re-audit of <YYYY-MM-DD> (baseline: <last_run | ledger | sidecar informe-YYYY-MM-DD.json>)
```

## The single reuse prompt

If `audit.last_answers` exists and validates, ask **one** `AskUserQuestion` in place of the
report-only question, the suite question and the production-URL question. Show every stored
answer, with its date, in the question text:

```
Re-audit of <date>. Last time: <report only | report then fixes>, browser suite <on | off>,
<production URL https://... | clone only, no production URL>  (answered <date>).
  [A] Same as last time
  [B] Same, but re-measure only what changed (scoped mode)
  [C] Choose again — ask each question
```

A and B act as if the stored flags had been typed: `--report-only` (and the `--report both`
default that follows from it), `--suite`, and the stored production URL for Step 2.3 and
Step 6.5. C falls through to the normal Step 1 questions. An explicit flag always wins over a
stored answer, and a question whose flag was typed is not asked about again.

Reuse is never silent:

- The prompt is always shown; there is no "reuse by default" path, and a non-interactive run
  without it asks the Step 1 questions (or fails closed to report-only).
- A stored production URL is only reused through this prompt, shown in full. If it differs
  from the host the manifest or `--host` now names, or the manifest's `environments` no
  longer lists it, do not offer A or B: say the stored URL is stale and use C.
- If `answered` is older than 30 days, or `audit.last_answers` fails validation or is
  absent, do not offer reuse: ask the Step 1 questions. Mention why in one line.
- Answers about installing plugins (Step 4), the security level (Step 5) and the adoption
  prompt are not stored and are asked as usual when they apply.

At most one reuse question is asked. After A, B or C nothing else in Step 1 or Step 2.3
re-asks what was just answered.

## Scoped mode

On B, measure less, not differently:

1. Re-measure every ledger entry whose status is `new`, `still_failing`, `unmeasured` or
   `fixed_unverified` (`ledger.md`): each by its own check on its own resource. Skip
   `accepted` entries: a human closed them, and re-proposing one is how a declined finding
   keeps coming back. A `fixed_unverified` entry that measures clean becomes `resolved`; one
   that is still found returns to `still_failing`.
2. List files changed since `audit.last_run`: `git log --since=<last_run> --name-only` in the
   project root (modification times when it is not a git repository). Map each file to the
   categories that read it (theme PHP and templates: all code-facing categories; CSS and
   JS: performance, a11y, best-practices; `.wp-create.json`/settings: security, seo) and
   run those categories in full.
3. Categories with no open finding and no changed file are reported as **Not re-measured**
   with the baseline's result, never as passing. A resolved status still requires a
   measurement in this run (Step 7.5).
4. If the changed-file list cannot be produced, fall back to a full audit and say so.

## Between audits: use the commands, not the report or memory

When the user says a finding stays as it is, or that fixes were applied since the last run,
and no audit is wanted now, do not remember it, and do not edit the `.md`/`.html` by hand
(the next comparison would then differ from what the sidecar says). Record it:
`audit-report.mjs --accept <id> --reason "..."` or `--mark-fixed <id> --evidence "..."`, then
`audit-report.mjs --rerender` to refresh the report and `audit-report.mjs --summary` for the
counts to quote (`ledger.md`). A full re-audit is for measuring, not for bookkeeping.
Every list of pending work built from the baseline leaves `accepted` entries out.

## Labelling the run

Carry the baseline into the rest of the run:

- The Step 8 console report and the Step 8.5 deliverable open with `Re-audit of <date>` and
  the diff header (resolved / new / still open), counted by finding identity as the renderer
  already does, plus the baseline source and, in scoped mode, the line
  `Scope: open findings and categories touching files changed since <date>`.
- The renderer already opens the deliverable with its comparison against the newest earlier
  sidecar (resolved / new / still failing). Add the label through `--notes <file>`: a first
  paragraph `Re-audit of <date>, compared against <baseline source>` and, in scoped mode, the
  scope line. The report must always state what it was compared against; when the renderer
  found no sidecar (baseline came from the ledger only), the note says so.
- Step 10 persists the answers (`manifest-update.md`).
