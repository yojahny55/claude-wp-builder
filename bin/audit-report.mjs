#!/usr/bin/env node
// Render an audit run into a dated deliverable: Markdown to work with, and one
// self-contained HTML file to send.
//
// /wp-audit printed its findings to the console and wrote `.wp-audit-findings.json`.
// Neither is a deliverable. A console report is gone when the scrollback is, and a ledger
// is a working file — nobody sends a client a JSON array of check ids. So the work was
// done, reported to whoever ran it, and left with nothing to hand over.
//
// Two rules are enforced here rather than left to prose, because both are the kind of
// thing a report quietly ships without:
//
//   1. Every finding names who applies it. `code` travels with the commit; `setting` is a
//      database or server change that does NOT, and has to be repeated wherever the site
//      is deployed; `content` needs a person to write or decide a text; `manual` needs
//      human judgment or an external tool. A report that does not separate these reads as
//      a list of things "the audit will fix", and the settings silently stay in local.
//   2. A report is dated, and a dated report is comparable. Each run writes a machine
//      sidecar beside the documents so the next one can diff against it without parsing
//      its own Markdown back.
//
// Usage:
//   bin/audit-report.mjs --run <run.json> [--agents <dir|file>...] [--merge <other.json>...]
//                        [--out <dir>] [--format md|html|both] [--lang en|es]
//                        [--date YYYY-MM-DD] [--notes <file>] [--site-root <dir>]
//
// --agents builds the findings straight from the agents' report files (a directory of
// *.json, or one file) instead of a run file somebody had to assemble by hand; --run may then
// carry only the metadata (site, date, tier, categories, notes) or be omitted. Every finding,
// from either source, goes through the normalizer in bin/lib/audit-schema.mjs: known key
// aliases are accepted (`code` for `check`, `owner` for `ownership`, ...). A finding in an
// agent report that has no id, an id outside the agents' catalogs, or that is also reported
// as a pass is refused. (Findings in --run come from the aggregator or the browser suite,
// whose ids are not the agents', so they are normalized but not held to the catalogs.)
//
// --lang defaults to the manifest's `languages.primary` when it is es or en, else en.
// The manifest is ./.wp-create.json, or <--site-root>/.wp-create.json.
//
//   bin/audit-report.mjs --accept <id,...> --reason "<why>"   [--ledger <file>] [--out <dir>]
//   bin/audit-report.mjs --unaccept <id,...>
//   bin/audit-report.mjs --mark-fixed <id,...> --evidence "<what was done>"
//   bin/audit-report.mjs --rerender [--format ...] [--lang ...] [--notes <file>]
//   bin/audit-report.mjs --summary [--json]
//
// The last five record a decision or read the state WITHOUT auditing. An <id> is a finding's
// identity as the ledger spells it, `check:resource` (or just `check` when it has no
// resource); a bare `check` selects every ledger entry of that check. Pass several ids
// comma-separated or by repeating the flag. They combine: `--mark-fixed ... --rerender
// --summary` records, rebuilds the report, then prints the counts.
//
//   --accept / --unaccept   a human decision, the only way an entry becomes `accepted`: the
//                           audit stops re-raising it and the report lists it apart from the
//                           plan. --unaccept puts it back to the status it had.
//   --mark-fixed            fixes applied since the last run. The entry becomes
//                           `fixed_unverified`: reported, never `resolved` -- only a re-run
//                           that measures the check can say that.
//   --rerender              rebuilds the .md/.html of the NEWEST sidecar from that sidecar
//                           plus the ledger. No check runs, so nothing becomes resolved.
//   --summary [--json]      counts by status and by severity, from the ledger (or from the
//                           newest sidecar when there is no ledger). Quote these, not memory.
//
// The ledger is `--ledger <file>`, else the manifest's `audit.findings_ledger.path`, else
// `.wp-audit-findings.json`, both read from the site root (--site-root, default the current
// directory).
//
// The output directory is, in order: --out, the WP_AUDIT_OUT_DIR environment variable, the
// manifest's `audit.out_dir`, `<audits root>/<site>/results` when an audits root is set (the
// WP_AUDITS_ROOT environment variable or the manifest's `audit.audits_root`), then
// `.wp-audit`. With no audits root configured nothing changes. The renderer
// diffs against the newest sidecar IN THAT DIRECTORY, so changing the directory between runs
// starts a new baseline. Every written file is printed as an absolute path, and a directory
// inside a git work tree that is not ignored gets a one-line warning.
//
// --notes reads a plain-text file whose paragraphs (separated by a blank line) become the
// "Scope and coverage" section, after any `notes` the run file itself carries. It is for what
// the findings cannot say: what was audited and against which environment, what was left out
// and why, which numbers come from a local clone rather than the live site.
//
// --merge folds another run file into this one. One audit produces two sources of findings
// -- the agents, and the browser suite -- and rendering them separately would split one
// audit across two documents and two baselines. Where both describe the same check and the
// same resource, the MEASURED one wins: the suite loaded the page, the agent reasoned about
// the code. The losing finding is noted in the winner's evidence and that evidence is kept
// in the dated sidecar, so a later reader can see that two sources reported it.
//
// Exit codes (house convention):
//   0  documents written — including for a run with no findings, which is a clean report
//   1  invalid input — the run file is missing, unparseable, or a finding is incomplete
//   3  crash

import { readFileSync, writeFileSync, mkdirSync, readdirSync, existsSync, renameSync, statSync } from 'node:fs';
import { join, resolve, basename, isAbsolute } from 'node:path';
import { spawnSync } from 'node:child_process';
import { normalizeEntry, normalizeReport, loadReports } from './lib/audit-schema.mjs';

const OWNERSHIP = ['code', 'setting', 'content', 'manual'];
const SEVERITY_ORDER = { CRITICAL: 0, WARNING: 1, INFO: 2 };

const STRINGS = {
  en: {
    title: 'Web audit',
    scope: 'Scope and coverage',
    date: 'Date',
    tier: 'Tier',
    categories: 'Categories',
    summary: 'Summary',
    comparison: 'Compared with the previous audit',
    noPrevious:
      'No previous audit found. This report is the baseline every later run is measured against.',
    noFindings: 'No issues found in the categories audited.',
    noFindingsUnmeasured:
      'No issues found in the checks that ran. Some checks did not run — see Not measured below.',
    previousRun: 'Previous run',
    previousUnmeasured:
      ' — that run left %unmeasured% check(s) unmeasured, so what is "new" below may be what it never looked at',
    scoreLine: 'Findings: %total% (%critical% critical, %warning% warnings, %info% info)',
    improved: 'Resolved since the previous run',
    regressed: 'New since the previous run',
    carried: 'Still failing',
    notRemeasured: 'Not re-measured in this run (not counted as resolved)',
    byCategory: 'By category',
    byPage: 'By page',
    category: 'Category',
    page: 'Page',
    plan: 'Remediation plan',
    priority: 'Priority',
    code: 'Check',
    problem: 'Problem',
    todo: 'What to do',
    applied: 'How it is applied',
    ownershipCounts: 'Split: %code% in code, %setting% in settings, %content% content, %manual% manual',
    settingWarning:
      'A `setting` is a database or server change. Applied on a local clone it does **not** travel with the commit — repeat it on staging and production, where there is no WP-CLI.',
    otherSeverity: ' — %other% with an unrecognised severity, from an older report',
    unmeasured: 'Not measured',
    tier3Unmeasured:
      'Tier 3 (browser measurement) was NOT measured in this run — nothing here comes from a loaded page, so do not read the absence of Tier 3 findings as a pass.',
    unmeasuredNote:
      'These checks apply to this site and did not run. They are not passes — say what stopped them before treating this report as complete.',
    none: 'None',
    ownership: { code: 'Code', setting: 'Setting', content: 'Content', manual: 'Manual' },
    designImpact: 'Visual change',
    severity: { CRITICAL: 'High', WARNING: 'Medium', INFO: 'Low' },
    decisionsLine: 'Set aside, not counted above: %accepted% accepted by a human, %fixed% fixed and awaiting a measured re-run',
    noOpen: 'No open issues. What remains is accepted by a human or fixed and awaiting a measured re-run — see below.',
    accepted: 'Accepted by a human',
    acceptedNote: 'A person decided these stay as they are. They are not in the plan or in the counts above, and a later audit does not re-raise them.',
    fixedUnverified: 'Fixed, awaiting a measured re-run',
    fixedNote: 'A person reports these as fixed. No check has re-run since, so they are neither open nor resolved: only a run that measures them can resolve them, and one that still finds them returns them to still failing.',
    reason: 'Reason',
    evidenceCol: 'Evidence',
    decidedOn: 'Date',
    rerendered: 'Re-rendered on %today% from the audit of %date% and the ledger decisions recorded since. No check was run again, so nothing here is newly resolved.',
  },
  es: {
    scope: 'Alcance y cobertura',
    title: 'Auditoría web',
    date: 'Fecha',
    tier: 'Nivel',
    categories: 'Categorías',
    summary: 'Resumen',
    comparison: 'Comparativa con la auditoría anterior',
    noPrevious:
      'No hay auditoría anterior. Este informe es la línea base contra la que se mide cada ejecución posterior.',
    noFindings: 'No se encontraron incidencias en las categorías auditadas.',
    noFindingsUnmeasured:
      'No se encontraron incidencias en los criterios que se ejecutaron. Algunos no se ejecutaron: ver Sin medir más abajo.',
    previousRun: 'Ejecución anterior',
    previousUnmeasured:
      ' — esa ejecución dejó %unmeasured% criterio(s) sin medir, así que lo que aquí figura como nuevo puede ser lo que entonces no se miró',
    scoreLine: 'Hallazgos: %total% (%critical% críticos, %warning% advertencias, %info% informativos)',
    improved: 'Resueltos desde la ejecución anterior',
    regressed: 'Nuevos desde la ejecución anterior',
    carried: 'Siguen fallando',
    notRemeasured: 'Sin volver a medir en esta ejecución (no cuentan como resueltos)',
    byCategory: 'Por categoría',
    byPage: 'Por página',
    category: 'Categoría',
    page: 'Página',
    plan: 'Plan de corrección',
    priority: 'Prioridad',
    code: 'Criterio',
    problem: 'Problema',
    todo: 'Qué hacer',
    applied: 'Cómo se aplica',
    ownershipCounts: 'Reparto: %code% en código, %setting% en ajustes, %content% de contenido, %manual% manuales',
    settingWarning:
      'Un `ajuste` es un cambio de base de datos o de servidor. Aplicado sobre un clon local **no** viaja con el commit: hay que repetirlo en staging y en producción, donde no hay WP-CLI.',
    otherSeverity: ' — %other% con severidad no reconocida, de un informe anterior',
    unmeasured: 'Sin medir',
    tier3Unmeasured:
      'El Nivel 3 (medición en navegador) NO se midió en esta ejecución — nada de lo que aparece sale de una página cargada, así que la ausencia de hallazgos de Nivel 3 no significa que pase.',
    unmeasuredNote:
      'Estos criterios aplican a este sitio y no se ejecutaron. No son aprobados: di qué lo impidió antes de dar el informe por completo.',
    none: 'Ninguno',
    ownership: { code: 'Código', setting: 'Ajuste', content: 'Contenido', manual: 'Manual' },
    designImpact: 'Cambio visual',
    severity: { CRITICAL: 'Alta', WARNING: 'Media', INFO: 'Baja' },
    decisionsLine: 'Apartados, no contados arriba: %accepted% aceptados por una persona, %fixed% corregidos a la espera de una nueva medición',
    noOpen: 'No hay incidencias abiertas. Lo que queda está aceptado por una persona o corregido a la espera de una nueva medición: ver más abajo.',
    accepted: 'Aceptados por una persona',
    acceptedNote: 'Una persona decidió que se quedan como están. No figuran en el plan ni en los recuentos de arriba, y una auditoría posterior no los vuelve a plantear.',
    fixedUnverified: 'Corregidos, a la espera de una nueva medición',
    fixedNote: 'Una persona indica que están corregidos. Ningún criterio se ha vuelto a medir, así que no están abiertos ni resueltos: solo una ejecución que los mida puede resolverlos, y si la ejecución los sigue encontrando vuelven a seguir fallando.',
    reason: 'Motivo',
    evidenceCol: 'Evidencia',
    decidedOn: 'Fecha',
    rerendered: 'Regenerado el %today% a partir de la auditoría del %date% y de las decisiones del registro posteriores. No se volvió a medir ningún criterio, así que nada de lo que aparece está resuelto de nuevo.',
  },
};

