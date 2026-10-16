// @ts-check
// Reporter de Playwright de la suite de regresion: recoge PASS/FAIL/SKIP por flujo y
// proyecto y escribe results/regression/<etiqueta>.json y .md. La etiqueta sale de
// REGRESSION_LABEL (p. ej. "before" / "after"); sin ella, "latest".
const fs = require('fs');
const path = require('path');
const { renderMarkdown, tally } = require('./helpers');

class RegressionReporter {
  constructor(options = {}) {
    this.outDir = options.outDir || path.join(process.cwd(), 'results', 'regression');
    this.rows = new Map();
    this.sweep = [];
    this.meta = {};
  }

  onTestEnd(test, result) {
    const m = test.title.match(/^\[([^\]]+)\] (.*?)(?: @regression)?$/);
    if (!m) return;
    const project = test.parent.project()?.name || 'unknown';
    const note = (type) => result.annotations.filter((a) => a.type === type).map((a) => a.description || '');
    const status = result.status === 'passed' ? 'PASS' : result.status === 'skipped' ? 'SKIP' : 'FAIL';
    let evidence = note('evidence').join(' | ');
    if (status === 'SKIP') evidence = note('skip')[0] || test.annotations.filter((a) => a.type === 'skip').map((a) => a.description).join(' ') || evidence;
    if (status === 'FAIL') {
      const err = (result.error && (result.error.message || String(result.error))) || result.status;
      const first = String(err).replace(/\u001b\[[0-9;]*m/g, '').split('\n').find((l) => l.trim()) || '';
      evidence = `${first.slice(0, 400)}${evidence ? ' | ' + evidence : ''}`;
    }
    const meta = note('meta')[0];
    if (meta) { try { Object.assign(this.meta, JSON.parse(meta)); } catch { /* ignorado */ } }
    for (const s of note('sweep')) { try { this.sweep.push({ project, ...JSON.parse(s) }); } catch { /* ignorado */ } }
    // un reintento sustituye al intento anterior del mismo flujo
    this.rows.set(`${project}::${m[1]}`, { id: m[1], title: m[2], project, status, evidence, ms: result.duration });
  }

  onEnd() {
    const rows = [...this.rows.values()];
    if (!rows.length) return;
    const label = process.env.REGRESSION_LABEL || 'latest';
    const run = {
      label, date: new Date().toISOString(), baseURL: this.meta.baseURL || '', clone: Boolean(this.meta.clone),
      totals: tally(rows), rows, sweep: this.sweep,
    };
    fs.mkdirSync(this.outDir, { recursive: true });
    fs.writeFileSync(path.join(this.outDir, `${label}.json`), JSON.stringify(run, null, 1));
    fs.writeFileSync(path.join(this.outDir, `${label}.md`), renderMarkdown(run));
    const t = run.totals;
    console.log(`\nRegresion [${label}]: ${t.PASS} PASS, ${t.FAIL} FAIL, ${t.SKIP} SKIP -> ${path.join(this.outDir, `${label}.md`)}`);
  }

  printsToStdio() { return false; }
}

module.exports = RegressionReporter;
