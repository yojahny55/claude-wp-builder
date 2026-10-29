// The audit finding schema, the check catalogs and the UNMEASURED reason vocabulary, in one
// place, so that bin/audit-report.mjs (aggregation) and bin/audit-coverage.mjs (Step 6.8)
// read an agent's report the same way.
//
// Why a module and not prose alone: seven agents each drifted into their own key names
// (`code` for `check`, `owner` for `ownership`, `fix: "auto"` for `auto_fixable`), and the
// parent wrote a throwaway script per run to map them back. The canonical schema is
// skills/wp-audit-standards/SKILL.md ("Report contract"); the alias table below is the only
// place the drift is tolerated, and it is listed there too.

import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const PLUGIN_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');

export const SEVERITIES = ['CRITICAL', 'WARNING', 'INFO'];
export const OWNERSHIPS = ['code', 'setting', 'content', 'manual'];
export const STATUSES = ['PASS', 'FAIL', 'UNMEASURED', 'N/A'];

// key a report may carry -> the canonical key. Order matters only when two aliases of one
// key are present: the canonical key always wins, then the first alias listed.
export const KEY_ALIASES = {
  check: ['code', 'id', 'check_id', 'check_code', 'checkId'],
  ownership: ['owner', 'fix_owner', 'fixOwner'],
  message: ['title', 'description', 'summary', 'problem'],
  fix: ['method', 'remediation'],
  evidence: ['proof', 'measurement'],
  root_cause: ['rootCause', 'root-cause', 'cause'],
  design_impact: ['designImpact', 'design-impact'],
  status: ['result', 'outcome'],
  reason: ['why', 'blocker'],
};

const SEVERITY_ALIASES = {
  CRITICAL: 'CRITICAL', ERROR: 'CRITICAL', HIGH: 'CRITICAL', BLOCKER: 'CRITICAL',
  WARNING: 'WARNING', WARN: 'WARNING', MEDIUM: 'WARNING', MAJOR: 'WARNING',
  INFO: 'INFO', INFORMATIONAL: 'INFO', LOW: 'INFO', NOTE: 'INFO', MINOR: 'INFO',
};
const STATUS_ALIASES = {
  PASS: 'PASS', PASSED: 'PASS', OK: 'PASS',
  FAIL: 'FAIL', FAILED: 'FAIL', FINDING: 'FAIL',
  UNMEASURED: 'UNMEASURED', 'NOT MEASURED': 'UNMEASURED', SKIPPED: 'UNMEASURED',
  'N/A': 'N/A', NA: 'N/A', 'NOT APPLICABLE': 'N/A',
};

const EXEMPT_ID = /^(A11Y-AXE|PERF-LH)-/; // browser-suite evidence rows, not catalog criteria
// An id this plugin's catalogs would own; anything else (a suite metric, a custom row) is not
// checked against them.
const CATALOG_SHAPED = /^(SEC|SEO|A11Y|PERF|WP|UX)-\d+(@\d+)?$|^GEO-[DAUP]\d+(@\d+)?$/;

export const CATALOGS = {
  security: 'agents/wp-audit-security.md',
  seo: 'agents/wp-audit-seo.md',
  a11y: 'agents/wp-audit-a11y.md',
  performance: 'agents/wp-audit-performance.md',
  'best-practices': 'agents/wp-audit-practices.md',
  geo: 'agents/wp-audit-geo.md',
  usability: 'skills/wp-audit-ux-standards/SKILL.md',
};
// Names agents and run files use for a category -> the catalog key.
const CATEGORY_ALIASES = {
  practices: 'best-practices', 'best practices': 'best-practices', bestpractices: 'best-practices', wp: 'best-practices',
  accessibility: 'a11y', ux: 'usability', perf: 'performance', sec: 'security',
};
export function canonicalCategory(name) {
  if (typeof name !== 'string') return null;
  const key = name.trim().toLowerCase().replace(/^wp-audit-/, '');
  const mapped = CATEGORY_ALIASES[key] ?? key;
  return CATALOGS[mapped] ? mapped : null;
}

const ID_CELL = /^`?((?:SEC|SEO|A11Y|PERF|WP|UX)-\d+(?:@\d+)?|GEO-[DAUP]\d+(?:@\d+)?)`?$/;

// The ids in a catalog: the first cell of every table row whose first cell is a check id.
// Read from the agent's own file (and, for usability, its standards skill) -- never from a
// copy, because a stored list that drifts reports green coverage for checks nobody ran.
export function readCatalog(category, root = PLUGIN_ROOT) {
  const rel = CATALOGS[category];
  if (!rel) throw new Error(`unknown audit category: ${category}`);
  const path = join(root, rel);
  const ids = [];
  for (const line of readFileSync(path, 'utf8').split('\n')) {
    if (!line.startsWith('|')) continue;
    const cell = line.split('|')[1]?.trim() ?? '';
    const m = ID_CELL.exec(cell);
    if (m && !ids.includes(m[1])) ids.push(m[1]);
  }
  return ids;
}