function die(code, message) {
  console.error(message);
  process.exit(code);
}

const DECISION_FLAGS = { '--accept': 'accept', '--unaccept': 'unaccept', '--mark-fixed': 'markFixed' };

function parseArgs(argv) {
  const opts = {
    out: null, format: 'both', lang: null, run: null, date: null, merge: [], agents: [], siteRoot: '.', ledger: null,
    accept: [], unaccept: [], markFixed: [], reason: null, evidence: null,
    rerender: false, summary: false, json: false,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    const value = argv[i + 1];
    switch (flag) {
      case '--rerender':
      case '--summary':
      case '--json':
        opts[flag.slice(2)] = true;
        break;
      case '--merge': {
        if (value === undefined || value.startsWith('--')) die(1, `${flag} needs a value`);
        opts.merge.push(value);
        i += 1;
        break;
      }
      case '--agents': {
        if (value === undefined || value.startsWith('--')) die(1, `${flag} needs a value`);
        opts.agents.push(value);
        i += 1;
        break;
      }
      case '--site-root': {
        if (value === undefined || value.startsWith('--')) die(1, `${flag} needs a value`);
        opts.siteRoot = value;
        i += 1;
        break;
      }
      case '--accept':
      case '--unaccept':
      case '--mark-fixed': {
        if (value === undefined || value.startsWith('--')) die(1, `${flag} needs a value`);
        // Comma-separated, or the flag repeated. A resource can hold spaces but not a comma
        // in any identity the ledger spells, so a comma is the separator.
        opts[DECISION_FLAGS[flag]].push(...value.split(',').map((id) => id.trim()).filter(Boolean));
        i += 1;
        break;
      }
      case '--run':
      case '--out':
      case '--format':
      case '--lang':
      case '--notes':
      case '--ledger':
      case '--reason':
      case '--evidence':
      case '--date': {
        if (value === undefined || value.startsWith('--')) {
          die(1, `${flag} needs a value`);
        }
        opts[flag.slice(2)] = value;
        i += 1;
        break;
      }
      default:
        die(1, `unknown argument: ${flag}`);
    }
  }
  const rendering = Boolean(opts.run) || opts.agents.length > 0;
  const deciding = opts.accept.length + opts.unaccept.length + opts.markFixed.length > 0;
  if (!rendering && !deciding && !opts.rerender && !opts.summary) {
    die(1, '--run <run.json> or --agents <dir|file> is required (or --accept, --unaccept, --mark-fixed, --rerender, --summary)');
  }
  if (rendering && (deciding || opts.rerender || opts.summary)) {
    die(1, '--run and --agents render a new audit; it cannot be combined with --accept, --unaccept, --mark-fixed, --rerender or --summary');
  }
  if (opts.merge.length && !rendering) die(1, '--merge needs --run or --agents');
  if (opts.json && !opts.summary) die(1, '--json only applies to --summary');
  if (opts.accept.length && !(opts.reason && opts.reason.trim())) {
    die(1, '--accept needs --reason "<why it stays>": a decision with no reason is the one nobody can review later');
  }
  if (opts.markFixed.length && !(opts.evidence && opts.evidence.trim())) {
    die(1, '--mark-fixed needs --evidence "<what was changed>"');
  }
  if (opts.reason && !opts.accept.length) die(1, '--reason only applies to --accept');
  if (opts.evidence && !opts.markFixed.length) die(1, '--evidence only applies to --mark-fixed');
  if (!['md', 'html', 'both'].includes(opts.format)) {
    die(1, `--format must be md, html or both (got: ${opts.format})`);
  }
  if (opts.lang === null) opts.lang = defaultLang(opts.siteRoot);
  if (!STRINGS[opts.lang]) {
    die(1, `--lang must be one of ${Object.keys(STRINGS).join(', ')} (got: ${opts.lang})`);
  }
  if (opts.format !== 'md' && !HTML_UI[opts.lang]) {
    die(1, `--lang ${opts.lang} has no HTML strings — add it to HTML_UI as well as STRINGS`);
  }
  if (opts.date && !/^\d{4}-\d{2}-\d{2}$/.test(opts.date)) {
    die(1, `--date must be YYYY-MM-DD (got: ${opts.date})`);
  }
  return opts;
}

function readManifest(siteRoot) {
  try {
    return JSON.parse(readFileSync(join(siteRoot, '.wp-create.json'), 'utf8'));
  } catch { return null; /* no manifest, or unreadable: every default below still works */ }
}

// The report is read by a client, so it follows the site's primary language, not the
// plugin's. Only languages the renderer has strings for count; anything else is English.
function defaultLang(siteRoot) {
  const primary = readManifest(siteRoot)?.languages?.primary;
  const code = typeof primary === 'string' ? primary.trim().toLowerCase().split(/[-_]/)[0] : '';
  return STRINGS[code] && HTML_UI[code] ? code : 'en';
}

const slugify = (value) => String(value ?? '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');

// --out > WP_AUDIT_OUT_DIR > audit.out_dir > <audits root>/<site>/results > .wp-audit
// The audits root (WP_AUDITS_ROOT, or audit.audits_root in the manifest) is where an operator
// keeps every site's reports side by side; with none set, the old default is unchanged.
function resolveOutDir(flag, siteRoot, run) {
  if (flag) return flag;
  if (process.env.WP_AUDIT_OUT_DIR) return process.env.WP_AUDIT_OUT_DIR;
  const manifest = readManifest(siteRoot);
  const dir = manifest?.audit?.out_dir;
  if (typeof dir === 'string' && dir !== '') return dir;
  const root = process.env.WP_AUDITS_ROOT || manifest?.audit?.audits_root;
  if (typeof root === 'string' && root !== '') {
    // The site root's folder name is the last candidate so that the commands that run without
    // a run file (--accept, --rerender, --summary) still find the folder a render wrote.
    const site = slugify(manifest?.project?.slug || manifest?.project?.name || run?.site || run?.project || basename(resolve(siteRoot)));
    if (site) return join(root, site, 'results');
  }
  return '.wp-audit';
}

// One line, never fatal: a report inside a work tree that nothing ignores gets committed.
function warnIfUnignored(outDir) {
  const git = (args) => spawnSync('git', ['-C', outDir, ...args], { encoding: 'utf8' });
  const inside = git(['rev-parse', '--is-inside-work-tree']);
  if (inside.error || inside.status === null) {
    console.warn(`audit-report: cannot check whether ${outDir} is ignored because git is unavailable: ${inside.error?.message ?? 'git did not exit'}`);
    return;
  }
  if (inside.status !== 0) return;
  const ignored = git(['check-ignore', '-q', '--', 'probe']);
  if (ignored.error || ignored.status === null) {
    console.warn(`audit-report: cannot check whether ${outDir} is ignored because git is unavailable: ${ignored.error?.message ?? 'git did not exit'}`);
    return;
  }
  if (ignored.status === 0) return;
  console.warn(`audit-report: ${outDir} is inside a git work tree and is not ignored -- add it to .gitignore, or run node bin/wp-config.mjs gitignore-check <site-root>`);
}

function loadRun(path, { findingsOptional = false } = {}) {
  let raw;
  try {
    raw = readFileSync(path, 'utf8');
  } catch (error) {
    die(1, `cannot read ${path}: ${error.message}`);
  }
  let run;
  try {
    run = JSON.parse(raw);
  } catch (error) {
    die(1, `${path} is not valid JSON: ${error.message}`);
  }
  // With --agents the findings come from the agents' reports and the run file is metadata.
  if (findingsOptional && run.findings === undefined) run.findings = [];
  if (!Array.isArray(run.findings)) {
    die(1, `${path} has no "findings" array`);
  }
  // The date becomes three file names under --out. `--date` was validated and this was not,
  // so a run file carrying `x/../../evil` wrote outside the output directory entirely --
  // `path.join` only cancels a `..` that lands on its own segment, and one slash is enough
  // to give it that. The run file is an argument like any other: it is not trusted.
  if (run.date !== undefined && !/^\d{4}-\d{2}-\d{2}$/.test(String(run.date))) {
    die(1, `${path} has an invalid "date": ${JSON.stringify(run.date)} -- expected YYYY-MM-DD`);
  }
  return run;
}

// A finding without an owner is the failure this whole file exists to stop, so it is
// refused here rather than rendered as an empty cell. The same goes for a check id and a
// message: a row a reader cannot act on is worse than a row that is missing, because it
// takes up space in a plan and looks like work that is accounted for.
// Several checks can trip over one defect: a notice printed before the document surfaces in
// security, both SEO files, the GEO head and performance, and counting it five times inflates
// every total. Findings that share a `root_cause` fold into the most severe one (the first on
// a tie), which lists the others under `also_affects`. Findings with no root_cause pass through.
function foldRootCauses(findings) {
  const parents = new Map();
  const out = [];
  for (const finding of findings) {
    const key = typeof finding.root_cause === 'string' ? finding.root_cause.trim() : '';
    if (!key) { out.push(finding); continue; }
    const held = parents.get(key);
    if (!held) {
      const parent = { ...finding, also_affects: [...(finding.also_affects || [])] };
      parents.set(key, parent);
      out.push(parent);
    } else if ((SEVERITY_ORDER[finding.severity] ?? 99) < (SEVERITY_ORDER[held.severity] ?? 99)) {
      // A more severe sibling becomes the parent; the old parent folds under it.
      const parent = { ...finding, also_affects: [...(finding.also_affects || []), ...held.also_affects, { check: held.check, resource: held.resource || null }] };
      parents.set(key, parent);
      out[out.indexOf(held)] = parent;
    } else {
      held.also_affects.push({ check: finding.check, resource: finding.resource || null });
    }
  }
  return out;
}

const alsoText = (finding) => (finding.also_affects && finding.also_affects.length
  ? ` (same cause: ${finding.also_affects.map((a) => (a.resource ? `${a.check} ${a.resource}` : a.check)).join(', ')})`
  : '');

