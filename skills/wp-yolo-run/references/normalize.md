# /wp-yolo — Step 2

`commands/wp-yolo.md` sends the run here at Step 2. Follow it in order; nothing in it is optional background.

## Contents

- Refuse a demo that has already been converted (`demo/.original/`)
- Dispatch `wp-normalize`, and a demo this plugin generated is not re-analyzed
- Demo mode
- Research the client, once for the site
- Classify the domain, once for the site
- The browser gate, before anything is built

`demo/.original/` exists only if a conversion has run, so its presence is the signal:

```bash
bash -c "test -d demo/.original && ls demo/.original/*.html 2>/dev/null | head -1"
```

If it holds any page, stop:

```
Error: demo/ has already been converted to Tailwind (demo/.original/ holds <n> pristine pages).
Normalizing converted markup would empty the manifest's cssRules, fonts and backgrounds —
silently, and the build would still report success.

Restore the originals first, then run again:
  cp demo/.original/*.html demo/
Or run against a pristine copy of the demo folder.
```

**`--force` does not bypass this.** `--force` means "discard the built theme and rebuild",
and it is about the theme; it says nothing about the demo, and rebuilding from converted
markup produces exactly the degraded output above. The two flags answer different questions,
and the destructive one here is the quiet one. Restoring the originals is the only way past
this guard, because it is the only thing that makes the build correct.

This is the check Step 2.6 already performs, moved to where it can still act: 2.6's own
idempotence test ("Tailwind evidence and no plain-CSS evidence") runs *after* Step 2 has
dispatched normalize, which is why 2.6 can skip correctly and the run is degraded anyway.

On the plain path nothing converts, `demo/.original/` never exists, and this guard never
fires.

Then dispatch the **wp-normalize** agent against the demo folder from Step 1. It scans every
page, resolves shared header/footer, splits sections, classifies content types
(static-repeater vs custom-post-type), and writes:
- `demo/*.html` — canonical, delimited pages (the same `<!-- SECTION: X -->` format the
  existing builders consume)
- `demo/.yolo-manifest.json` — the orchestration source of truth (`pages[]`, `shared`,
  `contentTypes[]`, `review[]`)

**A demo this plugin generated is not re-analyzed.** `/wp-demo` writes
`demo/.demo-plan.json` recording the page roles, section names, kinds, CPTs and block names
it decided while authoring the pages; `wp-normalize` reads it and copies those verbatim
instead of re-deriving them, per page, wherever the plan still matches the markup. What the
agent still does on such a demo is the reading no one can do ahead of time — CSS
consolidation, field guesses, assets, `cssRules`, `fonts`, `backgrounds` — which is why it is
still dispatched rather than skipped: the manifest is its output, and nothing else writes
one. A demo from anywhere else, or one edited by hand since it was generated, is classified
the old way and says so in `review[]`.

Read `demo/.yolo-manifest.json` back once the agent completes.

**Demo mode.** If `.wp-create.json` already has `demo mode`, read it and move on;
do not re-derive it. Otherwise decide it here using the same craft-versus-plain
test as `/wp-demo` Step 2.5 (project docs, `.claude/CLAUDE.md`, `.wp-create.json`;
`--craft`/`--plain` in `$ARGUMENTS` override), state the one-line reason, and write
`"demo mode"` into `.wp-create.json`. When the mode is **craft**, read
`${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/SKILL.md` and apply its order of work to
the whole multi-page build: the browser gate first, one `demo/DESIGN.md` for the
site, one composition plan covering every page, one evaluator loop over the
directory, and one fingerprint row for the site, not one per page.

**Research the client, here too, once for the site.** If `demo/RESEARCH.md`
already exists — a prior `/wp-demo` run against this project wrote it — read it
and move on. If `.wp-create.json` records `"research": "none"`, skip in one line
and do not retry. Otherwise, a craft `/wp-yolo` run never calls `/wp-demo`, so
it must research the client itself, in these same terms `/wp-demo` Step 2.4
uses on purpose — do not restate them a third way:
dispatch the `wp-research` agent, which reads
`${CLAUDE_PLUGIN_ROOT}/skills/wp-research/SKILL.md` for the method, the source
ladder and the fetch cap.

