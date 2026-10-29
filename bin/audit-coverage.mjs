#!/usr/bin/env node
// /wp-audit Step 6.8: how much of each agent's catalog did the run actually execute?
//
// The gate used to be prose ("compute executed ∩ catalog / catalog, re-dispatch under 90%").
// One run skipped it outright, others recomputed it with ad-hoc regexes over the catalogs,
// and the first dispatch never handed an agent its exact list of ids, so a category came
// back at 38/61 and cost two extra agents. This script is the gate: it reads the catalogs
// from the agents' own files, the run's per-agent `checks_executed`, and prints the number.
//
// Usage:
//   bin/audit-coverage.mjs --results <dir|file> [--categories a,b] [--threshold 90]
//                          [--final] [--json]
//   bin/audit-coverage.mjs --list <category> [--results <dir|file>] [--json]
//
// --results   a directory of agent report JSON files (one per agent or shard), or one file.
//             A report is { category, checks_executed[], findings[] } as the standards skill
//             defines; shards of one category are unioned. Aliased keys are accepted
//             (bin/lib/audit-schema.mjs).
// --list      print the category's catalog ids, comma-separated -- the exact must-run list a
//             first dispatch hands the agent. With --results it prints only the ids still
//             missing, which is what a re-dispatch sends and nothing else.
// --threshold percent of the catalog that must have executed (default 90).
// --final     the second pass, after the re-dispatch: exit 1 only if some missing id has no
//             allowed blocker (the run is INCOMPLETE), not because the percent is low.
//
// What counts, per catalog id:
//   executed   in checks_executed, or reported PASS / FAIL
//   n/a        reported N/A with a reason: out of the denominator (site type, clone)
//   blocked    reported UNMEASURED with an allowed reason (credentials, network or a third
//              party, production, a tier the run lacks): listed, not executed
//   missing    everything else -- never reported, N/A or UNMEASURED with no reason, or an
//              UNMEASURED reason that is not allowed ("not measured in this run", "not run",
//              "clone"): that is measurable with tools already present
//
// Exit: 0 gate passed, 1 below the threshold (or INCOMPLETE with --final), 2 invalid input
// (including an agent report the normalizer rejects), 3 crash.

import { existsSync } from 'node:fs';
import {
  CATALOGS, canonicalCategory, readCatalog, loadReports, normalizeReport, classifyUnmeasured,
} from './lib/audit-schema.mjs';

function die(code, message) { console.error(`audit-coverage: ${message}`); process.exit(code); }

function parseArgs(argv) {
  const opts = { results: null, categories: null, threshold: 90, final: false, json: false, list: null };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    const value = argv[i + 1];
    const need = () => { if (value === undefined || value.startsWith('--')) die(2, `${flag} needs a value`); i += 1; return value; };
    switch (flag) {
      case '--results': opts.results = need(); break;
      case '--categories': opts.categories = need().split(',').map((c) => c.trim()).filter(Boolean); break;
      case '--list': opts.list = need(); break;
      case '--threshold': {
        const n = Number(need());
        if (!Number.isFinite(n) || n < 0 || n > 100) die(2, `--threshold must be 0-100 (got: ${value})`);
        opts.threshold = n; break;
      }
      case '--final': opts.final = true; break;
      case '--json': opts.json = true; break;
      default: die(2, `unknown argument: ${flag}`);
    }
  }
  return opts;
}

function measure(category, catalog, reports) {
  const executed = new Set();
  const na = new Map();
  const unmeasured = new Map();
  const problems = [];
  for (const { label, report } of reports) {
    const n = normalizeReport(report, label);
    problems.push(...n.problems);
    n.executed.forEach((id) => executed.add(id));
    n.passes.forEach((p) => executed.add(p.check));
    n.findings.forEach((f) => executed.add(f.check));
    n.na.forEach((e) => { if (typeof e.reason === 'string' && e.reason.trim()) na.set(e.check, e.reason); });
    n.unmeasured.forEach((e) => unmeasured.set(e.check, e.reason));
  }
  const base = (id) => id.replace(/@\d+$/, '');
  const inCatalog = (id) => catalog.includes(id) || catalog.some((c) => base(c) === base(id) && (c === id || !/@/.test(id)));
  const rows = { executed: [], na: [], blocked: [], missing: [] };
  for (const id of catalog) {
    const hit = (set) => set.has(id) || set.has(base(id));
    if (hit(executed)) rows.executed.push(id);
    else if (na.has(id) || na.has(base(id))) rows.na.push(id);
    else if (hit(unmeasured)) {
      const reason = unmeasured.get(id) ?? unmeasured.get(base(id));
      const kind = classifyUnmeasured(reason);
      if (kind) rows.blocked.push({ id, kind, reason });
      else rows.missing.push({ id, why: reason ? `UNMEASURED reason not allowed: "${reason}"` : 'UNMEASURED with no reason' });
    } else rows.missing.push({ id, why: 'never reported' });
  }
  const total = catalog.length - rows.na.length;
  const pct = total === 0 ? 100 : Math.floor((rows.executed.length / total) * 1000) / 10;
  const extra = [...executed].filter((id) => !inCatalog(id));
  return {
    category, executed: rows.executed.length, total, na: rows.na.length, percent: pct,
    never_run: rows.missing.map((m) => m.id), missing: rows.missing, blocked: rows.blocked,
    not_in_catalog: extra, problems,
  };
}