function validate(findings) {
  const problems = [];
  findings.forEach((finding, index) => {
    const where = typeof finding.check === 'string' && finding.check ? finding.check : `findings[${index}]`;
    if (!finding.check) problems.push(`findings[${index}] has no "check" id`);
    else if (typeof finding.check !== 'string') {
      // Truthiness is not enough. A JSON number passes `!finding.check`, reaches the plan
      // comparator, and throws on `.localeCompare` -- turning invalid input, which exits 1
      // and names the finding, into a crash that exits 3 and names a line of this file.
      problems.push(`findings[${index}] has a non-string "check" id: ${JSON.stringify(finding.check)}`);
    }
    if (!finding.message) problems.push(`${where} has no "message"`);
    if (!finding.severity) problems.push(`${where} has no "severity"`);
    else if (!(finding.severity in SEVERITY_ORDER)) {
      problems.push(`${where} has severity "${finding.severity}" — expected one of ${Object.keys(SEVERITY_ORDER).join(', ')}`);
    }
    if (!finding.ownership) {
      problems.push(`${where} has no "ownership" — every finding says who applies it (${OWNERSHIP.join(', ')})`);
    } else if (!OWNERSHIP.includes(finding.ownership)) {
      problems.push(`${where} has ownership "${finding.ownership}" — expected one of ${OWNERSHIP.join(', ')}`);
    }
  });
  return problems;
}

// `unmeasured` is rendered under its own heading in the document a client reads, so an
// entry with no check id prints a literal `undefined` there. It is refused for the same
// reason an unowned finding is: the section exists to be trustworthy.
function validateUnmeasured(entries) {
  const problems = [];
  entries.forEach((entry, index) => {
    if (!entry || typeof entry !== 'object') {
      problems.push(`unmeasured[${index}] is not an object`);
      return;
    }
    if (typeof entry.check !== 'string' || !entry.check) {
      problems.push(`unmeasured[${index}] has no "check" id -- it would render as "undefined" in the report`);
    }
  });
  return problems;
}

// Free text for the "Scope and coverage" section. A run file carries it as `notes`: one string
// or an array of strings, each a paragraph (a paragraph whose lines all start with "- " is
// rendered as a list). The HTML report escapes it like any other cell. The Markdown report
// keeps it as written: the auditor writes these notes, and a path in backticks or a link
// should render in the .md the way it was typed.
function normalizeNotes(value, where) {
  if (value === undefined || value === null) return [];
  const list = Array.isArray(value) ? value : [value];
  list.forEach((item, index) => {
    if (typeof item !== 'string') {
      die(1, `${where} "notes"[${index}] is not a string -- notes are plain-text paragraphs`);
    }
  });
  return list.map((item) => item.trim()).filter(Boolean);
}

function readNotesFile(path) {
  let raw;
  try {
    raw = readFileSync(path, 'utf8');
  } catch (error) {
    die(1, `cannot read ${path}: ${error.message}`);
  }
  return raw.split(/\n\s*\n/).map((part) => part.trim()).filter(Boolean);
}

// A paragraph is a list when every line is a "- " bullet, otherwise running text.
function noteBlock(note) {
  const lines = note.split('\n').map((line) => line.trim()).filter(Boolean);
  if (lines.length && lines.every((line) => line.startsWith('- '))) {
    return { list: lines.map((line) => line.slice(2).trim()) };
  }
  return { text: lines.join(' ') };
}

function identity(finding) {
  return finding.resource ? `${finding.check}:${finding.resource}` : finding.check;
}

// A measurement beats an inference. Both describe the same defect only when they agree on
// the check AND the resource; a contrast failure measured on /contact and one found in a
// stylesheet rule no audited page uses are two real findings, and the second is the one
// nobody would find again.
function mergeRuns(base, extras) {
  // Swapped arguments, or a stale suite run left over from a previous audit, produced a
  // report labelled with whatever --run pointed at and no sign the inputs disagreed.
  for (const extra of extras) {
    for (const field of ['site', 'date']) {
      if (extra[field] && base[field] && extra[field] !== base[field]) {
        console.error(
          `audit-report: warning: merging a run whose ${field} is ${JSON.stringify(extra[field])} `
          + `into one whose ${field} is ${JSON.stringify(base[field])} -- the report keeps the latter`,
        );
      }
    }
  }

  const byIdentity = new Map(base.findings.map((finding) => [identity(finding), finding]));
  const merged = [...base.findings];
  const unmeasured = [...(Array.isArray(base.unmeasured) ? base.unmeasured : [])];
  const seenUnmeasured = new Set(unmeasured.map((entry) => entry.check));
  let superseded = 0;

  for (const extra of extras) {
    for (const finding of extra.findings) {
      if (!finding.source && extra.source) finding.source = extra.source;
      const key = identity(finding);
      const existing = byIdentity.get(key);
      if (!existing) {
        byIdentity.set(key, finding);
        merged.push(finding);
        continue;
      }
      // `measured` is set by whatever produced the run file. The suite sets it; an agent's
      // findings do not carry it, which is the whole distinction.
      const winner = finding.measured && !existing.measured ? finding : existing;
      const loser = winner === finding ? existing : finding;
      // Name the source, not the check: a collision means both carried the SAME check and
      // the same resource, so repeating the check id says nothing the row does not show.
      // Repeated merges must not repeat the note either.
      const note = `superseded ${loser.measured ? 'a measured' : 'an inferred'} finding from ${loser.source || 'another run'}`;
      if (!String(winner.evidence || '').includes(note)) {
        winner.evidence = [winner.evidence, note].filter(Boolean).join(' — ');
      }
      if (winner !== existing) {
        merged[merged.indexOf(existing)] = winner;
        byIdentity.set(key, winner);
      }
      superseded += 1;
    }
    for (const entry of Array.isArray(extra.unmeasured) ? extra.unmeasured : []) {
      if (seenUnmeasured.has(entry.check)) continue;
      seenUnmeasured.add(entry.check);
      unmeasured.push(entry);
    }
  }

  if (superseded) console.log(`audit-report: ${superseded} finding(s) reported by two sources, kept once`);
  const notes = [
    ...normalizeNotes(base.notes, 'the run file'),
    ...extras.flatMap((extra) => normalizeNotes(extra.notes, 'a merged run file')),
  ];
  return { ...base, findings: merged, unmeasured, notes };
}

// A sidecar is `informe-<date>.json`, or `informe-<date>-<HHMM[SS][-N]>.json` once a later
// run on the same day has archived it. Within one date the unsuffixed file is always the
// newest: archiving only ever happens to make room for it.
const SIDECAR = /^informe-(\d{4}-\d{2}-\d{2})(?:-(\d{4}(?:\d{2})?(?:-\d+)?))?\.json$/;

function sidecarOrder(name) {
  const [, date, time] = SIDECAR.exec(name);
  return `${date} ${time ? time.padEnd(6, '0') : '999999'}`;
}

// A second run on the same day used to overwrite the first run's documents and sidecar, and
// the first run's sidecar was the only thing the second could compare against: the report
// said "No previous audit found" and the earlier snapshot was gone. The earlier set is moved
// aside under the time it was written, so it stays readable and becomes the previous run.
function archiveSameDay(outDir, date) {
  const sidecar = join(outDir, `informe-${date}.json`);
  if (!existsSync(sidecar)) return;
  const at = statSync(sidecar).mtime;
  const pad = (n) => String(n).padStart(2, '0');
  let stamp = `${pad(at.getHours())}${pad(at.getMinutes())}`;
  if (existsSync(join(outDir, `informe-${date}-${stamp}.json`))) stamp += pad(at.getSeconds());
  let candidate = stamp;
  let n = 1;
  while (existsSync(join(outDir, `informe-${date}-${candidate}.json`))) {
    candidate = `${stamp}-${n++}`;
  }
  stamp = candidate;
  for (const ext of ['json', 'md', 'html']) {
    const from = join(outDir, `informe-${date}.${ext}`);
    if (existsSync(from)) renameSync(from, join(outDir, `informe-${date}-${stamp}.${ext}`));
  }
  console.log(`audit-report: earlier run of ${date} kept as informe-${date}-${stamp}.*`);
}

// The previous run is the newest sidecar in the output directory that is not this run's
// own. Markdown is never parsed back: a report rewritten by hand would then change what
// the next comparison claims happened.
function findPrevious(outDir, selfPath) {
  if (!existsSync(outDir)) return null;
  const sidecars = readdirSync(outDir)
    .filter((name) => SIDECAR.test(name))
    .sort((a, b) => sidecarOrder(a).localeCompare(sidecarOrder(b)))
    .map((name) => join(outDir, name))
    .filter((path) => resolve(path) !== resolve(selfPath));
  if (sidecars.length === 0) return null;
  const path = sidecars[sidecars.length - 1];
  try {
    const previous = JSON.parse(readFileSync(path, 'utf8'));
    if (!Array.isArray(previous.findings)) {
      console.error(`audit-report: ${path} holds no findings array -- treating this run as a baseline`);
      return null;
    }
    return { path, ...previous };
  } catch (error) {
    console.error(`audit-report: ${path} could not be read (${error.message}) -- treating this run as a baseline`);
    return null;
  }
}

// ---------------------------------------------------------------------------------------
// The ledger: the project's running record of every finding. The audit writes it (Step 7.5);
// the commands below are how a HUMAN decision gets in without an audit. Shape:
//   { "ledger_version": 1, "findings": [ { "check", "resource", "status", "severity",
//     "first_seen", "last_seen", "evidence" } ] }
// `findings` is an ARRAY of objects, not an object keyed by identity.
// ---------------------------------------------------------------------------------------
const LEDGER_STATUSES = ['new', 'still_failing', 'resolved', 'accepted', 'fixed_unverified', 'unmeasured'];
// Entries a re-audit still has to measure, and the ones a plan can still be made of.
const OPEN_STATUSES = ['new', 'still_failing', 'unmeasured'];
const LEDGER_SHAPE = '{"ledger_version":1,"findings":[{"check":"SEC-036","resource":"wp_options.siteurl","status":"still_failing","severity":"CRITICAL","first_seen":"<ISO>","last_seen":"<ISO>","evidence":"<command>"}]}';

const nowIso = () => new Date().toISOString().replace(/\.\d+Z$/, 'Z');

// Read from the same manifest as the output directory (--site-root), so a decision recorded
// from another directory lands in that site's ledger. A relative pointer is relative to it.
function resolveLedgerPath(flag, siteRoot = '.') {
  if (flag) return flag;
  const pointer = readManifest(siteRoot)?.audit?.findings_ledger;
  const path = typeof pointer === 'string' ? pointer : pointer?.path;
  if (typeof path === 'string' && path !== '') return isAbsolute(path) ? path : join(siteRoot, path);
  return join(siteRoot, '.wp-audit-findings.json');
}

// A ledger that is not this shape is refused with the shape, because the failure otherwise
// shows up in whatever reads it next (a one-off script indexing a string as an object).
function loadLedger(path, { required }) {
  if (!existsSync(path)) {
    if (required) die(1, `no ledger at ${path} -- pass --ledger <file>, or run an audit first`);
    return { path, data: { ledger_version: 1, findings: [] }, exists: false };
  }
  let data;
  try {
    data = JSON.parse(readFileSync(path, 'utf8'));
  } catch (error) {
    die(1, `${path} is not valid JSON: ${error.message}`);
  }
  if (!data || typeof data !== 'object' || !Array.isArray(data.findings)) {
    die(1, `${path} is not a findings ledger: expected ${LEDGER_SHAPE}`);
  }
  data.findings.forEach((entry, index) => {
    if (!entry || typeof entry !== 'object' || typeof entry.check !== 'string' || !entry.check) {
      die(1, `${path} findings[${index}] is not an entry with a string "check": expected ${LEDGER_SHAPE}`);
    }
  });
  return { path, data, exists: true };
}

