// @ts-check
// The bridge between this suite and /wp-audit.
//
// Everything else in this tree is vendored and answers to its own report. This file is the
// plugin's, and it exists so the suite does not become a second reporting pipeline running
// beside the first: it reads the same model the suite's own report is built from and emits
// the run file `bin/audit-report.mjs` consumes, so a browser measurement and a code finding
// land in one plan, one ledger and one dated document.
//
// Three translations happen here, and each one is a decision rather than a rename.
//
// 1. Criterion -> check id. The suite numbers criteria 1-58; the plugin's codes are
//    prefixed by category and are what the ledger's identity is built from. A bare `46`
//    would collide with every other numbering in the project the moment anything else
//    emits one, so a criterion becomes `UX-046`. Evidence rows are not criteria and do not
//    get a criterion's id: Lighthouse's 41.x rows become `PERF-LH-*` and axe's findings
//    become `A11Y-AXE-*`, because they are measurements of 41 and 45, not extra criteria,
//    and a ledger that stored them as criteria would report a different total every run.
//
// 2. Application -> ownership. The suite already splits a fix four ways and that split is
//    the reason this bridge is short. The words are translated, the classification is not
//    re-derived: two lists of which criterion is a setting would drift within a release.
//
// 3. Status -> severity. Only `fail` and `warn` cross over. A `pass` is not a finding, and
//    `manual` and `na` are not failures — `manual` goes to the run's `unmeasured` list,
//    which the report prints under its own heading precisely so nobody reads it as a pass.
//
// Usage: node scripts/to-run.js [--results <dir>] [--out <file>] [--config <file>]
//                               [--site <name>] [--date <YYYY-MM-DD>]

const fs = require('fs');
const path = require('path');

const { collect } = require('../lib/report-data');

const OWNERSHIP = {
  Codigo: 'code',
  Ajuste: 'setting',
  Contenido: 'content',
  Manual: 'manual',
};

const SEVERITY = { Alta: 'CRITICAL', Media: 'WARNING', Baja: 'INFO' };

// Which plugin category a criterion belongs to. The categories are the ones /wp-audit
// already groups by, so the suite's findings sit beside the agents' in the same table
// rather than in a seventh column nobody's report has a heading for.
const CATEGORY = [
  [/^a11y-/, 'a11y'],
  [/^41(\.|$)/, 'performance'],
  [/^(51|52|53|54|55|56|57|58)$/, 'seo'],
  [/^(23|46|47|48|49)$/, 'seo'],
  [/^(22|44|45|50)$/, 'a11y'],
  [/^(39|40)$/, 'performance'],
];

function categoryOf(criterion) {
  const c = String(criterion);
  for (const [pattern, name] of CATEGORY) if (pattern.test(c)) return name;
  return 'usability';
}

// A criterion id is padded so `UX-006` and `UX-046` sort the way a reader expects, and so
// a ledger written this release still matches one written next release.
function checkIdOf(criterion) {
  const c = String(criterion);
  if (/^a11y-/.test(c)) return `A11Y-AXE-${c.slice(5).toUpperCase()}`;
  if (/^41\./.test(c)) return `PERF-LH-${c.replace('.', '-')}`;
  if (/^\d+$/.test(c)) return `UX-${c.padStart(3, '0')}`;
  return `UX-${c.toUpperCase()}`;
}

function parseArgs(argv) {
  const opts = { results: 'results/audit', out: 'results/run.json', config: null, site: null, date: null };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    if (!flag.startsWith('--')) throw new Error(`unexpected argument: ${flag}`);
    const key = flag.slice(2);
    if (!(key in opts)) throw new Error(`unknown argument: ${flag}`);
    const value = argv[i + 1];
    if (value === undefined || value.startsWith('--')) throw new Error(`${flag} needs a value`);
    opts[key] = value;
    i += 1;
  }
  return opts;
}

