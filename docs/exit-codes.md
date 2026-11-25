# Exit codes of `bin/*.mjs`

Every Node tool in `bin/` reports through its exit code, and commands, skills and checks read
those numbers in prose ("exit 2 = no browser"). This page is the table of what each tool
really returns today. Its machine-readable twin is `bin/lib/exit-codes.mjs`, and
`tests/checks/exit-code-table.sh` fails when a tool exits with a code that is not declared
here and there.

## No renumbering

The numbers are documented as they are, not unified. A renumbering would have to edit every
command, skill and check that names a code, and a site missed breaks no test: the prose
just stops being true. A node uncaught exception also exits 1 in any tool, whatever its table
says.

## Scheme for new tools

A tool written from now on uses `COMMON` from `bin/lib/exit-codes.mjs`:

| Code | Meaning |
|---|---|
| 0 | ok |
| 1 | negative result, measured (findings, below threshold, invalid input) |
| 2 | could not measure (no browser, no key, no network) |
| 3 | crash (uncaught exception) |
| 64 | usage (EX_USAGE): malformed arguments |
| 4-9 | specific to the tool, declared in its `TOOLS` entry and in a section below |

A tool absent from `TOOLS` may only use the `COMMON` codes. The existing tools below keep
their own numbers: usage is 1, 2 or 3 depending on the tool, and `wp-config.mjs` is the
named exception (read by every command through `skills/wp-manifest-gate/SKILL.md`).

## Existing tools

### `assets-fresh.mjs`

| Code | Meaning |
|---|---|
| 0 | fresh, or no manifest (prints SKIP) |
| 1 | stale critical cuts |
| 2 | usage, unreadable or empty manifest |

### `audit-coverage.mjs`

| Code | Meaning |
|---|---|
| 0 | coverage at or above the threshold (or --list) |
| 1 | below the threshold, or incomplete with --final |
| 2 | usage, missing results, or invalid agent reports |
| 3 | crash |

### `audit-report.mjs`

| Code | Meaning |
|---|---|
| 0 | rendered or updated |
| 1 | usage or invalid input (bad arguments, unreadable JSON, findings that cannot render) |
| 3 | crash, or the earlier run could not be archived (nothing changed) |

### `audit-runbook.mjs`

| Code | Meaning |
|---|---|
| 0 | runbook rendered |
| 1 | usage or invalid input (bad replay record, local host or path would leak) |
| 3 | crash |

### `canary.mjs`

| Code | Meaning |
|---|---|
| 0 | snapshot written with at least one page loaded; compare found no regression (warnings allowed) |
| 1 | compare found a regression |
| 2 | could not measure: no playwright-core, no Chromium, or no page loaded |
| 3 | crash |
| 64 | usage: bad arguments, URLs on more than one host, snapshots of different hosts |

### `composition-preview.mjs`

| Code | Meaning |
|---|---|
| 0 | preview rendered (or --tokens printed) |
| 2 | no playwright-core or no browser |
| 3 | crash, or the composition has no section.html/section.css |

### `contrast-propose.mjs`

| Code | Meaning |
|---|---|
| 0 | proposals printed |
| 2 | usage or unusable colour input |

### `css-contour-lint.mjs`

| Code | Meaning |
|---|---|
| 0 | pass |
| 1 | findings |
| 2 | usage |

### `decision-sheet.mjs`

| Code | Meaning |
|---|---|
| 0 | ok |
| 1 | --parse: no DECISION line parsed, or a line was dropped |
| 2 | usage, no browser, or an unsafe --date |
| 3 | page written but a card is incomplete |

### `demo-verify.mjs`

| Code | Meaning |
|---|---|
| 0 | clean (also --probe ok and --help) |
| 1 | blocking findings, a page crashed, no pages, or usage |
| 2 | no playwright-core or no browser |
| 3 | the walk crashed |

### `h2-proxy.mjs`

| Code | Meaning |
|---|---|
| 0 | stopped by SIGINT or SIGTERM |
| 1 | openssl missing and no --cert/--key |
| 2 | usage, or --target is not plain http |

### `image-gen.mjs`

| Code | Meaning |
|---|---|
| 0 | ok |
| 2 | usage, invalid plan, or the approved prompt changed |
| 3 | no API key (nothing written, nothing billed) |
| 4 | one or more slots failed, or crash |

### `link-sweep.mjs`

| Code | Meaning |
|---|---|
| 0 | sweep ran (findings are in the JSON; --help) |
| 1 | crash |
| 2 | usage |
| 4 | blocked by the host, --stop-on-block stopped it |

### `section-diff.mjs`

| Code | Meaning |
|---|---|
| 0 | every viewport within the pixel and size tolerances |
| 1 | a viewport over a tolerance |
| 2 | nothing measured: no playwright-core, pixelmatch, pngjs or Chrome, or a page failed |
| 4 | section not found on one side, or its selector matches more than one element |
| 64 | usage |

### `style-diff.mjs`

| Code | Meaning |
|---|---|
| 0 | no non-noise style diff |
| 1 | style diffs found (size diffs only with --fail-on-size) |
| 2 | usage or no browser |
| 3 | INCOMPLETE: no diff, but a page or viewport was unmeasured |

### `tailwindify-parity.mjs`

| Code | Meaning |
|---|---|
| 0 | clean (also --help and --list-breakpoints) |
| 1 | deltas found, or a page could not be rendered |
| 2 | no playwright-core or no browser |
| 3 | crash, or bad usage (missing --against, bad paths, nothing to compare) |

### `theme-template-check.mjs`

| Code | Meaning |
|---|---|
| 0 | pass |
| 1 | findings |
| 2 | usage |

### `ux-probe.mjs`

| Code | Meaning |
|---|---|
| 0 | ran (findings and unmeasured items are in the JSON) |
| 1 | crash |
| 2 | usage or no browser |
| 3 | budget spent (launches or wall clock) |
| 130 | SIGINT |
| 143 | SIGTERM |

### `lib/browsers.mjs`

A library module that is also a CLI (`node bin/lib/browsers.mjs <engine>`); `/wp-audit`'s
browser tier reads its exit 2 as "no browser".

| Code | Meaning |
|---|---|
| 0 | browser found (path on stdout) |
| 1 | usage: engine is not chromium, firefox or webkit |
| 2 | no browser of that engine on the machine |

### `wp-config.mjs`

| Code | Meaning |
|---|---|
| 0 | ok |
| 1 | invalid or refused |
| 2 | a manifest migration is available |
| 3 | no manifest (or no profile) |
| 4 | drift, tool state not git-ignored, or secret-looking files |
| 5 | adopted site (require-origin): the builder must stop |