function saveLedger(ledger) {
  const tmp = `${ledger.path}.tmp-${process.pid}`;
  writeFileSync(tmp, `${JSON.stringify(ledger.data, null, 2)}\n`);
  renameSync(tmp, ledger.path);
}

function newestSidecar(outDir) {
  if (!existsSync(outDir)) return null;
  const names = readdirSync(outDir)
    .filter((name) => SIDECAR.test(name))
    .sort((a, b) => sidecarOrder(a).localeCompare(sidecarOrder(b)));
  if (!names.length) return null;
  const path = join(outDir, names[names.length - 1]);
  let data;
  try {
    data = JSON.parse(readFileSync(path, 'utf8'));
  } catch (error) {
    die(1, `${path} is not valid JSON: ${error.message}`);
  }
  if (!Array.isArray(data.findings)) die(1, `${path} has no "findings" array`);
  return { path, data };
}

// `--accept SEC-036` selects every entry of the check; `SEC-036:wp_options.siteurl` one.
// Every token is resolved before anything is written, so a typo changes nothing. A token
// the ledger lacks may still name a finding of the newest sidecar (an audit run with
// --report only, say), which is then added to the ledger as it stood.
function selectEntries(ledger, tokens, outDir) {
  const picked = [];
  const missing = [];
  let sidecar;
  for (const token of tokens) {
    let matches = ledger.data.findings.filter((entry) => identity(entry) === token);
    if (!matches.length) matches = ledger.data.findings.filter((entry) => entry.check === token);
    if (!matches.length) {
      if (sidecar === undefined) sidecar = newestSidecar(outDir);
      const found = sidecar ? sidecar.data.findings.filter((f) => !f.not_remeasured && (identity(f) === token || f.check === token)) : [];
      matches = found.map((f) => {
        const entry = {
          check: f.check, resource: f.resource || null, status: 'still_failing', severity: f.severity,
          first_seen: nowIso(), last_seen: nowIso(), evidence: f.evidence || null,
        };
        ledger.data.findings.push(entry);
        return entry;
      });
    }
    if (!matches.length) missing.push(token);
    for (const entry of matches) if (!picked.includes(entry)) picked.push(entry);
  }
  if (missing.length) {
    die(1, `audit-report: not in the ledger (${ledger.path}) nor in the newest report: ${missing.join(', ')}\n`
      + '  an id is `check:resource` as the ledger spells it, or a bare `check` for all its resources -- --summary --json lists them');
  }
  return picked;
}

function recordDecisions(opts, outDir) {
  const ledger = loadLedger(resolveLedgerPath(opts.ledger, opts.siteRoot), { required: false });
  const at = nowIso();
  const say = (verb, entry, extra = '') => console.log(`audit-report: ${verb} ${identity(entry)}${extra}`);

  if (opts.accept.length) {
    for (const entry of selectEntries(ledger, opts.accept, outDir)) {
      if (entry.status === 'accepted') { say('already accepted:', entry); continue; }
      entry.previous_status = entry.status || 'still_failing';
      entry.status = 'accepted';
      entry.accepted_reason = opts.reason.trim();
      entry.accepted_at = at;
      say('accepted', entry);
    }
  }
  if (opts.unaccept.length) {
    for (const entry of selectEntries(ledger, opts.unaccept, outDir)) {
      if (entry.status !== 'accepted') { say('not accepted, left alone:', entry, ` (${entry.status})`); continue; }
      entry.status = LEDGER_STATUSES.includes(entry.previous_status) && entry.previous_status !== 'accepted'
        ? entry.previous_status : 'still_failing';
      delete entry.previous_status;
      delete entry.accepted_reason;
      delete entry.accepted_at;
      say('unaccepted', entry, ` -> ${entry.status}`);
    }
  }
  if (opts.markFixed.length) {
    for (const entry of selectEntries(ledger, opts.markFixed, outDir)) {
      if (entry.status === 'accepted') { say('skipped (accepted -- --unaccept it first):', entry); continue; }
      if (entry.status === 'resolved') { say('skipped (already resolved by a measurement):', entry); continue; }
      entry.status = 'fixed_unverified';
      entry.fix_evidence = opts.evidence.trim();
      entry.fixed_at = at;
      say('marked fixed_unverified', entry);
    }
  }
  ledger.data.ledger_version = ledger.data.ledger_version || 1;
  saveLedger(ledger);
  console.log(`audit-report: wrote ${resolve(ledger.path)}`);
  if (opts.markFixed.length) console.log('audit-report: fixed_unverified is not resolved -- only a run that measures the check resolves it');
  if (!opts.rerender) console.log('audit-report: the report on disk still shows the old state -- run --rerender to refresh it');
}

// Ledger decisions as the renderers need them. `fresh` is true when the findings come from
// a run just measured: a `fixed_unverified` entry that run still found is open (the fix did
// not hold), whatever the ledger says. A rerender has no fresh measurement, so the entry
// stays set aside.
function splitByDecision(findings, entries, fresh) {
  const byId = new Map(entries.map((entry) => [identity(entry), entry]));
  const present = new Set(findings.map(identity));
  const decorate = (finding, entry) => ({
    ...finding,
    decision: entry.status === 'accepted'
      ? { reason: entry.accepted_reason || '', at: entry.accepted_at || '' }
      : { reason: entry.fix_evidence || '', at: entry.fixed_at || '' },
  });
  const open = [];
  const accepted = [];
  const fixed = [];
  for (const finding of findings) {
    const entry = byId.get(identity(finding));
    if (entry?.status === 'accepted') accepted.push(decorate(finding, entry));
    else if (entry?.status === 'fixed_unverified' && !fresh) fixed.push(decorate(finding, entry));
    else {
      if (entry?.status === 'fixed_unverified') {
        console.error(`audit-report: ${identity(finding)} is marked fixed_unverified but this run still found it -- reported as open`);
      }
      open.push(finding);
    }
  }
  // Decisions about findings this run does not carry still belong in the report.
  for (const entry of entries) {
    if (present.has(identity(entry)) || !['accepted', 'fixed_unverified'].includes(entry.status)) continue;
    const stub = {
      check: entry.check, resource: entry.resource || null, severity: entry.severity,
      message: entry.message || entry.evidence || entry.check,
    };
    (entry.status === 'accepted' ? accepted : fixed).push(decorate(stub, entry));
  }
  return { open, accepted, fixed };
}

function statusTable(rows) {
  const blank = () => ({ CRITICAL: 0, WARNING: 0, INFO: 0, other: 0, total: 0 });
  const byStatus = Object.fromEntries(LEDGER_STATUSES.map((status) => [status, blank()]));
  const bySeverity = blank();
  for (const row of rows) {
    const status = row.status || 'unknown';
    byStatus[status] ||= blank();
    const bucket = row.severity in SEVERITY_ORDER ? row.severity : 'other';
    byStatus[status][bucket] += 1;
    byStatus[status].total += 1;
    bySeverity[bucket] += 1;
    bySeverity.total += 1;
  }
  const open = blank();
  for (const status of OPEN_STATUSES) for (const key of Object.keys(open)) open[key] += byStatus[status][key];
  return { by_status: byStatus, by_severity: bySeverity, open };
}

function printSummary(opts, outDir) {
  const ledger = loadLedger(resolveLedgerPath(opts.ledger, opts.siteRoot), { required: false });
  let source = 'ledger';
  let path = ledger.path;
  let rows = ledger.data.findings;
  if (!ledger.exists) {
    const sidecar = newestSidecar(outDir);
    if (!sidecar) die(1, `audit-report: no ledger at ${ledger.path} and no sidecar in ${outDir} -- nothing to summarise`);
    source = 'sidecar';
    path = sidecar.path;
    rows = sidecar.data.findings.filter((f) => !f.not_remeasured).map((f) => ({ ...f, status: f.status || 'open' }));
  }
  const table = statusTable(rows);
  const result = { source, path: resolve(path), total: rows.length, ...table };
  if (opts.json) {
    console.log(JSON.stringify(result, null, 2));
    return;
  }
  const pad = (v, n) => String(v).padEnd(n);
  console.log(`audit-report: ${source} ${resolve(path)} -- ${rows.length} entries`);
  console.log(`${pad('status', 18)}${pad('CRITICAL', 10)}${pad('WARNING', 9)}${pad('INFO', 6)}${pad('other', 7)}total`);
  const line = (label, b) => console.log(`${pad(label, 18)}${pad(b.CRITICAL, 10)}${pad(b.WARNING, 9)}${pad(b.INFO, 6)}${pad(b.other, 7)}${b.total}`);
  for (const [status, bucket] of Object.entries(table.by_status)) line(status, bucket);
  line('open*', table.open);
  line('all', table.by_severity);
  console.log(`* open = ${OPEN_STATUSES.join(' + ')}. accepted and fixed_unverified are set aside, resolved is closed.`);
}

function counts(findings) {
  const out = { total: findings.length, CRITICAL: 0, WARNING: 0, INFO: 0, other: 0 };
  for (const finding of findings) {
    // This also counts a PREVIOUS run's sidecar, which never passed validation -- it was
    // written by whatever version of this tool existed then. An unknown severity must land
    // somewhere visible: dropping it leaves a summary whose parts do not add up to its own
    // total, in a client-facing comparison, with nothing saying why.
    if (finding.severity in out && finding.severity !== 'total' && finding.severity !== 'other') {
      out[finding.severity] += 1;
    } else {
      out.other += 1;
    }
  }
  return out;
}

function ownershipCounts(findings) {
  const out = { code: 0, setting: 0, content: 0, manual: 0 };
  for (const finding of findings) out[finding.ownership] += 1;
  return out;
}

function groupBy(findings, key) {
  const groups = new Map();
  for (const finding of findings) {
    const value = finding[key] || null;
    if (value === null) continue;
    if (!groups.has(value)) groups.set(value, []);
    groups.get(value).push(finding);
  }
  return groups;
}

function sortForPlan(findings) {
  return [...findings].sort((a, b) => {
    // `counts()` already buckets an unrecognised severity; this has to survive one too.
    // `undefined - undefined` is NaN, NaN !== 0, and a comparator returning NaN leaves the
    // sort undefined -- on a list built from a PREVIOUS run's sidecar, which never passed
    // validation because it was written by whatever version existed then.
    const rank = (finding) => SEVERITY_ORDER[finding.severity] ?? Number.POSITIVE_INFINITY;
    const bySeverity = rank(a) - rank(b);
    if (bySeverity !== 0) return bySeverity;
    return identity(a).localeCompare(identity(b));
  });
}

// A Markdown table cell ends at the next `|`, and an evidence string is exactly the kind
// of value that carries one — a grep pattern, a shell pipeline, a CSS selector list. An
// unescaped pipe silently splits the row and shifts every later column left, so the
// ownership of one finding is printed against another's problem.
function mdCell(value) {
  return String(value ?? '')
    .replaceAll('|', '\\|')
    // Every call site wraps its output in a code span, so a backtick in the value closes
    // that span early and the rest of the cell renders as prose with a stray backtick.
    .replaceAll('`', "'")
    .replace(/\s*\n\s*/g, ' ')
    .trim();
}

// The one place a count becomes a sentence. Both renderers call it, so the unclassified
// tail cannot be added to one and forgotten in the other.
function scoreSentence(t, c) {
  const line = fill(t.scoreLine, {
    total: c.total,
    critical: c.CRITICAL,
    warning: c.WARNING,
    info: c.INFO,
  });
  return c.other ? line + fill(t.otherSeverity, { other: c.other }) : line;
}

