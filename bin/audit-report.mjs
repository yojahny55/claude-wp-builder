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
//   bin/audit-report.mjs --run <run.json> [--merge <other.json>...] [--out <dir>]
//                        [--format md|html|both] [--lang en|es] [--date YYYY-MM-DD]
//
// --merge folds another run file into this one. One audit produces two sources of findings
// -- the agents, and the browser suite -- and rendering them separately would split one
// audit across two documents and two baselines. Where both describe the same check and the
// same resource, the MEASURED one wins: the suite loaded the page, the agent reasoned about
// the code. The losing finding is noted in the winner's evidence and that evidence is kept
// in the dated sidecar, so a later reader can see that two sources reported it.
//
// Exit codes (house convention):
//   0  documents written
//   1  invalid input — the run file is missing, unparseable, or a finding is incomplete
//   2  clean skip — the run carries no findings to report
//   3  crash

import { readFileSync, writeFileSync, mkdirSync, readdirSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';

const OWNERSHIP = ['code', 'setting', 'content', 'manual'];
const SEVERITY_ORDER = { CRITICAL: 0, WARNING: 1, INFO: 2 };

const STRINGS = {
  en: {
    title: 'Web audit',
    date: 'Date',
    tier: 'Tier',
    categories: 'Categories',
    summary: 'Summary',
    comparison: 'Compared with the previous audit',
    noPrevious:
      'No previous audit found. This report is the baseline every later run is measured against.',
    previousRun: 'Previous run',
    previousUnmeasured:
      ' — that run left %unmeasured% check(s) unmeasured, so what is "new" below may be what it never looked at',
    scoreLine: 'Findings: %total% (%critical% critical, %warning% warnings, %info% info)',
    improved: 'Resolved since the previous run',
    regressed: 'New since the previous run',
    carried: 'Still failing',
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
    unmeasuredNote:
      'These checks apply to this site and did not run. They are not passes — say what stopped them before treating this report as complete.',
    none: 'None',
    ownership: { code: 'Code', setting: 'Setting', content: 'Content', manual: 'Manual' },
    severity: { CRITICAL: 'High', WARNING: 'Medium', INFO: 'Low' },
  },
  es: {
    title: 'Auditoría web',
    date: 'Fecha',
    tier: 'Nivel',
    categories: 'Categorías',
    summary: 'Resumen',
    comparison: 'Comparativa con la auditoría anterior',
    noPrevious:
      'No hay auditoría anterior. Este informe es la línea base contra la que se mide cada ejecución posterior.',
    previousRun: 'Ejecución anterior',
    previousUnmeasured:
      ' — esa ejecución dejó %unmeasured% criterio(s) sin medir, así que lo que aquí figura como nuevo puede ser lo que entonces no se miró',
    scoreLine: 'Hallazgos: %total% (%critical% críticos, %warning% advertencias, %info% informativos)',
    improved: 'Resueltos desde la ejecución anterior',
    regressed: 'Nuevos desde la ejecución anterior',
    carried: 'Siguen fallando',
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
    unmeasuredNote:
      'Estos criterios aplican a este sitio y no se ejecutaron. No son aprobados: di qué lo impidió antes de dar el informe por completo.',
    none: 'Ninguno',
    ownership: { code: 'Código', setting: 'Ajuste', content: 'Contenido', manual: 'Manual' },
    severity: { CRITICAL: 'Alta', WARNING: 'Media', INFO: 'Baja' },
  },
};

function die(code, message) {
  console.error(message);
  process.exit(code);
}

function parseArgs(argv) {
  const opts = { out: '.wp-audit', format: 'both', lang: 'en', run: null, date: null, merge: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    const value = argv[i + 1];
    switch (flag) {
      case '--merge': {
        if (value === undefined || value.startsWith('--')) die(1, `${flag} needs a value`);
        opts.merge.push(value);
        i += 1;
        break;
      }
      case '--run':
      case '--out':
      case '--format':
      case '--lang':
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
  if (!opts.run) die(1, '--run <run.json> is required');
  if (!['md', 'html', 'both'].includes(opts.format)) {
    die(1, `--format must be md, html or both (got: ${opts.format})`);
  }
  if (!STRINGS[opts.lang]) {
    die(1, `--lang must be one of ${Object.keys(STRINGS).join(', ')} (got: ${opts.lang})`);
  }
  if (opts.date && !/^\d{4}-\d{2}-\d{2}$/.test(opts.date)) {
    die(1, `--date must be YYYY-MM-DD (got: ${opts.date})`);
  }
  return opts;
}

function loadRun(path) {
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
  return { ...base, findings: merged, unmeasured };
}

// The previous run is the newest sidecar in the output directory that is not this run's
// own. Markdown is never parsed back: a report rewritten by hand would then change what
// the next comparison claims happened.
function findPrevious(outDir, selfPath) {
  if (!existsSync(outDir)) return null;
  const sidecars = readdirSync(outDir)
    .filter((name) => /^informe-\d{4}-\d{2}-\d{2}\.json$/.test(name))
    .map((name) => join(outDir, name))
    .filter((path) => resolve(path) !== resolve(selfPath))
    .sort();
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

function compare(findings, previous) {
  if (!previous) return null;
  const now = new Set(findings.map(identity));
  const before = new Set(previous.findings.map(identity));
  return {
    date: previous.date,
    // A previous run that measured nothing is not one that found nothing, and the
    // difference decides how to read every "new since" below it.
    unmeasured: Array.isArray(previous.unmeasured) ? previous.unmeasured.length : 0,
    counts: counts(previous.findings),
    resolved: previous.findings.filter((finding) => !now.has(identity(finding))),
    added: findings.filter((finding) => !before.has(identity(finding))),
    carried: findings.filter((finding) => before.has(identity(finding))),
  };
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
  push(scoreSentence(t, model.counts));
  push();
  push(fill(t.ownershipCounts, model.ownership));
  push();

  push(`## ${t.comparison}`);
  push();
  if (!model.comparison) {
    push(t.noPrevious);
  } else {
    const c = model.comparison;
    push(`**${t.previousRun}:** ${c.date} — ${scoreSentence(t, c.counts)}`
      + (c.unmeasured ? fill(t.previousUnmeasured, { unmeasured: c.unmeasured }) : ''));
    push();
    for (const [label, list] of [[t.improved, c.resolved], [t.regressed, c.added], [t.carried, c.carried]]) {
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
  push(`| ${t.priority} | ${t.code} | ${t.page} | ${t.problem} | ${t.todo} | ${t.applied} |`);
  push('|---|---|---|---|---|---|');
  for (const finding of model.plan) {
    push(`| ${[
      t.severity[finding.severity],
      `\`${identity(finding)}\``,
      finding.page || '—',
      finding.message,
      finding.fix || '—',
      t.ownership[finding.ownership],
    ].map(mdCell).join(' | ')} |`);
  }
  push();
  push(fill(t.ownershipCounts, model.ownership));
  push();
  push(`> ${t.settingWarning}`);
  push();

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
    findings: 'findings',
    critical: 'critical',
    warnings: 'warnings',
    info: 'info',
    unmeasured: 'not measured',
    detail: 'Findings by category',
    show: 'Show:',
    all: 'All',
    onlyCritical: 'Critical only',
    criticalAndWarnings: 'Critical and warnings',
    dark: 'Dark mode',
    light: 'Light mode',
    total: 'Total',
    evidence: 'Evidence',
    resource: 'Resource',
    who: 'Who',
    legend: 'Legend',
    legendSeverity: 'Severity',
    legendOwner: 'Who applies the fix',
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
    findings: 'hallazgos',
    critical: 'críticos',
    warnings: 'advertencias',
    info: 'informativos',
    unmeasured: 'sin medir',
    detail: 'Hallazgos por categoría',
    show: 'Ver:',
    all: 'Todos',
    onlyCritical: 'Solo críticos',
    criticalAndWarnings: 'Críticos y advertencias',
    dark: 'Modo oscuro',
    light: 'Modo claro',
    total: 'Total',
    evidence: 'Evidencia',
    resource: 'Recurso',
    who: 'Quién',
    legend: 'Leyenda',
    legendSeverity: 'Severidad',
    legendOwner: 'Quién aplica la corrección',
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
:root:has(#theme:checked) .theme .to-dark{display:none}
:root:has(#theme:checked) .theme .to-light{display:inline}
@media (prefers-color-scheme:dark){
  .theme .to-dark{display:none} .theme .to-light{display:inline}
  :root:has(#theme:checked) .theme .to-dark{display:inline}
  :root:has(#theme:checked) .theme .to-light{display:none}
}
.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip-path:inset(50%);white-space:nowrap}
main{padding:28px 24px 60px}
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
footer{color:var(--muted);font-size:12.5px;padding-bottom:36px}
@media (max-width:720px){
  .wrap{padding:0 14px} main{padding:18px 14px 40px} section{padding:16px}
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
  const ui = HTML_UI[model.lang] || HTML_UI.en;
  const esc = escapeHtml;
  const sevChip = (severity) =>
    `<span class="chip sev-${severity in SEVERITY_ORDER ? severity.toLowerCase() : 'other'}">${esc(
      t.severity[severity] || severity,
    )}</span>`;
  const ownTag = (owner) => `<span class="tag own-${owner}">${esc(t.ownership[owner] || owner)}</span>`;
  // A zero is good news and is coloured as such; a count is coloured by what it counts.
  const score = (value, tone) => `<span class="score ${value ? tone : 'ok'}">${value}</span>`;
  const categoryName = (name) => ui.categoryNames[name] || name;
  const slug = (value) => String(value).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  const c = model.counts;

  const countRow = (label, list) => {
    const n = counts(list);
    return `<tr><td>${label}</td><td>${score(n.CRITICAL, 'bad')}</td><td>${score(n.WARNING, 'mid')}</td><td>${score(
      n.INFO,
      'na',
    )}</td><td class="num">${n.total}</td></tr>`;
  };
  const groupTable = (heading, id, groups, label, name) => {
    if (!groups.size) return '';
    const rows = [...groups].map(([key, list]) => countRow(name(key), list)).join('');
    return `<section id="${id}"><h2>${esc(heading)}</h2><div class="scroll"><table>
<thead><tr><th>${esc(label)}</th><th>${esc(t.severity.CRITICAL)}</th><th>${esc(t.severity.WARNING)}</th><th>${esc(
      t.severity.INFO,
    )}</th><th>${esc(ui.total)}</th></tr></thead>
<tbody>${rows}<tr class="sum"><td>${esc(ui.total)}</td><td>${score(c.CRITICAL, 'bad')}</td><td>${score(
      c.WARNING,
      'mid',
    )}</td><td>${score(c.INFO, 'na')}</td><td class="num">${c.total}</td></tr></tbody></table></div></section>`;
  };

  const findingRow = (finding) => `<tr data-sev="${esc(finding.severity)}">
<td class="nowrap">${sevChip(finding.severity)}</td>
<td class="num">${esc(finding.check)}</td>
<td>${finding.page ? `<code>${esc(finding.page)}</code>` : '<span class="muted">—</span>'}</td>
<td><b>${esc(finding.message)}</b>${finding.resource ? `<br><span class="muted">${esc(ui.resource)}: ${esc(finding.resource)}</span>` : ''}${
    finding.evidence ? `<span class="ev" title="${esc(finding.evidence)}">${esc(ui.evidence)}: ${esc(finding.evidence)}</span>` : ''
  }</td>
<td class="ev">${finding.fix ? esc(finding.fix) : '<span class="muted">—</span>'}</td>
<td class="nowrap">${ownTag(finding.ownership)}</td></tr>`;
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
<ul class="changes">${list(t.improved, cmp.resolved, 'ok')}${list(t.regressed, cmp.added, 'bad')}${list(t.carried, cmp.carried, 'mid')}</ul>`;
  };

  // The detail groups by category when the run carries one, and falls back to a single
  // group so a run without categories still lists every finding.
  const byCategory = model.byCategory.size ? model.byCategory : new Map([[null, model.plan]]);
  const groups = [...byCategory]
    .map(([name, list], i) => {
      const n = counts(list);
      return `<details class="group" id="cat-${slug(name || 'all')}"${i === 0 ? ' open' : ''}>
<summary><b>${esc(name ? categoryName(name) : t.plan)}</b> <span class="pill">${n.total} ${esc(ui.findings)}</span>${
        n.CRITICAL ? ` <span class="pill bad">${n.CRITICAL} ${esc(ui.critical)}</span>` : ''
      }${n.WARNING ? ` <span class="pill mid">${n.WARNING} ${esc(ui.warnings)}</span>` : ''}</summary>
${findingTable(sortForPlan(list))}</details>`;
    })
    .join('\n');

  const unmeasuredBlock = model.unmeasured.length
    ? `<p>${esc(t.unmeasuredNote)}</p><div class="scroll"><table><thead><tr><th>${esc(t.code)}</th><th></th><th>${esc(
        t.problem,
      )}</th></tr></thead><tbody>${model.unmeasured
        .map(
          (entry) =>
            `<tr><td class="num">${esc(entry.check)}</td><td><span class="chip unmeasured">${esc(t.unmeasured)}</span></td><td class="ev">${esc(
              entry.reason || entry.message || '',
            )}</td></tr>`,
        )
        .join('')}</tbody></table></div>`
    : `<p>${esc(t.none)}</p>`;

  const toc = [
    ['summary', t.summary],
    ['comparison', t.comparison],
    model.byCategory.size ? ['by-category', t.byCategory] : null,
    model.byPage.size ? ['by-page', t.byPage] : null,
    ['plan', t.plan],
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
<style>${HTML_CSS}</style>
</head>
<body>
<input type="checkbox" id="theme" class="sr">
<header class="top"><div class="wrap">
<p class="kicker">${esc(ui.kicker)}</p>
<h1>${esc(model.site)}</h1>
<p class="meta">${esc([model.date, model.tier].filter(Boolean).join(' · '))}</p>
${model.categories.length ? `<p class="meta">${esc(t.categories)}: ${esc(model.categories.map(categoryName).join(', '))}</p>` : ''}
<div class="kpis">
<div class="kpi big"><b>${c.total}</b><span>${esc(ui.findings)}</span></div>
<div class="kpi"><b class="bad">${c.CRITICAL}</b><span>${esc(ui.critical)}</span></div>
<div class="kpi"><b class="mid">${c.WARNING}</b><span>${esc(ui.warnings)}</span></div>
<div class="kpi"><b>${c.INFO}</b><span>${esc(ui.info)}</span></div>
<div class="kpi"><b class="info">${model.unmeasured.length}</b><span>${esc(ui.unmeasured)}</span></div>
</div></div></header>
<nav class="toc"><div class="wrap">${toc.map(([id, label]) => `<a href="#${id}">${esc(label)}</a>`).join('')}
<label class="theme" for="theme"><span class="to-dark">🌙 ${esc(ui.dark)}</span><span class="to-light">☀️ ${esc(ui.light)}</span></label></div></nav>
<main class="wrap">
<section id="summary"><h2>${esc(t.summary)}</h2>
<p>${esc(scoreSentence(t, c))}</p>
<p>${esc(fill(t.ownershipCounts, model.ownership))}</p></section>
<section id="comparison"><h2>${esc(t.comparison)}</h2>${comparisonBlock()}</section>
${groupTable(t.byCategory, 'by-category', model.byCategory, t.category, (name) => `<a href="#cat-${slug(name)}">${esc(categoryName(name))}</a>`)}
${groupTable(t.byPage, 'by-page', model.byPage, t.page, (name) => `<code>${esc(name)}</code>`)}
<section id="plan"><h2>${esc(t.plan)}</h2>
<div class="filters" role="radiogroup" aria-label="${esc(ui.show)}"><span>${esc(ui.show)}</span>
<input type="radio" name="filter" id="filter-all" class="sr" checked><label for="filter-all">${esc(ui.all)}</label>
<input type="radio" name="filter" id="filter-critical" class="sr"><label for="filter-critical">${esc(ui.onlyCritical)}</label>
<input type="radio" name="filter" id="filter-problems" class="sr"><label for="filter-problems">${esc(ui.criticalAndWarnings)}</label></div>
${groups}
<p>${esc(fill(t.ownershipCounts, model.ownership))}</p>
<p class="note">${esc(t.settingWarning.replaceAll('**', '').replaceAll('`', ''))}</p></section>
<section id="unmeasured"><h2>${esc(t.unmeasured)}</h2>${unmeasuredBlock}</section>
<section id="legend"><h2>${esc(ui.legend)}</h2><ul class="legend">
<li><b>${esc(ui.legendSeverity)}:</b> ${['CRITICAL', 'WARNING', 'INFO'].map(sevChip).join(' ')}</li>
<li><b>${esc(ui.legendOwner)}:</b><ul>${OWNERSHIP.map((owner) => `<li>${ownTag(owner)} ${esc(ui.ownerHelp[owner])}</li>`).join('')}</ul></li>
</ul></section>
</main>
<footer class="wrap"><p>${esc(`${t.title} · ${model.site} · ${model.date}`)}</p></footer>
</body>
</html>
`;
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const run = opts.merge.length
    ? mergeRuns(loadRun(opts.run), opts.merge.map(loadRun))
    : loadRun(opts.run);
  const findings = run.findings;

  if (findings.length === 0 && !(run.unmeasured || []).length) {
    console.log('audit-report: the run carries no findings — nothing to write');
    process.exit(2);
  }

  const problems = [
    ...validate(findings),
    ...validateUnmeasured(Array.isArray(run.unmeasured) ? run.unmeasured : []),
  ];
  if (problems.length) {
    die(1, `audit-report: ${problems.length} finding(s) cannot be rendered:\n  ${problems.join('\n  ')}`);
  }

  const date = opts.date || run.date || new Date().toISOString().slice(0, 10);
  const outDir = opts.out;
  mkdirSync(outDir, { recursive: true });

  const sidecarPath = join(outDir, `informe-${date}.json`);
  const previous = findPrevious(outDir, sidecarPath);

  const model = {
    lang: opts.lang,
    t: STRINGS[opts.lang],
    site: run.site || run.project || 'site',
    date,
    tier: run.tier || null,
    categories: Array.isArray(run.categories) ? run.categories : [],
    counts: counts(findings),
    ownership: ownershipCounts(findings),
    byCategory: groupBy(findings, 'category'),
    byPage: groupBy(findings, 'page'),
    plan: sortForPlan(findings),
    unmeasured: Array.isArray(run.unmeasured) ? run.unmeasured : [],
    comparison: compare(findings, previous),
  };

  const written = [];
  if (opts.format === 'md' || opts.format === 'both') {
    const path = join(outDir, `informe-${date}.md`);
    writeFileSync(path, renderMarkdown(model));
    written.push(path);
  }
  if (opts.format === 'html' || opts.format === 'both') {
    const path = join(outDir, `informe-${date}.html`);
    writeFileSync(path, renderHtml(model));
    written.push(path);
  }

  // The sidecar is written last and holds exactly what the next run diffs against. It is
  // not the ledger: the ledger is the project's running record of every finding ever seen,
  // this is one dated snapshot of one run.
  writeFileSync(
    sidecarPath,
    `${JSON.stringify(
      {
        report_version: 1,
        date,
        site: model.site,
        tier: model.tier,
        categories: model.categories,
        unmeasured: model.unmeasured.map((entry) => ({ check: entry.check, reason: entry.reason || null })),
        findings: findings.map((finding) => ({
          check: finding.check,
          resource: finding.resource || null,
          severity: finding.severity,
          ownership: finding.ownership,
          category: finding.category || null,
          page: finding.page || null,
          message: finding.message,
          evidence: finding.evidence || null,
        })),
      },
      null,
      2,
    )}\n`,
  );
  written.push(sidecarPath);

  for (const path of written) console.log(`audit-report: wrote ${path}`);
  process.exit(0);
}

try {
  main();
} catch (error) {
  console.error(`audit-report: ${error.stack || error.message}`);
  process.exit(3);
}
