/**
 * exit-codes.mjs: the documented exit-code table of every bin/*.mjs tool.
 *
 * Nothing imports this at run time. It is the data tests/checks/exit-code-table.sh reads, and
 * docs/exit-codes.md is its human-readable twin. Keep the three in step.
 *
 * Decision: the numbers below are what the tools already return. Nothing was renumbered,
 * because commands, skills and checks read those numbers in prose ("exit 2 = no browser") and
 * a site missed in a renumbering breaks no test.
 *
 * COMMON is the scheme a NEW tool follows. TOOLS is the truth for the existing ones, read from
 * each tool's process.exit(N) / process.exitCode = N / die(N, ..) / usage(msg, N) sites.
 * A tool absent from TOOLS may only use COMMON codes.
 */

/** The scheme for tools written from now on. 4-9 are specific to a tool and declared in TOOLS. */
export const COMMON = {
  0: 'ok',
  1: 'negative result, measured (findings, below threshold, invalid input)',
  2: 'could not measure (no browser, no key, no network)',
  3: 'crash (uncaught exception)',
  64: 'usage (EX_USAGE): malformed arguments',
};

/** Codes a new tool may declare for itself, on top of COMMON. */
export const SPECIFIC_RANGE = [4, 9];

/** Existing tools, with the codes they really return. A code not listed here is a bug or an omission. */
export const TOOLS = {
  'assets-fresh.mjs': {
    0: 'fresh, or no manifest (prints SKIP)',
    1: 'stale critical cuts',
    2: 'usage, unreadable or empty manifest',
  },
  'audit-coverage.mjs': {
    0: 'coverage at or above the threshold (or --list)',
    1: 'below the threshold, or incomplete with --final',
    2: 'usage, missing results, or invalid agent reports',
    3: 'crash',
  },
  'audit-report.mjs': {
    0: 'rendered or updated',
    1: 'usage or invalid input (bad arguments, unreadable JSON, findings that cannot render)',
    3: 'crash, or the earlier run could not be archived (nothing changed)',
  },
  'audit-runbook.mjs': {
    0: 'runbook rendered',
    1: 'usage or invalid input (bad replay record, local host or path would leak)',
    3: 'crash',
  },
  'canary.mjs': {
    0: 'snapshot written (a page loaded), or compare found no regression',
    1: 'compare found a regression',
    2: 'could not measure: no playwright-core, no Chromium, or no page loaded',
    3: 'crash',
    64: 'usage: bad arguments, more than one host, snapshots of different hosts',
  },
  'composition-preview.mjs': {
    0: 'preview rendered (or --tokens printed)',
    2: 'no playwright-core or no browser',
    3: 'crash, or the composition has no section.html/section.css',
  },
  'contrast-propose.mjs': {
    0: 'proposals printed',
    2: 'usage or unusable colour input',
  },
  'css-contour-lint.mjs': {
    0: 'pass',
    1: 'findings',
    2: 'usage',
  },
  'decision-sheet.mjs': {
    0: 'ok',
    1: '--parse: no DECISION line parsed, or a line was dropped',
    2: 'usage, no browser, or an unsafe --date',
    3: 'page written but a card is incomplete',
  },
  'demo-verify.mjs': {
    0: 'clean (also --probe ok and --help)',
    1: 'blocking findings, a page crashed, no pages, or usage',
    2: 'no playwright-core or no browser',
    3: 'the walk crashed',
  },
  'h2-proxy.mjs': {
    0: 'stopped by SIGINT or SIGTERM',
    1: 'openssl missing and no --cert/--key',
    2: 'usage, or --target is not plain http',
  },
  'image-gen.mjs': {
    0: 'ok',
    2: 'usage, invalid plan, or the approved prompt changed',
    3: 'no API key (nothing written, nothing billed)',
    4: 'one or more slots failed, or crash',
  },
  'link-sweep.mjs': {
    0: 'sweep ran (findings are in the JSON; --help)',
    1: 'crash',
    2: 'usage',
    4: 'blocked by the host, --stop-on-block stopped it',
  },
  'section-diff.mjs': {
    0: 'every viewport within the pixel and size tolerances',
    1: 'a viewport over a tolerance',
    2: 'nothing measured: no playwright-core, pixelmatch, pngjs or Chrome, or a page failed',
    4: 'section not found on one side, or its selector matches more than one element',
    64: 'usage',
  },
  'style-diff.mjs': {
    0: 'no non-noise style diff',
    1: 'style diffs found (size diffs only with --fail-on-size)',
    2: 'usage or no browser',
    3: 'INCOMPLETE: no diff, but a page or viewport was unmeasured',
  },
  'tailwindify-parity.mjs': {
    0: 'clean (also --help and --list-breakpoints)',
    1: 'deltas found, or a page could not be rendered',
    2: 'no playwright-core or no browser',
    3: 'crash, or bad usage (missing --against, bad paths, nothing to compare)',
  },
  'theme-template-check.mjs': {
    0: 'pass',
    1: 'findings',
    2: 'usage',
  },
  'ux-probe.mjs': {
    0: 'ran (findings and unmeasured items are in the JSON)',
    1: 'crash',
    2: 'usage or no browser',
    3: 'budget spent (launches or wall clock)',
    130: 'SIGINT',
    143: 'SIGTERM',
  },
  // A library module that is also a CLI: commands read `exit 2 = no browser` from it.
  'lib/browsers.mjs': {
    0: 'browser found (path on stdout)',
    1: 'usage: engine is not chromium, firefox or webkit',
    2: 'no browser of that engine on the machine',
  },
  // The named exception: every command reads these through skills/wp-manifest-gate/SKILL.md.
  'wp-config.mjs': {
    0: 'ok',
    1: 'invalid or refused',
    2: 'a manifest migration is available',
    3: 'no manifest (or no profile)',
    4: 'drift, tool state not git-ignored, or secret-looking files',
    5: 'adopted site (require-origin): the builder must stop',
  },
};