function main() {
  const opts = parseArgs(process.argv.slice(2));

  if (opts.list) {
    const category = canonicalCategory(opts.list);
    if (!category) die(2, `unknown category "${opts.list}" -- one of ${Object.keys(CATALOGS).join(', ')}`);
    let ids = readCatalog(category);
    if (opts.results) {
      if (!existsSync(opts.results)) die(2, `--results ${opts.results} does not exist`);
      const reports = loadReports(opts.results).filter(({ report }) => canonicalCategory(report?.category ?? report?.agent ?? '') === category);
      ids = measure(category, ids, reports).never_run;
    }
    console.log(opts.json ? JSON.stringify({ category, ids }) : ids.join(','));
    process.exit(0);
  }

  if (!opts.results) die(2, '--results <dir|file> is required (or --list <category>)');
  if (!existsSync(opts.results)) die(2, `--results ${opts.results} does not exist`);
  const reports = loadReports(opts.results);
  const byCategory = new Map();
  for (const item of reports) {
    const category = canonicalCategory(item.report?.category ?? item.report?.agent ?? '');
    if (!category) die(2, `${item.label} has no recognisable "category" (one of ${Object.keys(CATALOGS).join(', ')})`);
    if (!byCategory.has(category)) byCategory.set(category, []);
    byCategory.get(category).push(item);
  }
  const wanted = opts.categories ? opts.categories.map((c) => canonicalCategory(c) ?? die(2, `unknown category "${c}"`)) : [...byCategory.keys()];
  const results = wanted.map((category) => measure(category, readCatalog(category), byCategory.get(category) || []));

  const below = results.filter((r) => r.percent < opts.threshold);
  const incomplete = results.filter((r) => r.missing.length > 0);
  const failed = opts.final ? incomplete.length > 0 : below.length > 0;
  const status = failed ? (opts.final ? 'INCOMPLETE' : 'BELOW_THRESHOLD') : 'OK';

  if (opts.json) {
    console.log(JSON.stringify({ threshold: opts.threshold, final: opts.final, status, categories: results }, null, 2));
  } else {
    for (const r of results) {
      const flag = r.percent < opts.threshold ? ' [below threshold]' : '';
      console.log(`${r.category} ${r.executed}/${r.total} checks executed (${r.percent}%)${flag}${r.never_run.length ? ` — never run: ${r.never_run.join(', ')}` : ''}`);
      if (r.na) console.log(`  n/a (out of the denominator): ${r.na}`);
      for (const b of r.blocked) console.log(`  blocked ${b.id}: ${b.kind} — ${b.reason}`);
      for (const m of r.missing.filter((x) => x.why !== 'never reported')) console.log(`  missing ${m.id}: ${m.why}`);
      if (r.not_in_catalog.length) console.log(`  not in the catalog (ignored): ${r.not_in_catalog.join(', ')}`);
      for (const p of r.problems) console.log(`  problem: ${p}`);
    }
    console.log(`coverage: ${status} (threshold ${opts.threshold}%${opts.final ? ', final pass' : ''})`);
  }
  // A report the normalizer rejects (a finding with no catalog id, a code both failed and
  // passed) is invalid input, not a coverage number: say so after the numbers.
  const problems = results.flatMap((r) => r.problems);
  if (problems.length) {
    console.error(`audit-coverage: ${problems.length} problem(s) in the agent reports -- fix the reports and run again`);
    process.exit(2);
  }
  process.exit(failed ? 1 : 0);
}

try { main(); } catch (error) {
  console.error(`audit-coverage: ${error.stack || error.message}`);
  process.exit(3);
}
