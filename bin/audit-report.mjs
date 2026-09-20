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
// the code. The loser's check id is kept in the winner's evidence, so the ledger still shows
// it ran.
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
  const byIdentity = new Map(base.findings.map((finding) => [identity(finding), finding]));
  const merged = [...base.findings];
  const unmeasured = [...(Array.isArray(base.unmeasured) ? base.unmeasured : [])];
  const seenUnmeasured = new Set(unmeasured.map((entry) => entry.check));
  let superseded = 0;

  for (const extra of extras) {
    for (const finding of extra.findings) {
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
      winner.evidence = [winner.evidence, `superseded ${loser.check}`].filter(Boolean).join(' — ');
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
function renderHtml(model) {
  const t = model.t;
  const row = (cells, tag = 'td') =>
    `<tr>${cells.map((cell) => `<${tag}>${cell}</${tag}>`).join('')}</tr>`;

  const planRows = model.plan
    .map((finding) =>
      row([
        `<span class="sev sev--${finding.severity.toLowerCase()}">${escapeHtml(t.severity[finding.severity])}</span>`,
        `<code>${escapeHtml(identity(finding))}</code>`,
        escapeHtml(finding.page || '—'),
        escapeHtml(finding.message),
        escapeHtml(finding.fix || '—'),
        `<span class="own own--${finding.ownership}">${escapeHtml(t.ownership[finding.ownership])}</span>`,
      ]),
    )
    .join('\n');

  const groupTable = (heading, groups, label) => {
    if (!groups.size) return '';
    const body = [...groups]
      .map(([name, list]) => {
        const c = counts(list);
        return row([escapeHtml(name), c.CRITICAL, c.WARNING, c.INFO]);
      })
      .join('\n');
    return `<h2>${escapeHtml(heading)}</h2>
<table><thead>${row(
      [label, t.severity.CRITICAL, t.severity.WARNING, t.severity.INFO].map(escapeHtml),
      'th',
    )}</thead><tbody>
${body}
</tbody></table>`;
  };

  const comparisonBlock = () => {
    if (!model.comparison) return `<p>${escapeHtml(t.noPrevious)}</p>`;
    const c = model.comparison;
    const list = (label, items) =>
      `<li><strong>${escapeHtml(label)}:</strong> ${items.length}<ul>${sortForPlan(items)
        .map((finding) => `<li><code>${escapeHtml(identity(finding))}</code> — ${escapeHtml(finding.message)}</li>`)
        .join('')}</ul></li>`;
    return `<p><strong>${escapeHtml(t.previousRun)}:</strong> ${escapeHtml(c.date)} — ${escapeHtml(
      scoreSentence(t, c.counts)
      + (c.unmeasured ? fill(t.previousUnmeasured, { unmeasured: c.unmeasured }) : ''),
    )}</p>
<ul>${list(t.improved, c.resolved)}${list(t.regressed, c.added)}${list(t.carried, c.carried)}</ul>`;
  };

  const unmeasuredBlock = model.unmeasured.length
    ? `<p>${escapeHtml(t.unmeasuredNote)}</p><ul>${model.unmeasured
        .map((entry) => `<li><code>${escapeHtml(entry.check)}</code> — ${escapeHtml(entry.reason || entry.message || '')}</li>`)
        .join('')}</ul>`
    : `<p>${escapeHtml(t.none)}</p>`;

  return `<!DOCTYPE html>
<html lang="${model.lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(`${t.title} — ${model.site} — ${model.date}`)}</title>
<style>
  :root {
    --ink: #16191d;
    --muted: #5b6470;
    --rule: #dfe3e8;
    --canvas: #ffffff;
    --critical: #b3261e;
    --warning: #8a5a00;
    --info: #3c4650;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0 auto;
    padding: 2.5rem 1rem 4rem;
    max-width: 62rem;
    background: var(--canvas);
    color: var(--ink);
    font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  }
  h1 { font-size: 1.9rem; margin: 0 0 .5rem; }
  h2 { font-size: 1.25rem; margin: 2.5rem 0 .75rem; padding-bottom: .3rem; border-bottom: 1px solid var(--rule); }
  code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: .875em; }
  dl.meta { display: grid; grid-template-columns: max-content 1fr; gap: .25rem 1rem; margin: 0 0 1.5rem; }
  dl.meta dt { color: var(--muted); }
  dl.meta dd { margin: 0; }
  table { width: 100%; border-collapse: collapse; margin: 1rem 0; font-size: .9375rem; }
  th, td { text-align: left; padding: .5rem .6rem; border-bottom: 1px solid var(--rule); vertical-align: top; }
  th { font-size: .8125rem; text-transform: uppercase; letter-spacing: .04em; color: var(--muted); }
  .sev { font-weight: 600; }
  .sev--critical { color: var(--critical); }
  .sev--warning { color: var(--warning); }
  .sev--info { color: var(--info); }
  .own { white-space: nowrap; }
  blockquote { margin: 1rem 0; padding: .75rem 1rem; border-left: 3px solid var(--rule); color: var(--muted); }
  ul ul { color: var(--muted); }
  @media print {
    body { padding: 0; max-width: none; font-size: 11pt; }
    h2 { break-after: avoid; }
    tr { break-inside: avoid; }
  }
</style>
</head>
<body>
<h1>${escapeHtml(`${t.title} — ${model.site}`)}</h1>
<dl class="meta">
  <dt>${escapeHtml(t.date)}</dt><dd>${escapeHtml(model.date)}</dd>
  ${model.tier ? `<dt>${escapeHtml(t.tier)}</dt><dd>${escapeHtml(model.tier)}</dd>` : ''}
  ${model.categories.length ? `<dt>${escapeHtml(t.categories)}</dt><dd>${escapeHtml(model.categories.join(', '))}</dd>` : ''}
</dl>

<h2>${escapeHtml(t.summary)}</h2>
<p>${escapeHtml(scoreSentence(t, model.counts))}</p>
<p>${escapeHtml(fill(t.ownershipCounts, model.ownership))}</p>

<h2>${escapeHtml(t.comparison)}</h2>
${comparisonBlock()}

${groupTable(t.byCategory, model.byCategory, t.category)}
${groupTable(t.byPage, model.byPage, t.page)}

<h2>${escapeHtml(t.plan)}</h2>
<table><thead>${row(
    [t.priority, t.code, t.page, t.problem, t.todo, t.applied].map(escapeHtml),
    'th',
  )}</thead><tbody>
${planRows}
</tbody></table>
<p>${escapeHtml(fill(t.ownershipCounts, model.ownership))}</p>
<blockquote>${escapeHtml(t.settingWarning.replaceAll('**', ''))}</blockquote>

<h2>${escapeHtml(t.unmeasured)}</h2>
${unmeasuredBlock}
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