function fill(template, values) {
  return Object.entries(values).reduce(
    (text, [key, value]) => text.replaceAll(`%${key}%`, String(value)),
    template,
  );
}

// `scope` says what THIS run measured: `unmeasured` (entries with a check id) and
// `categories` (the categories the run covered; empty means the run did not say).
// A previous finding that is absent now is "resolved" only if its check was looked at. One
// whose check is listed as unmeasured, or whose category the run did not cover, is carried
// as "not re-measured": absence of evidence is not a fix, and calling it one hid the
// production-only checks a local run skips behind a "Resolved" count.
function compare(findings, previous, scope = {}) {
  if (!previous) return null;
  const skippedChecks = new Set((scope.unmeasured || []).map((entry) => entry.check));
  const coveredCategories = new Set((scope.categories || []).map((name) => String(name).toLowerCase()));
  const measuredNow = (finding) => {
    if (skippedChecks.has(finding.check)) return false;
    if (coveredCategories.size && finding.category && !coveredCategories.has(String(finding.category).toLowerCase())) return false;
    return true;
  };
  // A folded finding is still present: its identity travels under its parent's also_affects.
  // Without this a sibling that outlives its parent reads as resolved-and-new.
  const withFolded = (list) => new Set(list.flatMap((f) => [identity(f), ...(f.also_affects || []).map((a) => identity(a))]));
  const now = withFolded(findings);
  // A finding a human accepted may be left out of the run on purpose; that is not a fix.
  for (const id of scope.keep || []) now.add(id);
  const before = withFolded(previous.findings);
  return {
    date: previous.date,
    // A previous run that measured nothing is not one that found nothing, and the
    // difference decides how to read every "new since" below it.
    unmeasured: Array.isArray(previous.unmeasured) ? previous.unmeasured.length : 0,
    // A finding the previous run carried forward unmeasured is in its sidecar for the baseline,
    // not in its score: it was not found by that run.
    counts: counts(previous.findings.filter((finding) => !finding.not_remeasured && !finding.status)),
    resolved: previous.findings.filter((finding) => !now.has(identity(finding)) && measuredNow(finding)),
    notMeasured: previous.findings.filter((finding) => !now.has(identity(finding)) && !measuredNow(finding)),
    added: findings.filter((finding) => !before.has(identity(finding))),
    carried: findings.filter((finding) => before.has(identity(finding))),
  };
}

// The sentence a run with no findings renders in place of the plan. Both renderers call it.
// With unmeasured checks it must not read as a clean bill of health: the Not measured
// section below it says those checks never ran.
function noFindingsText(model) {
  if (model.accepted.length || model.fixed.length) return model.t.noOpen;
  return model.unmeasured.length ? model.t.noFindingsUnmeasured : model.t.noFindings;
}

// Tier 3 is unmeasured when the run says so (`tier3: "unmeasured"`) or lists an unmeasured
// entry whose check id starts with `tier3`/`tier-3`. The reader of a report with no browser
// findings otherwise assumes the browser tier passed.
function tier3Unmeasured(run) {
  const entries = Array.isArray(run.unmeasured) ? run.unmeasured : [];
  return String(run.tier3 || '').toLowerCase() === 'unmeasured'
    || entries.some((entry) => /^tier-?3(\b|_)/i.test(String((entry && entry.check) || '')));
}

