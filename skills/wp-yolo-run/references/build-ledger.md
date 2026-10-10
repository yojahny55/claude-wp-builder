# /wp-yolo — Step 4.0

`commands/wp-yolo.md` sends the run here at Step 4.0. Follow it in order; nothing in it is optional background.

## Contents

- The unit
- What the ledger does not cover
- The ledger file
- A generated file someone else changed
- Entering with `--resume`
- Verify before skipping

### The unit

One dispatch, one unit. Ids are recomputed from the manifest on every run rather than
stored as a list, so a manifest edit cannot leave the ledger describing units that no
longer exist:

```
settings                      cpt:<name>                header       footer
section:<page-slug>:<block>   page:<slug>               page:blog
page:404                      page:search               seed-cpt:<name>
promotion                     fonts                     behaviour
```

`<page-slug>` is `index` for the home page and the page's own slug for an inner page;
`<block>` is the unique BEM block Step 4 already assigns each section so parallel agents
cannot collide on a selector. `section:index:hero` is therefore stable across runs with
no counter to keep.

**A section is one unit, not three.** `/wp-section` dispatches three agents in parallel;
two of three finished is not a built section.

**There is no resume inside a unit.** An interrupted unit writes no ledger entry, so the
next run re-dispatches it and it overwrites its own half-written file. The granularity
is the recovery — there is no partial state to reconcile and nothing to roll back.

### What the ledger does not cover

Two kinds of step are deliberately absent, and adding them would each cause a defect.

- **Steps that are already idempotent.** `/wp-seed` re-enters correctly by itself: it
  owns records by marker and fields by digest, and reports a client's edit rather than
  reverting it. A resume simply runs it. A ledger entry here would be a second source of
  truth for a question the command already answers, and a stale one skips a seed the
  demo needs.
- **Steps that measure.** The Tailwind rebuild, `/wp-finalize`, `/wp-polish`,
  `/wp-responsive-check` and the Step 5.5 parity gate all read the **live site**.
  Skipping one because an earlier run performed it would report a gate result for a
  build that no longer exists — a signed-off deliverable nobody measured. These always
  run, on a resume exactly as on a fresh build.

Stated once: **the ledger covers work that generates, never work that verifies.**

### The ledger file

`demo/.yolo-progress.json`, beside the manifest — not in `.wp-create.json`, which is
configuration every command parses on every run, where this is transient build state
that dies with the demo folder.

```json
{
  "version": 2,
  "started": "2026-09-18T14:02:11Z",
  "completed": null,
  "plugin_version": "1.24.0",
  "inputs": {
    "manifest": "<sha256 of demo/.yolo-manifest.json>",
    "pages": { "index": "<sha256>", "about": "<sha256>" }
  },
  "units": [
    { "id": "section:index:hero",
      "at": "2026-09-18T14:09:40Z",
      "artifact": "template-parts/section-hero.php",
      "output": "<sha256 of that file as written>" }
  ]
}
```

Three of those fields are new in `version: 2`, and each closes a question the old ledger
could not answer.

