# /wp-yolo — Step 6

`commands/wp-yolo.md` sends the run here at Step 6. Follow it in order; nothing in it is optional background.

If any critical demo-parity finding survived Step 5.5's auto-fix + re-verify, or the
GEO scan in Step 5 item 8 did not succeed (unmeasured on exit 2 or 3, errored on exit 1), or
its GEO fixer returned `BLOCKED: <reason>`, or any of Step 5 items 4-8 did not run, do NOT
print "Build Complete." Print instead,
before anything else:
```
=== WP YOLO Build INCOMPLETE — deliverable not signed off ===

Review (blocking):
  - <every unresolved critical finding — layer, selector/property/file, demo value vs. built value>
  - <GEO scan unmeasured (exit 2), not publicly reachable (exit 3 — re-run with --host), or errored (exit 1)>
  - <GEO fixer BLOCKED: wp-agentic-surfaces, its reason, the files it touched, the checks still failing>
  - <any of Step 5 items 4-8 that did not run, and why>

Run /wp-finalize again after resolving the above, then re-run this gate.
```
This applies under `--yolo` too — `--yolo` skips the Step 3 checkpoint, not this gate.
A run whose GEO scan did not succeed cannot print "Build Complete".

Otherwise, print a summary:
```
=== WP YOLO Build Complete ===
Pages built:       <slug list, with section counts>
CPTs registered:   <name list, with archive/single status and seed count>
CF7 forms:         <count, if any contact sections were found>
Media imported:    <count>
Mandatory pages:   404, search (always built)
Visual:            <counts, only with --visual — see visual-pass.md>
Embed/IDX pages:   <slug list — "install & configure <provider>" for each delivery: idx|plugin page>

Review:
  - <every review[] entry from the manifest — low-confidence splits, CPT-vs-repeater
    verdicts, ambiguous fields>
  - <untranslated secondary-language strings, if any>
  - <GEO findings left unfixed — advisory, off-site (no theme file can change it)>
  - <anything skipped — e.g. JS-only interactivity not reproducible in static templates>
  - <out-of-scope pages skipped: "in demo but out of scope — skipped">
  - <approved-but-missing-HTML pages: "approved/designed but no HTML — needs demo">
  - <research identity: confirmed or unconfirmed, with the name>
```

**On a resumed run**, add a Resume block above Review, and delete
`demo/.yolo-progress.json` once the summary is printed (Step 4.0):
```
Resumed:
  Skipped (already built):     <count> units
  Rebuilt (artifact missing):  <unit id list — the ledger claimed these, the files were gone>
  Built this run:              <count> units
  Drift accepted:              <file list, only when --accept-drift was passed>
```
The rebuilt-because-missing list is never folded into the built count. It is the one
signal that the ledger and the theme directory had diverged, and a reader who cannot
see it cannot know which parts of the site this run actually looked at.

Note for the user: `--yolo` is best used **after** one checkpointed dry-run of the same
demo folder, once the manifest has been reviewed and edited at least once.