function renderMarkdown(model) {
  const t = model.t;
  const lines = [];
  const push = (line = '') => lines.push(line);

  push(`# ${t.title} — ${model.site}`);
  push();
  push(`- **${t.date}:** ${model.date}`);
  if (model.tier) push(`- **${t.tier}:** ${model.tier}`);
  if (model.categories.length) push(`- **${t.categories}:** ${model.categories.join(', ')}`);
  push();

  push(`## ${t.summary}`);
  push();
  if (model.tier3Unmeasured) {
    push(`**${t.tier3Unmeasured}**`);
    push();
  }
  push(scoreSentence(t, model.counts));
  push();
  if (model.accepted.length || model.fixed.length) {
    push(fill(t.decisionsLine, { accepted: model.accepted.length, fixed: model.fixed.length }));
    push();
  }
  if (model.plan.length) {
    push(fill(t.ownershipCounts, model.ownership));
    push();
  }

  if (model.notes.length) {
    push(`## ${t.scope}`);
    push();
    for (const note of model.notes) {
      const block = noteBlock(note);
      if (block.list) block.list.forEach((item) => push(`- ${item}`));
      else push(block.text);
      push();
    }
  }

  push(`## ${t.comparison}`);
  push();
  if (!model.comparison) {
    push(t.noPrevious);
  } else {
    const c = model.comparison;
    push(`**${t.previousRun}:** ${c.date} — ${scoreSentence(t, c.counts)}`
      + (c.unmeasured ? fill(t.previousUnmeasured, { unmeasured: c.unmeasured }) : ''));
    push();
    for (const [label, list] of [[t.improved, c.resolved], [t.regressed, c.added], [t.carried, c.carried], [t.notRemeasured, c.notMeasured]]) {
      if (list === c.notMeasured && !list.length) continue;
      push(`- **${label}:** ${list.length}`);
      for (const finding of sortForPlan(list)) {
        push(`  - \`${mdCell(identity(finding))}\` — ${mdCell(finding.message)}`);
      }
    }
  }
  push();

  if (model.byCategory.size) {
    push(`## ${t.byCategory}`);
    push();
    push(`| ${t.category} | ${t.severity.CRITICAL} | ${t.severity.WARNING} | ${t.severity.INFO} |`);
    push('|---|---:|---:|---:|');
    for (const [name, list] of model.byCategory) {
      const c = counts(list);
      push(`| ${mdCell(name)} | ${c.CRITICAL} | ${c.WARNING} | ${c.INFO} |`);
    }
    push();
  }

  if (model.byPage.size) {
    push(`## ${t.byPage}`);
    push();
    push(`| ${t.page} | ${t.severity.CRITICAL} | ${t.severity.WARNING} | ${t.severity.INFO} |`);
    push('|---|---:|---:|---:|');
    for (const [name, list] of model.byPage) {
      const c = counts(list);
      push(`| ${mdCell(name)} | ${c.CRITICAL} | ${c.WARNING} | ${c.INFO} |`);
    }
    push();
  }

  push(`## ${t.plan}`);
  push();
  if (model.plan.length === 0) {
    push(noFindingsText(model));
    push();
  } else {
    push(`| ${t.priority} | ${t.code} | ${t.page} | ${t.problem} | ${t.todo} | ${t.applied} |`);
    push('|---|---|---|---|---|---|');
    for (const finding of model.plan) {
      push(`| ${[
        t.severity[finding.severity],
        `\`${identity(finding)}\``,
        finding.page || '—',
        finding.message + alsoText(finding),
        finding.fix || '—',
        t.ownership[finding.ownership] + (finding.design_impact === true ? ` · ${t.designImpact}` : ''),
      ].map(mdCell).join(' | ')} |`);
    }
    push();
    push(fill(t.ownershipCounts, model.ownership));
    push();
    push(`> ${t.settingWarning}`);
    push();
  }

  for (const [heading, note, list, column] of [
    [t.accepted, t.acceptedNote, model.accepted, t.reason],
    [t.fixedUnverified, t.fixedNote, model.fixed, t.evidenceCol],
  ]) {
    if (!list.length) continue;
    push(`## ${heading}`);
    push();
    push(note);
    push();
    push(`| ${t.code} | ${t.problem} | ${column} | ${t.decidedOn} |`);
    push('|---|---|---|---|');
    for (const finding of sortForPlan(list)) {
      push(`| ${[`\`${identity(finding)}\``, finding.message, finding.decision.reason || '—', String(finding.decision.at).slice(0, 10) || '—'].map(mdCell).join(' | ')} |`);
    }
    push();
  }

  push(`## ${t.unmeasured}`);
  push();
  if (model.unmeasured.length === 0) {
    push(t.none);
  } else {
    push(t.unmeasuredNote);
    push();
    for (const entry of model.unmeasured) {
      push(`- \`${entry.check}\` — ${entry.reason || entry.message || ''}`);
    }
  }
  push();

  return `${lines.join('\n')}\n`;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

// One file, no external stylesheet, no script, no font. It is opened by double-click,
// forwarded as an attachment and printed to PDF from the browser — every one of which
// breaks the moment the page fetches something.
//
// The two things a reader clicks — the theme switch and the severity filter — are
// therefore CSS, not script: a hidden input and `:has()`. A mail client that strips
// scripts, or a print dialog, leaves both working or harmlessly inert, and the page
// still honours the reader's system colour scheme with no input at all.
const HTML_UI = {
  en: {
    kicker: 'WordPress audit report',
    finding: 'finding',
    findings: 'findings',
    criticalOne: 'critical',
    critical: 'critical',
    warningOne: 'warning',
    warnings: 'warnings',
    info: 'info',
    unmeasured: 'not measured',
    uncategorised: 'Other findings',
    show: 'Show:',
    all: 'All',
    onlyCritical: 'Critical only',
    criticalAndWarnings: 'Critical and warnings',
    dark: 'Dark mode',
    light: 'Light mode',
    total: 'Total',
    evidence: 'Evidence',
    resource: 'Resource',
    legend: 'Legend',
    legendSeverity: 'Severity',
    legendOwner: 'Who applies the fix',
    legendDesign: 'Changes how the page looks; needs consent and a before/after measurement before it is applied.',
    ownerHelp: {
      code: 'a file in the theme or the site\'s own plugins; fixed once, travels with the commit.',
      setting: 'a WordPress option, a plugin\'s configuration, a server or CDN rule — does not travel with the commit.',
      content: 'a text somebody has to write or decide: descriptions, alternative text, links.',
      manual: 'human judgement, an external provider, or vendor code that is worked around rather than edited.',
    },
    categoryNames: {
      security: 'Security', seo: 'SEO', a11y: 'Accessibility', performance: 'Performance',
      'best-practices': 'Best practices', geo: 'GEO / AI agents', usability: 'Usability',
    },
  },
  es: {
    kicker: 'Informe de auditoría WordPress',
    finding: 'hallazgo',
    findings: 'hallazgos',
    criticalOne: 'crítico',
    critical: 'críticos',
    warningOne: 'advertencia',
    warnings: 'advertencias',
    info: 'informativos',
    unmeasured: 'sin medir',
    uncategorised: 'Otros hallazgos',
    show: 'Ver:',
    all: 'Todos',
    onlyCritical: 'Solo críticos',
    criticalAndWarnings: 'Críticos y advertencias',
    dark: 'Modo oscuro',
    light: 'Modo claro',
    total: 'Total',
    evidence: 'Evidencia',
    resource: 'Recurso',
    legend: 'Leyenda',
    legendSeverity: 'Severidad',
    legendOwner: 'Quién aplica la corrección',
    legendDesign: 'Cambia el aspecto de la página; requiere consentimiento y medición antes y después de aplicarla.',
    ownerHelp: {
      code: 'archivo del tema o de un plugin propio; se corrige una vez y viaja con el commit.',
      setting: 'opción de WordPress, configuración de un plugin, regla del servidor o del CDN; no viaja con el commit.',
      content: 'hay que escribir o decidir un texto: descripciones, textos alternativos, enlaces.',
      manual: 'juicio humano, proveedor externo o código de terceros que se sortea en lugar de editarse.',
    },
    categoryNames: {
      security: 'Seguridad', seo: 'SEO', a11y: 'Accesibilidad', performance: 'Rendimiento',
      'best-practices': 'Buenas prácticas', geo: 'GEO / agentes IA', usability: 'Usabilidad',
    },
  },
};

// Light values first; the dark block redefines the same tokens, so no rule below names a
// colour directly. A rule that did would stay light in dark mode, which is how a dark
// theme ends up with one white table in the middle of it.
const HTML_TOKENS_LIGHT = `--ink:#1b1f24;--muted:#5b6672;--rule:#e3e7ec;--canvas:#f6f7f9;--paper:#fff;
  --ok:#1a7f4b;--ok-bg:#e6f4ec;--ok-rule:#c6e6d5;--bad:#c0362c;--bad-bg:#fbeae8;--bad-rule:#f2cfcb;
  --mid:#9a6a00;--mid-bg:#fdf3e0;--mid-rule:#f0dcb4;--info:#2b5fa8;--info-bg:#e9f0fb;--info-rule:#cfe0f6;
  --na:#7a828c;--na-bg:#eef0f3;--na-rule:#dfe3e8;--bar:rgba(255,255,255,.96);--hover:#fafbfc;color-scheme:light;`;
const HTML_TOKENS_DARK = `--ink:#e6e9ee;--muted:#9aa4b0;--rule:#2c333c;--canvas:#0f1318;--paper:#171c22;
  --ok:#4cc38a;--ok-bg:#11291d;--ok-rule:#1d4a33;--bad:#ff7b72;--bad-bg:#3a1714;--bad-rule:#5c2520;
  --mid:#e3b341;--mid-bg:#352a0c;--mid-rule:#5a4513;--info:#79b8ff;--info-bg:#132a45;--info-rule:#24476e;
  --na:#8b949e;--na-bg:#232a32;--na-rule:#333b45;--bar:rgba(23,28,34,.94);--hover:#1c232b;color-scheme:dark;`;

const HTML_CSS = `
:root{${HTML_TOKENS_LIGHT}}
@media (prefers-color-scheme:dark){:root{${HTML_TOKENS_DARK}}}
/* The switch inverts whatever the system chose, so it works from either starting point. */
:root:has(#theme:checked){${HTML_TOKENS_DARK}}
@media (prefers-color-scheme:dark){:root:has(#theme:checked){${HTML_TOKENS_LIGHT}}}
*{box-sizing:border-box}
body{margin:0;background:var(--canvas);color:var(--ink);
  font:15px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
  -webkit-text-size-adjust:100%}
.wrap{max-width:1180px;margin:0 auto;padding:0 24px}
h1{font-size:30px;margin:.1em 0 .2em;letter-spacing:-.01em}
h2{font-size:22px;margin:0 0 16px;padding-bottom:8px;border-bottom:2px solid var(--rule)}
p{margin:0 0 12px}
code{background:var(--na-bg);padding:1px 5px;border-radius:4px;font-size:.9em}
.top{background:var(--paper);border-bottom:1px solid var(--rule);padding:34px 0 26px}
.kicker{margin:0;color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.1em}
.meta{margin:2px 0;color:var(--muted);font-size:13.5px}
.kpis{display:flex;flex-wrap:wrap;gap:12px;margin-top:20px}
.kpi{background:var(--canvas);border:1px solid var(--rule);border-radius:10px;padding:12px 16px;min-width:120px}
.kpi b{display:block;font-size:26px;line-height:1.1}
.kpi span{color:var(--muted);font-size:12.5px}
.kpi.big{background:var(--info-bg);border-color:var(--info-rule)}
.kpi.big b{font-size:34px;color:var(--info)}
b.ok{color:var(--ok)} b.bad{color:var(--bad)} b.mid{color:var(--mid)} b.info{color:var(--info)}
.toc{position:sticky;top:0;z-index:5;background:var(--bar);border-bottom:1px solid var(--rule);
  backdrop-filter:saturate(1.6) blur(6px)}
.toc .wrap{display:flex;align-items:center;gap:4px;overflow-x:auto;padding-top:6px;padding-bottom:6px}
.toc a{white-space:nowrap;padding:6px 10px;border-radius:7px;text-decoration:none;color:var(--muted);font-size:13px}
.toc a:hover{background:var(--na-bg);color:var(--ink)}
.theme{margin-left:auto;white-space:nowrap;cursor:pointer;font-size:13px;background:var(--paper);color:var(--ink);
  border:1px solid var(--rule);border-radius:7px;padding:5px 11px}
.theme .to-light{display:none}
:root:has(#theme:focus-visible) .theme{outline:2px solid var(--info);outline-offset:2px}
:root:has(#theme:checked) .theme .to-dark{display:none}
:root:has(#theme:checked) .theme .to-light{display:inline}
@media (prefers-color-scheme:dark){
  .theme .to-dark{display:none} .theme .to-light{display:inline}
  :root:has(#theme:checked) .theme .to-dark{display:inline}
  :root:has(#theme:checked) .theme .to-light{display:none}
}
.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip-path:inset(50%);white-space:nowrap}
main.wrap{padding:28px 24px 60px}
section{background:var(--paper);border:1px solid var(--rule);border-radius:12px;padding:24px;margin:0 0 22px}
section,details.group{scroll-margin-top:64px}
.scroll{overflow-x:auto;-webkit-overflow-scrolling:touch;margin:0 0 12px}
table{border-collapse:collapse;width:100%;font-size:13.5px}
th,td{text-align:left;vertical-align:top;padding:8px 10px;border-bottom:1px solid var(--rule)}
thead th{background:var(--canvas);color:var(--muted);font-size:12px;text-transform:uppercase;
  letter-spacing:.04em;white-space:nowrap}
tbody tr:hover{background:var(--hover)}
td.num{font-variant-numeric:tabular-nums;white-space:nowrap;font-weight:600}
td.nowrap{white-space:nowrap}
.ev{color:var(--muted);word-break:break-word}
span.ev{display:-webkit-box;-webkit-line-clamp:4;-webkit-box-orient:vertical;overflow:hidden;margin-top:2px;font-size:12.5px}
.muted{color:var(--na)}
tr.sum td{background:var(--canvas);font-weight:600;border-top:2px solid var(--rule)}
.chip{display:inline-block;padding:2px 8px;border-radius:999px;font-size:12px;white-space:nowrap;border:1px solid transparent}
.sev-critical{background:var(--bad-bg);color:var(--bad);border-color:var(--bad-rule);font-weight:600}
.sev-warning{background:var(--mid-bg);color:var(--mid);border-color:var(--mid-rule)}
.sev-info{background:var(--na-bg);color:var(--na);border-color:var(--na-rule)}
.sev-other,.chip.unmeasured{background:var(--info-bg);color:var(--info);border-color:var(--info-rule)}
.score{display:inline-block;min-width:34px;text-align:center;padding:2px 7px;border-radius:6px;
  font-weight:600;font-variant-numeric:tabular-nums}
.score.ok{background:var(--ok-bg);color:var(--ok)} .score.bad{background:var(--bad-bg);color:var(--bad)}
.score.mid{background:var(--mid-bg);color:var(--mid)} .score.na{background:var(--na-bg);color:var(--na)}
.tag{display:inline-block;padding:2px 8px;border-radius:6px;font-size:12px;border:1px solid var(--rule);white-space:nowrap}
.own-code{background:var(--info-bg);color:var(--info);border-color:var(--info-rule)}
.own-setting{background:var(--mid-bg);color:var(--mid);border-color:var(--mid-rule)}
.own-content{background:var(--ok-bg);color:var(--ok);border-color:var(--ok-rule)}
.own-manual{background:var(--na-bg);color:var(--na);border-color:var(--na-rule)}
.design-impact{background:transparent;color:var(--mid);border:1px dashed var(--mid-rule)}
.note{color:var(--muted);font-size:13px;border-left:3px solid var(--rule);padding-left:12px;margin-top:14px}
.changes{margin:0;padding-left:18px} .changes li{margin-bottom:8px} .changes ul{color:var(--muted);font-size:13px}
.legend{margin:0;padding-left:18px;font-size:13.5px} .legend li{margin-bottom:8px}
.filters{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin:0 0 16px;font-size:13px;color:var(--muted)}
.filters label{cursor:pointer;background:var(--paper);border:1px solid var(--rule);border-radius:7px;padding:5px 11px;color:var(--ink)}
.filters input:checked+label{background:var(--info);border-color:var(--info);color:var(--paper)}
.filters input:focus-visible+label{outline:2px solid var(--info);outline-offset:2px}
:root:has(#filter-critical:checked) tr[data-sev="WARNING"],
:root:has(#filter-critical:checked) tr[data-sev="INFO"],
:root:has(#filter-problems:checked) tr[data-sev="INFO"]{display:none}
details.group{border:1px solid var(--rule);border-radius:10px;margin-bottom:12px;background:var(--paper)}
details.group>summary{cursor:pointer;padding:12px 16px;display:flex;align-items:center;gap:10px;flex-wrap:wrap;list-style:none}
details.group>summary::-webkit-details-marker{display:none}
details.group>summary::before{content:"▸";color:var(--muted);font-size:12px}
details.group[open]>summary::before{content:"▾"}
details.group[open]>summary{border-bottom:1px solid var(--rule);background:var(--canvas);border-radius:10px 10px 0 0}
details.group>.scroll{margin:0 16px 16px}
.pill{background:var(--na-bg);color:var(--muted);border-radius:999px;padding:2px 9px;font-size:12px}
.pill.bad{background:var(--bad-bg);color:var(--bad)} .pill.mid{background:var(--mid-bg);color:var(--mid)}
footer.wrap{color:var(--muted);font-size:12.5px;padding-bottom:36px}
@media (max-width:720px){
  .wrap{padding:0 14px} main.wrap{padding:18px 14px 40px} section{padding:16px}
  h1{font-size:24px} .kpi.big b{font-size:28px}
}
@media print{
  :root,:root:has(#theme:checked){${HTML_TOKENS_LIGHT}}
  body{background:#fff} .toc,.filters,.theme{display:none}
  tr[data-sev]{display:table-row!important}
  section{border:none;padding:0;margin-bottom:18px}
  details.group{border:none} details.group>.scroll{margin:0}
  h2{break-after:avoid} tr{break-inside:avoid}
  span.ev{display:block;overflow:visible;-webkit-line-clamp:none}
}`;

function renderHtml(model) {
  const t = model.t;
  // parseArgs() refuses a --lang HTML_UI does not carry, so this lookup cannot fall back.
  const ui = HTML_UI[model.lang];
  const plural = (n, one, many) => (n === 1 ? one : many);
  const esc = escapeHtml;
  const sevChip = (severity) =>
    `<span class="chip sev-${severity in SEVERITY_ORDER ? severity.toLowerCase() : 'other'}">${esc(
      t.severity[severity] || severity,
    )}</span>`;
  const ownTag = (owner) => `<span class="tag own-${owner}">${esc(t.ownership[owner] || owner)}</span>`;
  // A zero is good news and is coloured as such; a count is coloured by what it counts.
  const score = (value, tone) => `<span class="score ${value ? tone : 'ok'}">${value}</span>`;
  // The header KPIs follow the same rule, so a clean run is not a red 0 at the top of the page.
  const kpi = (value, tone) => `<b class="${value ? tone : 'ok'}">${value}</b>`;
  const categoryName = (name) => ui.categoryNames[name] || name;
  const slug = (value) => String(value).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  const c = model.counts;

  // `labelHtml` is markup, not text: it is inserted as is, so every caller escapes the run
  // input it wraps (group names come from the audited site). groupTable's `nameHtml` feeds it.
  const countRow = (labelHtml, list) => {
    const n = counts(list);
    return `<tr><td>${labelHtml}</td><td>${score(n.CRITICAL, 'bad')}</td><td>${score(n.WARNING, 'mid')}</td><td>${score(
      n.INFO,
      'na',
    )}</td><td class="num">${n.total}</td></tr>`;
  };
  const groupTable = (heading, id, groups, label, nameHtml) => {
    if (!groups.size) return '';
    const rows = [...groups].map(([key, list]) => countRow(nameHtml(key), list)).join('');
    // Totals of the rows printed, not of the run: groupBy skips findings without the key
    // (site-wide findings have no page), and a Total larger than its rows reads as a sum error.
    const listed = counts([...groups.values()].flat());
    return `<section id="${id}"><h2>${esc(heading)}</h2><div class="scroll"><table>
<thead><tr><th>${esc(label)}</th><th>${esc(t.severity.CRITICAL)}</th><th>${esc(t.severity.WARNING)}</th><th>${esc(
      t.severity.INFO,
    )}</th><th>${esc(ui.total)}</th></tr></thead>
<tbody>${rows}<tr class="sum"><td>${esc(ui.total)}</td><td>${score(listed.CRITICAL, 'bad')}</td><td>${score(
      listed.WARNING,
      'mid',
    )}</td><td>${score(listed.INFO, 'na')}</td><td class="num">${listed.total}</td></tr></tbody></table></div></section>`;
  };

  const findingRow = (finding) => `<tr data-sev="${esc(finding.severity)}">
<td class="nowrap">${sevChip(finding.severity)}</td>
<td class="num">${esc(finding.check)}</td>
<td>${finding.page ? `<code>${esc(finding.page)}</code>` : '<span class="muted">—</span>'}</td>
<td><b>${esc(finding.message)}</b>${finding.also_affects && finding.also_affects.length ? `<br><span class="muted">${esc(alsoText(finding).trim())}</span>` : ''}${finding.resource ? `<br><span class="muted">${esc(ui.resource)}: ${esc(finding.resource)}</span>` : ''}${
    finding.evidence ? `<span class="ev" title="${esc(finding.evidence)}">${esc(ui.evidence)}: ${esc(finding.evidence)}</span>` : ''
  }</td>
<td class="ev">${finding.fix ? esc(finding.fix) : '<span class="muted">—</span>'}</td>
<td class="nowrap">${ownTag(finding.ownership)}${finding.design_impact === true ? ` <span class="tag design-impact">${esc(t.designImpact)}</span>` : ''}</td></tr>`;
  const findingTable = (list) => `<div class="scroll"><table>
<thead><tr>${[t.priority, t.code, t.page, t.problem, t.todo, t.applied].map((h) => `<th>${esc(h)}</th>`).join('')}</tr></thead>
<tbody>${list.map(findingRow).join('\n')}</tbody></table></div>`;

  const comparisonBlock = () => {
    if (!model.comparison) return `<p class="note">${esc(t.noPrevious)}</p>`;
    const cmp = model.comparison;
    const list = (label, items, tone) =>
      `<li><b class="${tone}">${esc(label)}:</b> ${items.length}<ul>${sortForPlan(items)
        .map((finding) => `<li><code>${esc(identity(finding))}</code> — ${esc(finding.message)}</li>`)
        .join('')}</ul></li>`;
    return `<p><b>${esc(t.previousRun)}:</b> ${esc(cmp.date)} — ${esc(
      scoreSentence(t, cmp.counts) + (cmp.unmeasured ? fill(t.previousUnmeasured, { unmeasured: cmp.unmeasured }) : ''),
    )}</p>
<ul class="changes">${list(t.improved, cmp.resolved, 'ok')}${list(t.regressed, cmp.added, 'bad')}${list(t.carried, cmp.carried, 'mid')}${cmp.notMeasured.length ? list(t.notRemeasured, cmp.notMeasured, 'mid') : ''}</ul>`;
  };

  // The detail groups by category. Findings the run left without a category go into one
  // trailing group, so the HTML lists every finding the Markdown does, and a run with no
  // categories at all is that one group. Every group is open: the report is a document, and
  // a printed PDF of a collapsed <details> would drop its findings.
  const byCategory = new Map(model.byCategory);
  const grouped = new Set([...byCategory.values()].flat());
  const rest = model.plan.filter((finding) => !grouped.has(finding));
  if (rest.length) byCategory.set(null, rest);
  // Ids come from the group's position, not only its name: names are run input, and two
  // that slug alike ("GEO / AI", "geo-ai") would share an id and misroute the table's link.
  const groupIds = new Map([...byCategory.keys()].map((name, i) => [name, `cat-${slug(name || 'other') || 'group'}-${i}`]));
  const groupLabel = (name) => {
    if (name) return categoryName(name);
    return model.byCategory.size ? ui.uncategorised : t.plan;
  };
  const groups = [...byCategory]
    .map(([name, list]) => {
      const n = counts(list);
      return `<details class="group" id="${groupIds.get(name)}" open>
<summary><b>${esc(groupLabel(name))}</b> <span class="pill">${n.total} ${esc(plural(n.total, ui.finding, ui.findings))}</span>${
        n.CRITICAL ? ` <span class="pill bad">${n.CRITICAL} ${esc(plural(n.CRITICAL, ui.criticalOne, ui.critical))}</span>` : ''
      }${n.WARNING ? ` <span class="pill mid">${n.WARNING} ${esc(plural(n.WARNING, ui.warningOne, ui.warnings))}</span>` : ''}</summary>
${findingTable(sortForPlan(list))}</details>`;
    })
    .join('\n');

  // A clean run shows the same sentence as the Markdown, not an empty plan, and drops the
  // filters, the ownership split and the setting warning, which describe changes there are
  // none of.
  const planBlock = model.plan.length === 0
    ? `<p>${esc(noFindingsText(model))}</p>`
    : `<div class="filters" role="radiogroup" aria-label="${esc(ui.show)}"><span>${esc(ui.show)}</span>
<input type="radio" name="filter" id="filter-all" class="sr" checked><label for="filter-all">${esc(ui.all)}</label>
<input type="radio" name="filter" id="filter-critical" class="sr"><label for="filter-critical">${esc(ui.onlyCritical)}</label>
<input type="radio" name="filter" id="filter-problems" class="sr"><label for="filter-problems">${esc(ui.criticalAndWarnings)}</label></div>
${groups}
<p>${esc(fill(t.ownershipCounts, model.ownership))}</p>
<p class="note">${esc(t.settingWarning.replaceAll('**', '').replaceAll('`', ''))}</p>`;

  const unmeasuredBlock = model.unmeasured.length
    ? `<p>${esc(t.unmeasuredNote)}</p><div class="scroll"><table><thead><tr><th>${esc(t.code)}</th><th></th><th>${esc(
        t.problem,
      )}</th></tr></thead><tbody>${model.unmeasured
        .map(
          (entry) =>
            `<tr><td class="num">${esc(entry.check)}</td><td><span class="chip unmeasured">${esc(ui.unmeasured)}</span></td><td class="ev">${esc(
              entry.reason || entry.message || '',
            )}</td></tr>`,
        )
        .join('')}</tbody></table></div>`
    : `<p>${esc(t.none)}</p>`;

  const decisionSection = (id, heading, note, list, column) => (list.length
    ? `<section id="${id}"><h2>${esc(heading)}</h2><p>${esc(note)}</p><div class="scroll"><table><thead><tr><th>${esc(t.code)}</th><th>${esc(t.problem)}</th><th>${esc(column)}</th><th>${esc(t.decidedOn)}</th></tr></thead><tbody>${sortForPlan(list)
      .map((finding) => `<tr><td class="num">${esc(identity(finding))}</td><td>${esc(finding.message)}</td><td class="ev">${finding.decision.reason ? esc(finding.decision.reason) : '<span class="muted">—</span>'}</td><td class="nowrap">${esc(String(finding.decision.at).slice(0, 10) || '—')}</td></tr>`)
      .join('')}</tbody></table></div></section>\n`
    : '');
  const decisionsBlock = decisionSection('accepted', t.accepted, t.acceptedNote, model.accepted, t.reason)
    + decisionSection('fixed', t.fixedUnverified, t.fixedNote, model.fixed, t.evidenceCol);

  const notesBlock = model.notes.length
    ? `<section id="scope"><h2>${esc(t.scope)}</h2>${model.notes
        .map((note) => {
          const block = noteBlock(note);
          return block.list
            ? `<ul>${block.list.map((item) => `<li>${esc(item)}</li>`).join('')}</ul>`
            : `<p>${esc(block.text)}</p>`;
        })
        .join('')}</section>\n`
    : '';

  const toc = [
    ['summary', t.summary],
    model.notes.length ? ['scope', t.scope] : null,
    ['comparison', t.comparison],
    model.byCategory.size ? ['by-category', t.byCategory] : null,
    model.byPage.size ? ['by-page', t.byPage] : null,
    ['plan', t.plan],
    model.accepted.length ? ['accepted', t.accepted] : null,
    model.fixed.length ? ['fixed', t.fixedUnverified] : null,
    ['unmeasured', t.unmeasured],
    ['legend', ui.legend],
  ].filter(Boolean);

  return `<!DOCTYPE html>
<html lang="${model.lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${esc(`${t.title} — ${model.site} — ${model.date}`)}</title>
<style>${HTML_CSS.replace(/\s*\n\s*/g, ' ')}</style>
</head>
<body>
<input type="checkbox" id="theme" class="sr">
<header class="top"><div class="wrap">
<p class="kicker">${esc(ui.kicker)}</p>
<h1>${esc(model.site)}</h1>
<p class="meta">${esc([model.date, model.tier].filter(Boolean).join(' · '))}</p>
${model.tier3Unmeasured ? `<p class="meta"><strong>${esc(t.tier3Unmeasured)}</strong></p>` : ''}
${model.categories.length ? `<p class="meta">${esc(t.categories)}: ${esc(model.categories.map(categoryName).join(', '))}</p>` : ''}
<div class="kpis">
<div class="kpi big"><b>${c.total}</b><span>${esc(plural(c.total, ui.finding, ui.findings))}</span></div>
<div class="kpi">${kpi(c.CRITICAL, 'bad')}<span>${esc(plural(c.CRITICAL, ui.criticalOne, ui.critical))}</span></div>
<div class="kpi">${kpi(c.WARNING, 'mid')}<span>${esc(plural(c.WARNING, ui.warningOne, ui.warnings))}</span></div>
<div class="kpi">${kpi(c.INFO, 'info')}<span>${esc(ui.info)}</span></div>
<div class="kpi">${kpi(model.unmeasured.length, 'info')}<span>${esc(ui.unmeasured)}</span></div>
</div></div></header>
<nav class="toc"><div class="wrap">${toc.map(([id, label]) => `<a href="#${id}">${esc(label)}</a>`).join('')}
<label class="theme" for="theme"><span class="to-dark">🌙 ${esc(ui.dark)}</span><span class="to-light">☀️ ${esc(ui.light)}</span></label></div></nav>
<main class="wrap">
<section id="summary"><h2>${esc(t.summary)}</h2>
${model.tier3Unmeasured ? `<p><strong>${esc(t.tier3Unmeasured)}</strong></p>\n` : ''}<p>${esc(scoreSentence(t, c))}</p>
${model.accepted.length || model.fixed.length ? `<p>${esc(fill(t.decisionsLine, { accepted: model.accepted.length, fixed: model.fixed.length }))}</p>\n` : ''}${model.plan.length ? `<p>${esc(fill(t.ownershipCounts, model.ownership))}</p>` : ''}</section>
${notesBlock}<section id="comparison"><h2>${esc(t.comparison)}</h2>${comparisonBlock()}</section>
${groupTable(t.byCategory, 'by-category', model.byCategory, t.category, (name) => `<a href="#${groupIds.get(name)}">${esc(categoryName(name))}</a>`)}
${groupTable(t.byPage, 'by-page', model.byPage, t.page, (name) => `<code>${esc(name)}</code>`)}
<section id="plan"><h2>${esc(t.plan)}</h2>
${planBlock}</section>
${decisionsBlock}<section id="unmeasured"><h2>${esc(t.unmeasured)}</h2>${unmeasuredBlock}</section>
<section id="legend"><h2>${esc(ui.legend)}</h2><ul class="legend">
<li><b>${esc(ui.legendSeverity)}:</b> ${['CRITICAL', 'WARNING', 'INFO'].map(sevChip).join(' ')}</li>
<li><b>${esc(ui.legendOwner)}:</b><ul>${OWNERSHIP.map((owner) => `<li>${ownTag(owner)} ${esc(ui.ownerHelp[owner])}</li>`).join('')}</ul></li>
<li><span class="tag design-impact">${esc(t.designImpact)}</span> ${esc(ui.legendDesign)}</li>
</ul></section>
</main>
<footer class="wrap"><p>${esc(`${t.title} · ${model.site} · ${model.date}`)}</p></footer>
</body>
</html>
`;
}

// Bring every finding to the canonical keys and fold in the agents' own report files.
// Returns the problems the normalizer refuses in the agent reports: an id outside the catalogs, and a check
// reported both as a finding and as a pass. The aliases it translates are accepted silently
// (they are listed in the standards skill), so an agent that wrote `owner` still renders;
// what it refuses is a report that cannot say which check it is about.
function aggregateAgents(run, agentPaths) {
  const problems = [];
  const findings = [];
  const unmeasured = Array.isArray(run.unmeasured) ? run.unmeasured : [];
  const executed = new Set(Array.isArray(run.checks_executed) ? run.checks_executed : []);
  const seenUnmeasured = new Set(unmeasured.map((e) => `${e?.check ?? e?.code}|${e?.reason ?? ''}`));

  // The run file's own findings may come from the browser suite, whose ids are the suite's
  // (`UX-045` is contrast there), so they are normalized but not held to the agents' catalogs.
  run.findings.forEach((raw) => findings.push(normalizeEntry(raw).entry));
  const extra = [];
  for (const path of agentPaths) {
    let reports;
    try {
      reports = loadReports(path);
    } catch (error) {
      die(1, `cannot read agent reports at ${path}: ${error.message}`);
    }
    for (const { label, report } of reports) {
      const n = normalizeReport(report, label);
      problems.push(...n.problems);
      n.executed.forEach((id) => executed.add(id));
      n.passes.forEach((p) => executed.add(p.check));
      n.findings.forEach((f) => { executed.add(f.check); findings.push(f); });
      for (const u of n.unmeasured) {
        const key = `${u.check}|${u.reason ?? ''}`;
        if (!seenUnmeasured.has(key)) { seenUnmeasured.add(key); extra.push(u); }
      }
    }
  }
  run.findings = findings;
  run.unmeasured = [...unmeasured.map((e) => (e && typeof e === 'object' ? normalizeEntry(e).entry : e)), ...extra];
  if (executed.size) run.checks_executed = [...executed];
  return problems;
}

const toSidecarFinding = (finding) => ({
  check: finding.check,
  resource: finding.resource || null,
  severity: finding.severity,
  ownership: finding.ownership,
  design_impact: finding.design_impact === true,
  category: finding.category || null,
  page: finding.page || null,
  message: finding.message,
  fix: finding.fix || null,
  evidence: finding.evidence || null,
  root_cause: finding.root_cause || null,
  also_affects: finding.also_affects && finding.also_affects.length ? finding.also_affects : null,
  ...(finding.status ? { status: finding.status } : {}),
  ...(finding.not_remeasured ? { not_remeasured: true } : {}),
});

// Everything both entry points share: split by ledger decision, build the model, write the
// documents and the sidecar. `stem` names the files (`informe-<date>` or an archived run's).
function writeReport({ opts, outDir, stem, date, run, folded, baseNotes, extraNotes, previous, fresh }) {
  const ledger = loadLedger(resolveLedgerPath(opts.ledger, opts.siteRoot), { required: false });
  const { open, accepted, fixed } = splitByDecision(folded, ledger.data.findings, fresh);
  const unmeasured = Array.isArray(run.unmeasured) ? run.unmeasured : [];
  const categories = Array.isArray(run.categories) ? run.categories : [];
  const setAside = [...accepted, ...fixed];

  const model = {
    lang: opts.lang,
    t: STRINGS[opts.lang],
    site: run.site || run.project || 'site',
    date,
    tier: run.tier || null,
    categories,
    counts: counts(open),
    ownership: ownershipCounts(open),
    byCategory: groupBy(open, 'category'),
    byPage: groupBy(open, 'page'),
    plan: sortForPlan(open),
    accepted,
    fixed,
    unmeasured,
    tier3Unmeasured: tier3Unmeasured(run),
    notes: [...baseNotes, ...extraNotes],
    comparison: compare(open, previous, { unmeasured, categories, keep: setAside.map(identity) }),
  };

  const written = [];
  if (opts.format === 'md' || opts.format === 'both') {
    const path = join(outDir, `${stem}.md`);
    writeFileSync(path, renderMarkdown(model));
    written.push(path);
  }
  if (opts.format === 'html' || opts.format === 'both') {
    const path = join(outDir, `${stem}.html`);
    writeFileSync(path, renderHtml(model));
    written.push(path);
  }

  // The sidecar is written last and holds exactly what the next run diffs against. It is
  // not the ledger: the ledger is the project's running record of every finding ever seen,
  // this is one dated snapshot of one run. A finding set aside carries its `status`, so the
  // previous-run count the next report prints is the open count this one printed.
  const statusOf = new Map(setAside.map((finding) => [identity(finding), accepted.includes(finding) ? 'accepted' : 'fixed_unverified']));
  const sidecarPath = join(outDir, `${stem}.json`);
  const sidecarTmp = `${sidecarPath}.tmp-${process.pid}`;
  writeFileSync(
    sidecarTmp,
    `${JSON.stringify(
      {
        report_version: 1,
        date,
        site: model.site,
        tier: model.tier,
        categories: model.categories,
        notes: baseNotes,
        unmeasured: model.unmeasured.map((entry) => ({ check: entry.check, reason: entry.reason || null })),
        // A previous finding this run did not measure stays in the baseline, flagged, so the
        // first run that does measure it can report it resolved instead of losing it.
        findings: [
          ...folded.map((finding) => (statusOf.has(identity(finding)) ? { ...finding, status: statusOf.get(identity(finding)) } : finding)),
          ...(model.comparison ? model.comparison.notMeasured.map((finding) => ({ ...finding, not_remeasured: true })) : []),
        ].map(toSidecarFinding),
      },
      null,
      2,
    )}\n`,
  );
  renameSync(sidecarTmp, sidecarPath);
  written.push(sidecarPath);

  for (const path of written) console.log(`audit-report: wrote ${resolve(path)}`);
}

function renderRun(opts) {
  const base = opts.run ? loadRun(opts.run, { findingsOptional: opts.agents.length > 0 }) : { findings: [] };
  const run = opts.merge.length
    ? mergeRuns(base, opts.merge.map(loadRun))
    : base;
  const schemaProblems = aggregateAgents(run, opts.agents);
  const notes = [
    ...normalizeNotes(run.notes, 'the run file'),
    ...(opts.notes ? readNotesFile(opts.notes) : []),
  ];
  const findings = run.findings;

  // A run with no findings is still rendered. A clean audit is a result the client is owed,
  // and its sidecar is the baseline the next audit diffs against: skipping it left the first
  // report-only run on a clean site with nothing to compare later runs to.

  const problems = [
    ...schemaProblems,
    ...validate(findings),
    ...validateUnmeasured(Array.isArray(run.unmeasured) ? run.unmeasured : []),
  ];
  if (problems.length) {
    die(1, `audit-report: ${problems.length} finding(s) cannot be rendered:\n  ${problems.join('\n  ')}`);
  }
  // Folded only after every finding has been validated, so a bad sibling cannot hide in a parent.
  const folded = foldRootCauses(findings);

  const date = opts.date || run.date || new Date().toISOString().slice(0, 10);
  const outDir = resolveOutDir(opts.out, opts.siteRoot, run);
  mkdirSync(outDir, { recursive: true });
  warnIfUnignored(outDir);

  const sidecarPath = join(outDir, `informe-${date}.json`);
  archiveSameDay(outDir, date);
  const previous = findPrevious(outDir, sidecarPath);
  writeReport({ opts, outDir, stem: `informe-${date}`, date, run, folded, baseNotes: notes, extraNotes: [], previous, fresh: true });
}

// Rebuild the newest report from its own sidecar and the ledger. The sidecar already holds
// every field the renderers read (this tool wrote it), so no audit and no run file is
// needed; the documents of that date are overwritten in place and nothing is archived.
function rerender(opts, outDir) {
  const latest = newestSidecar(outDir);
  if (!latest) die(1, `audit-report: --rerender found no informe-*.json in ${outDir} -- run an audit first, or pass --out`);
  const run = latest.data;
  const live = run.findings.filter((finding) => !finding.not_remeasured).map((finding) => {
    const { status, ...rest } = finding; // set aside by an earlier render: the ledger decides again
    return rest;
  });
  const problems = validate(live);
  if (problems.length) die(1, `audit-report: ${latest.path} cannot be rendered:\n  ${problems.join('\n  ')}`);
  const date = String(run.date || '');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) die(1, `audit-report: ${latest.path} has no valid "date"`);
  const stem = basename(latest.path, '.json');
  const baseNotes = normalizeNotes(run.notes, 'the sidecar');
  const extraNotes = [
    ...(opts.notes ? readNotesFile(opts.notes) : []),
    fill(STRINGS[opts.lang].rerendered, { today: new Date().toISOString().slice(0, 10), date }),
  ];
  const previous = findPrevious(outDir, latest.path);
  writeReport({ opts, outDir, stem, date, run, folded: live, baseNotes, extraNotes, previous, fresh: false });
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  // The audits-root fallback names the folder after the run's site when the manifest has no
  // slug, so a render resolves its own directory once the run is loaded.
  const outDir = resolveOutDir(opts.out, opts.siteRoot);
  if (opts.accept.length || opts.unaccept.length || opts.markFixed.length) recordDecisions(opts, outDir);
  if (opts.run || opts.agents.length) renderRun(opts);
  else if (opts.rerender) rerender(opts, outDir);
  if (opts.summary) printSummary(opts, outDir);
  process.exit(0);
}

try {
  main();
} catch (error) {
  console.error(`audit-report: ${error.stack || error.message}`);
  process.exit(3);
}
