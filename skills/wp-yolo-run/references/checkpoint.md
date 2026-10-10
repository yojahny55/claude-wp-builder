# /wp-yolo — Step 3

`commands/wp-yolo.md` sends the run here at Step 3. Follow it in order; nothing in it is optional background.

Print the detected map from the manifest as a build plan:
```
Build plan for <demo-folder>
Pages to build:   <slug> (<role>) — <n> sections: <name:kind>, ...
CPTs to register: <name> (archive: yes/no, <n> seed items) | none
Content types:    <name>: <field list>
Shared header/footer: <ok | divergent on <slugs>>
Skipped:          <out-of-scope pages, missing-HTML pages> | none
Review:           <review[] items> | none
```
Cover, at minimum:
- Pages (slug, role: home / inner / cpt-archive / blog) and their sections (name, kind,
  confidence where < 1.0)
- Shared header/footer flags and any divergent pages
- Content-type classifications (`contentTypes[]`) with field lists
- **Scope annotations** (if `docs/.scope-manifest.json` was loaded): each page's
  `delivery` (theme/idx/plugin), out-of-scope pages skipped, and approved-but-missing-HTML
  pages awaiting a demo
- The full `review[]` list of low-confidence decisions

Ask the user to **approve / edit / abort** with AskUserQuestion, then stop and wait:
- Edit = rename/merge/split a section, drop a page, flip a `kind` between `static` and
  `cpt-teaser`, etc. Apply edits directly to `demo/.yolo-manifest.json` before continuing.
- Abort = stop here, leaving the manifest and `demo/*.html` on disk. On the `tailwind`
  path Step 2.6 has already run by this point, so `demo/*.html` is the converted markup
  and the plain-CSS originals sit in `demo/.original/`.

  A later `/wp-yolo` run is **not** a resume: it starts at Step 2 and dispatches
  `wp-normalize` over the demo folder unconditionally — there is no manifest guard — so
  normalize re-derives `cssRules`, `fonts` and `backgrounds` from the now Tailwind-native
  markup, which no longer carries the plain-CSS declarations or `@font-face` rules they
  were captured from. Step 2.6 then correctly detects the pages as already Tailwind-native
  and skips them, but the manifest **that** Step 4.5's font carry and `/wp-finalize`
  Layer 1 read has already been emptied by then. Nothing fails; the output is quietly
  degraded.

  So a fresh `/wp-yolo` after an abort must start from plain-CSS demo pages: restore
  `demo/<slug>.html` from `demo/.original/<slug>.html` for every page first (or re-run
  against a pristine demo folder), then run `/wp-yolo` again from the top.

  **Step 2 now refuses rather than relying on this being remembered.** `demo/.original/`
  holding any page means a conversion has run, and Step 2 stops with the restore command
  before dispatching normalize — including under `--force`, which discards the theme and
  says nothing about the demo. The degradation was silent, and a workaround documented
  three steps away from the command that triggers it is a workaround nobody applies.

  **`--resume` is the only continuation entrypoint, and it is never `--yolo`.**
  `--yolo` suppresses this checkpoint and nothing else (Step 1: "no checkpoint at all"):
  Step 2 still dispatches `wp-normalize` and still overwrites `demo/.yolo-manifest.json`
  before Step 3 is ever reached, so re-running with it *is* the unconditional-normalize
  path described above and it regenerates the very manifest a resume would have to
  preserve.

  `--resume` is the one entrypoint that does not have this problem, because it does not
  run Step 2 at all — it enters at Step 4 with the manifest already on disk (Step 4.0).
  That is the whole mechanism rather than an optimisation: the steps it skips are
  precisely the ones that consume the demo in place. An abort *before* Step 4 has
  therefore built nothing, so a resume has no work to find and no ledger to read:
  restore the originals and start fresh, as above.

Under `--yolo`, skip this step and proceed straight to Phase 2 with the manifest as
emitted by `wp-normalize`.