// Reasons that keep an UNMEASURED check out of the "missing" list (Step 6.8, point 2).
// Anything else -- "not measured in this run", "not run", "no browser measurement", "clone",
// an empty reason -- is measurable with tools already present and counts as missing.
export const ALLOWED_UNMEASURED = [
  { key: 'credentials', re: /credential|password|log-?in|api[ -]?key|token|authenticat|secret/i },
  { key: 'network', re: /network|third[- ]party|external (service|api|tool)|rate[- ]limit|quota|offline|dns/i },
  { key: 'production', re: /production|public url|prod[- ]gate|gate busy|host (is )?blocked|waf|live host/i },
  { key: 'tier', re: /needs? (a )?tier|tier [123] (is |was )?(not |un)?(available|run|reachable)|no tier [123]|tier [123] never ran|no wp-cli|no (browser tool and no suite)|no node/i },
];
export function classifyUnmeasured(reason) {
  if (typeof reason !== 'string' || !reason.trim()) return null;
  for (const { key, re } of ALLOWED_UNMEASURED) if (re.test(reason)) return key;
  return null;
}

function pick(obj, canonical) {
  if (obj[canonical] !== undefined) return obj[canonical];
  for (const alias of KEY_ALIASES[canonical] || []) if (obj[alias] !== undefined) return obj[alias];
  return undefined;
}

// Normalize one entry (a finding, a pass, an UNMEASURED/N-A row) to canonical keys.
// Returns { entry, notes } where notes lists the aliases it had to translate. Does not
// judge validity; validateFinding does.
export function normalizeEntry(raw) {
  const notes = [];
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return { entry: raw, notes };
  const entry = { ...raw };
  for (const canonical of Object.keys(KEY_ALIASES)) {
    if (entry[canonical] === undefined) {
      for (const alias of KEY_ALIASES[canonical]) {
        if (entry[alias] !== undefined) { entry[canonical] = entry[alias]; notes.push(`${alias} -> ${canonical}`); break; }
      }
    }
    for (const alias of KEY_ALIASES[canonical]) delete entry[alias];
  }
  // `Fix: auto|manual` (the dispatch line) and `fix: true` mean auto_fixable, not the fix text.
  if (entry.fix === true || entry.fix === false || /^(auto|manual)$/i.test(String(entry.fix ?? ''))) {
    if (entry.auto_fixable === undefined) entry.auto_fixable = entry.fix === true || /^auto$/i.test(String(entry.fix));
    notes.push('fix (auto|manual|boolean) -> auto_fixable');
    delete entry.fix;
  }
  if (typeof entry.check === 'string') entry.check = entry.check.trim();
  if (typeof entry.severity === 'string') {
    const mapped = SEVERITY_ALIASES[entry.severity.trim().toUpperCase()];
    if (mapped) { if (mapped !== entry.severity) notes.push(`severity ${entry.severity} -> ${mapped}`); entry.severity = mapped; }
  }
  if (typeof entry.ownership === 'string') entry.ownership = entry.ownership.trim().toLowerCase();
  if (typeof entry.status === 'string') {
    const mapped = STATUS_ALIASES[entry.status.trim().toUpperCase()];
    if (mapped) entry.status = mapped;
  }
  if (typeof entry.design_impact === 'string') entry.design_impact = entry.design_impact.trim().toLowerCase() === 'true';
  return { entry, notes };
}

const catalogCache = new Map();
export function catalogIds(root = PLUGIN_ROOT) {
  if (catalogCache.has(root)) return catalogCache.get(root);
  const all = new Set();
  for (const category of Object.keys(CATALOGS)) {
    if (!existsSync(join(root, CATALOGS[category]))) continue;
    for (const id of readCatalog(category, root)) all.add(id);
  }
  catalogCache.set(root, all);
  return all;
}

// Problems with one FAIL finding beyond the renderer's own required-field rules: a check id
// that is catalog-shaped but absent from every catalog is an invented code.
export function catalogProblem(check, root = PLUGIN_ROOT) {
  if (typeof check !== 'string' || EXEMPT_ID.test(check) || !CATALOG_SHAPED.test(check)) return null;
  const ids = catalogIds(root);
  if (ids.size === 0 || ids.has(check)) return null;
  // `SEC-040` is also satisfied by a catalog row spelled `SEC-040@2` and the reverse.
  const base = check.replace(/@\d+$/, '');
  for (const id of ids) if (id.replace(/@\d+$/, '') === base) return null;
  return `check "${check}" is not in any audit catalog -- a finding carries the catalog's own id`;
}