function toFinding(row) {
  const criterion = String(row.c);
  const ownership = OWNERSHIP[row.como];
  if (!ownership) {
    // The suite's own classifier covers every criterion it can emit, so an unmapped
    // application means the two trees have drifted. Guessing `code` here would silently
    // turn a setting into something the commit is assumed to carry.
    throw new Error(
      `criterion ${criterion} has application ${JSON.stringify(row.como)}, which maps to no ownership -- `
      + 'templates/audit-suite/lib/plan.js and scripts/to-run.js have drifted',
    );
  }
  const severity = SEVERITY[row.sev];
  if (!severity) {
    // Same reasoning as the ownership lookup above, and the same refusal. Defaulting to
    // WARNING would quietly demote a renamed CRITICAL, and an indexability failure that
    // reads as a warning is one nobody puts at the top of the plan.
    throw new Error(
      `criterion ${criterion} has severity ${JSON.stringify(row.sev)}, which maps to none of `
      + `${Object.keys(SEVERITY).join(', ')} -- templates/audit-suite/lib/plan.js and scripts/to-run.js have drifted`,
    );
  }
  return {
    check: checkIdOf(criterion),
    // The page is the stable half of the identity: a criterion that fails on one page and
    // passes on another is two different facts, and merging them loses the one that fails.
    resource: `page:${row.page}`,
    // The flag the merge reads. Everything in this file loaded the page; an agent's finding
    // reasoned about the code and carries no such flag, and that difference is what decides
    // which of two findings for one resource survives.
    measured: true,
    severity,
    ownership,
    category: categoryOf(criterion),
    page: row.page,
    message: row.name ? `${row.name}${row.evidence ? ` — ${row.evidence}` : ''}` : String(row.evidence || criterion),
    fix: row.rec || '',
    evidence: row.evidence || '',
  };
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const resultsDir = path.resolve(opts.results);
  if (!fs.existsSync(resultsDir)) {
    console.error(`to-run: ${resultsDir} does not exist -- run the suite before converting it`);
    process.exit(2);
  }
  // The config belongs to the results, not to whoever is standing in a shell. Resolving it
  // against cwd worked only because the runner cd's into the suite first: run this by hand
  // from anywhere else and it either cannot find a config or silently loads an unrelated
  // one and labels these results with another site's name.
  const configPath = opts.config
    ? path.resolve(opts.config)
    : path.resolve(resultsDir, '..', '..', 'audit.config.js');
  if (!fs.existsSync(configPath)) {
    console.error(`to-run: ${configPath} does not exist -- pass --config if the suite lives elsewhere`);
    process.exit(1);
  }
  const audit = require(configPath);
  const model = collect(resultsDir, audit);

  const findings = model.plan.map(toFinding);

  // `manual` is the suite saying a criterion applies and it could not decide it. That is
  // not a pass and it is not a failure, and the run file has a place for exactly that.
  const unmeasured = model.pendientes.map((row) => ({
    check: checkIdOf(row.c),
    reason: `${row.name || ''} — ${[...(row.evidencias || [])].filter(Boolean).join('; ') || 'needs human judgement or an external tool'}`.trim(),
    pages: row.paginas,
  }));

  const run = {
    site: opts.site || audit.siteName || 'site',
    date: opts.date || new Date().toISOString().slice(0, 10),
    tier: 'Code + Runtime + Suite',  // one of the four labels /wp-audit Step 3 prints
    categories: [...new Set(findings.map((f) => f.category))].sort(),
    source: 'audit-suite',
    findings,
    unmeasured,
  };

  fs.mkdirSync(path.dirname(path.resolve(opts.out)), { recursive: true });
  fs.writeFileSync(path.resolve(opts.out), `${JSON.stringify(run, null, 2)}\n`);
  console.log(`to-run: wrote ${opts.out} (${findings.length} findings, ${unmeasured.length} unmeasured)`);
}

if (require.main === module) {
  try {
    main();
  } catch (error) {
    console.error(`to-run: ${error.message}`);
    process.exit(1);
  }
}

module.exports = { checkIdOf, categoryOf, toFinding, OWNERSHIP, SEVERITY };