This run is unattended, so the agent **asks nothing**: it takes the top
candidate, records `confidence: "unconfirmed"` with the candidates it rejected,
and Step 6 states that the identity was unconfirmed. An unconfirmed identity
records no `research.site`, so `designlang` is never pointed at a guess.
Research never blocks this run: if every rung of the ladder fails, record
`"research": "none"` and carry on.

**Classify the domain, here too, once for the site.** If `.wp-create.json`
already has `"domain"` — a prior `/wp-demo` run against this same project
recorded it — read it and move on; do not re-classify. Otherwise, a craft
`/wp-yolo` run never calls `/wp-demo`, so it must classify the domain itself, in
these same terms `/wp-demo` Step 2.6 uses on purpose — do not restate them a
third way: match the
English-language material in **the client documents and `demo/RESEARCH.md`**
(sections `## What they actually say` and `## Competitors`) against the
keyword lists in
`${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/domains/domains.csv`. A
domain is matched when **two distinct keywords** from its list appear in that
corpus; below that, report `unclassified` and carry on without constraining
anything. When more than one domain clears the threshold, the highest hit count
wins; on an exact tie for the top count, report both names and proceed
`unclassified` for the same reason. The lists are English-only: a corpus with
no English-language material is `unclassified` **with that reason stated**, and
the operator may name the domain directly instead of relying on the match.
Record the result once, for the site, not once per page, in `.wp-create.json`
under `"domain"` as `name`, `score`, `matched` and `confidence`, recording in
`matched` **which corpus produced each hit** — `docs` or `research`. The
threshold does not move: two distinct keywords are still required. A matched
domain's `page_pattern` and `considerations` fold into the brief as stated
constraints; it **never touches tokens**, which come from `demo/DESIGN.md` and
the client's own material, never from a category.

**The browser gate, here, before anything is built.** The gate is not `/wp-demo`'s
alone — a craft `/wp-yolo` run never calls `/wp-demo`, so it must run the probe
itself, in these same terms. Run
`node "${CLAUDE_PLUGIN_ROOT}/bin/demo-verify.mjs" --probe`. On exit 2, run
`npm i -D playwright-core` in the project root and probe again (say first that this
writes a `package.json` and a `node_modules/` into the WordPress project root).
After the retry, **only exit 0 continues** — exit 2 means print what the probe said
is missing (`playwright-core` or Chrome; the fix is `WP_DEMO_CHROME` pointing at a Chrome or
Chromium already on the machine, never a browser download), and any other exit code (127 for a missing `node`, or a crash) means print it
verbatim. Either way **stop** the whole run there: do not normalize on, never fall back to plain,
and never build a craft demo blind. `--yolo` does not waive this. The
verify loop that follows is `/wp-demo-verify demo/` over the directory, at most
**three rounds**, reading the pass/fail table it writes to `demo/VERIFY.md` and
fixing every failed line before the next round; after three rounds with failures,
stop and write `demo/FAILED.md` — in the same shape `/wp-demo` Step 2.6 defines —
rather than converting a demo the rubric never passed. Open the loop with
`rm -f demo/FAILED.md`, exactly as `/wp-demo` Step 2.6 defines: the marker
describes this run and not a past one, and clearing it is the only thing that
lets a run which wrote the marker get back past this command's own Step 0 gate.
That loop is the gate this mode exists for, and it blocks — unlike Step 5's
`/wp-responsive-check`, whose findings are folded into the Step 6 review list. The
rules are stated here in the same terms `/wp-demo` Step 2.6 uses on purpose, because
the two entry points must gate identically — do not restate them a third way.