**`output`** is the digest of the artifact as this command wrote it. Resume used to skip a
unit when its file existed and was non-empty, which cannot tell *our* output from anyone
else's: a half-written template part that a crashed agent left syntactically valid is
non-empty, and so is a file a developer edited by hand between runs. With a digest, three
states are distinguishable where there used to be two — matches (ours, skip it), differs
(someone else's work, see below), absent (never built).

**`plugin_version`** is this plugin's version, not the ledger format's — `version` already
covers the format, and the two were conflated. A resume across a plugin upgrade is a
resume whose remaining units will be built by different instructions than the finished
ones, which is worth saying out loud rather than discovering in the diff.

**`completed`** replaces deleting the file. The old rule was to delete the ledger on
success, and its reason was sound: a leftover ledger is a `--resume` aimed at a site that
needs nothing. But deleting it also destroys the only record of what this build produced,
which is the record any later update has to start from. Setting `completed` keeps the
record and keeps the protection — `--resume` on a ledger with a `completed` timestamp
refuses, and says the build finished and when:

```
Error: this build completed at 2026-09-18T15:40:02Z — there is nothing to resume.
Run /wp-yolo --force to rebuild from the demo.
```

A `--force` rebuild still deletes the ledger before Step 2, unchanged: the inputs it
digested are about to be regenerated and every digest in it is about to become a lie.

### A generated file someone else changed

With `output` recorded, a resume can see that an artifact on disk is not the one it wrote.
It must not silently replace it, and it must not silently keep it:

```
demo/.yolo-progress.json records section:index:hero as
  template-parts/section-hero.php  sha256 9f2c…
but that file now digests to  4ab1…

Someone edited it after this build wrote it. Rebuilding replaces those edits.
  Keep the edits:    /wp-yolo --resume --skip section:index:hero
  Discard and build: /wp-yolo --resume --rebuild section:index:hero
```

Report every such unit before building any of them, so the operator sees the whole list
and makes one decision rather than being interrupted per file.

Create it at the top of Step 4 on **every** run, not only under `--resume` — a run that
is never interrupted still writes one, and that is what makes the next one resumable.
`inputs` is digested once, here, before the first dispatch:

```bash
sha256sum demo/.yolo-manifest.json demo/index.html demo/<slug>.html
```

Append one entry the moment a unit returns, with `jq` — never in a batch at the end of a
phase, which loses exactly the units a crash interrupted:

```bash
ART="template-parts/section-hero.php"
jq --arg id "section:index:hero" --arg at "$(date -u +%FT%TZ)" \
   --arg art "$ART" \
   --arg out "$(sha256sum "$ART" 2>/dev/null | cut -d' ' -f1)" \
   '.units += [{id: $id, at: $at, artifact: $art, output: $out}]' \
   demo/.yolo-progress.json > demo/.yolo-progress.json.tmp \
   && mv demo/.yolo-progress.json.tmp demo/.yolo-progress.json
```

Digest the file at the moment the unit returns, not later: anything that runs in between
can touch it, and a digest taken afterwards would record that state as ours.

`artifact` is theme-relative, and is `null` for a unit that writes no single file
(`settings`). Write it through a temp file and `mv`: a crash during the write of a
ledger is the one crash that must not also destroy the record of everything before it.

**Stamp `completed` on a successful completion**, in the same place Step 6 appends the
`## Workflow — DONE, do not re-run` note:

```bash
jq --arg at "$(date -u +%FT%TZ)" '.completed = $at' \
   demo/.yolo-progress.json > demo/.yolo-progress.json.tmp \
   && mv demo/.yolo-progress.json.tmp demo/.yolo-progress.json
```

and **delete it before Step 2 on a `--force` rebuild**, where the inputs it digested are
about to be regenerated and every digest in it is about to become a lie.

### Entering with `--resume`

`--resume` enters **here**, at Step 4. It has not run Steps 2, 2.5, 2.6 or 3, and must
not: those are the steps that convert `demo/*.html` in place and rewrite the manifest.

**Refuse when there is no ledger:**

```
Error: no demo/.yolo-progress.json — there is no interrupted run to resume.
Run /wp-yolo without --resume to build from the demo.
```

`--resume` with nothing to resume is a typo, not a request for a fresh build. Silently
converting one into the other is how a resume flag overwrites a finished site.

**Then check for drift.** Re-digest `demo/.yolo-manifest.json` and every page named in
`inputs.pages`, and compare against the stored digests. Unchanged → continue. Changed,
or a recorded page now missing → stop, naming the file, what it feeds, and how far the
previous run got:

```
Error: demo/.yolo-manifest.json changed since the interrupted run.
It feeds every section build. 4 of 11 units completed against the previous version.
  Rebuild from scratch: restore demo/.original/*.html, then /wp-yolo --force
  Continue anyway:      /wp-yolo --resume --accept-drift
```

Without those three facts the message is one an operator cannot act on. Resuming across
a changed input builds half a theme from one manifest and half from another, and nothing
downstream fails — the parity gate measures the built site against the demo it can see
now, so the half built from the old manifest is simply wrong and green.

`--accept-drift` proceeds anyway, and exists because the edit is often deliberate: the
manifest was fixed to correct whatever broke the run. It is its own flag and is **not**
implied by `--force`, the same way `--force-fields` is not implied by `--force` in
`/wp-seed`. A run that accepts drift re-digests `inputs` and says so in the Step 6
report.

### Verify before skipping

Walk the units in the Step 4 order below. For each:

- **no ledger entry** → dispatch it.
- **entry, `artifact` non-null, file present and non-empty** → skip it, and count it as
  resumed in the report.
- **entry, `artifact` non-null, file missing or empty** → **it is not done.** Dispatch
  it, and list it in the Step 6 report as rebuilt-because-missing. A ledger can outlive
  the files it describes — someone deleted a template part, or a theme directory was
  restored from elsewhere — and trusting it here leaves a hole the build reports as
  filled.
- **entry, `artifact` null** → skip on the ledger alone (`settings` only).