// Normalize one agent report object ({category, checks_executed, findings[], passes?}) and
// return { category, executed[], findings[] (FAIL), unmeasured[], na[], passes[], problems[], notes[] }.
export function normalizeReport(report, label = 'report') {
  const problems = [];
  const notes = [];
  const out = { category: null, executed: [], findings: [], unmeasured: [], na: [], passes: [], problems, notes };
  if (!report || typeof report !== 'object' || Array.isArray(report)) {
    problems.push(`${label} is not an object`);
    return out;
  }
  out.category = canonicalCategory(report.category ?? report.agent ?? '') ?? null;
  const exec = report.checks_executed ?? report.checksExecuted ?? [];
  if (!Array.isArray(exec)) problems.push(`${label} "checks_executed" must be an array of check ids`);
  else out.executed = exec.filter((x) => typeof x === 'string').map((x) => x.trim());
  const listed = (key) => (Array.isArray(report[key]) ? report[key] : []);
  const passList = [...listed('passes'), ...listed('checks_passed'), ...listed('passed')];
  for (const item of passList) {
    const { entry } = normalizeEntry(typeof item === 'string' ? { check: item, status: 'PASS' } : item);
    if (entry && typeof entry.check === 'string') out.passes.push({ check: entry.check, resource: entry.resource ?? null });
  }
  const sources = [
    [listed('findings'), 'findings', 'FAIL'],
    [listed('unmeasured'), 'unmeasured', 'UNMEASURED'],
    [listed('not_applicable'), 'not_applicable', 'N/A'],
  ];
  for (const [rows, key, fallback] of sources) {
    rows.forEach((raw, index) => {
      const { entry, notes: n } = normalizeEntry(raw);
      notes.push(...n);
      const where = `${label} ${key}[${index}]`;
      if (!entry || typeof entry !== 'object' || Array.isArray(entry)) { problems.push(`${where} is not an object`); return; }
      if (typeof entry.check !== 'string' || !entry.check) { problems.push(`${where} has no "check" id (aliases accepted: ${KEY_ALIASES.check.join(', ')})`); return; }
      if (entry.status !== undefined && !STATUSES.includes(entry.status)) { problems.push(`${entry.check} has status "${entry.status}" -- expected ${STATUSES.join(', ')}`); return; }
      const status = entry.status ?? fallback;
      if (status === 'PASS') out.passes.push({ check: entry.check, resource: entry.resource ?? null });
      else if (status === 'UNMEASURED') out.unmeasured.push({ check: entry.check, reason: entry.reason ?? null });
      else if (status === 'N/A') out.na.push({ check: entry.check, reason: entry.reason ?? null });
      else {
        const problem = catalogProblem(entry.check);
        if (problem) problems.push(`${entry.check}: ${problem}`);
        if (out.category && !entry.category) entry.category = out.category;
        out.findings.push(entry);
      }
    });
  }
  // The same check listed as a pass and as a failure of the same thing is an agent that
  // could not decide; refusing it here is cheaper than a report that says both.
  for (const finding of out.findings) {
    const clash = out.passes.find((p) => p.check === finding.check && (p.resource ?? null) === (finding.resource ?? null));
    const bare = out.passes.find((p) => p.check === finding.check && p.resource === null);
    if (clash || bare) problems.push(`${finding.check} is reported both as a finding and as a pass -- one or the other`);
  }
  return out;
}

// A directory of agent reports (*.json) or a single file; a file may hold one report or an
// array of them (shards of one category). Returns [{ label, report }].
export function loadReports(path) {
  const files = [];
  const st = statSync(path);
  if (st.isDirectory()) {
    for (const name of readdirSync(path).sort()) if (name.endsWith('.json') && name !== 'run-state.json') files.push(join(path, name));
  } else files.push(path);
  const out = [];
  for (const file of files) {
    let data;
    try { data = JSON.parse(readFileSync(file, 'utf8')); } catch (error) { throw new Error(`${file} is not valid JSON: ${error.message}`); }
    if (Array.isArray(data)) data.forEach((r, i) => out.push({ label: `${file}[${i}]`, report: r }));
    else if (data && typeof data === 'object' && !Array.isArray(data.findings) && !data.checks_executed && typeof data === 'object' && Object.values(data).every((v) => v && typeof v === 'object')) {
      // { security: {...}, seo: {...} }
      for (const [key, value] of Object.entries(data)) out.push({ label: `${file}#${key}`, report: { category: key, ...value } });
    } else out.push({ label: file, report: data });
  }
  return out;
}
