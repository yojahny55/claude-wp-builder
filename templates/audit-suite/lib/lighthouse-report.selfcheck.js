// @ts-check
// Autocomprobacion de lib/lighthouse-report.js con un `lhr` sintetico.
// Sin red, sin navegador, sin Lighthouse:  node lib/lighthouse-report.selfcheck.js
const assert = require('assert');
const LH = require('./lighthouse-report');

// --- lhr sintetico de escritorio -------------------------------------------
const lhr = {
  categories: {
    performance: {
      score: 0.62,
      auditRefs: [
        { id: 'unminified-css', group: 'diagnostics' }, { id: 'render-blocking', group: 'diagnostics' },
        { id: 'uses-webp', group: 'diagnostics' }, { id: 'viewport' },
        // Las metricas y los audits "insight" de Lighthouse 12 no son
        // incidencias: repiten lo que ya dicen las filas 41.1-41.3.
        { id: 'speed-index', group: 'metrics' }, { id: 'render-blocking-insight', group: 'hidden' },
      ],
    },
    'best-practices': { score: 0.83, auditRefs: [{ id: 'no-vulnerable-libraries' }, { id: 'errors-in-console' }] },
    seo: { score: 1, auditRefs: [{ id: 'meta-description' }] },
    accessibility: { score: 0.91, auditRefs: [{ id: 'image-alt' }, { id: 'aria-hidden' }] },
  },
  audits: {
    'largest-contentful-paint': { numericValue: 4800 },
    'cumulative-layout-shift': { numericValue: 0.04 },
    'total-blocking-time': { numericValue: 340 },
    'unminified-css': { id: 'unminified-css', title: 'Minificar CSS', score: 0.3, scoreDisplayMode: 'numeric', details: { overallSavingsMs: 900, items: [1, 2] } },
    'render-blocking': { id: 'render-blocking', title: 'Eliminar recursos que bloquean', score: 0.1, scoreDisplayMode: 'numeric', details: { overallSavingsMs: 2100, items: [1] } },
    'uses-webp': { id: 'uses-webp', title: 'Servir imagenes en WebP', score: 0.5, scoreDisplayMode: 'numeric', details: { items: [1, 2, 3] } },
    'viewport': { id: 'viewport', title: 'Tiene viewport', score: 1, scoreDisplayMode: 'binary' },
    'no-vulnerable-libraries': { id: 'no-vulnerable-libraries', title: 'Librerias con vulnerabilidades', score: 0, scoreDisplayMode: 'binary', details: { items: [1] } },
    'errors-in-console': { id: 'errors-in-console', title: 'Errores en consola', score: null, scoreDisplayMode: 'informative' },
    'meta-description': { id: 'meta-description', title: 'Meta description', score: 1, scoreDisplayMode: 'binary' },
    'image-alt': { id: 'image-alt', title: 'Imagenes sin alt', score: 0, scoreDisplayMode: 'binary', details: { items: [1, 2] } },
    'aria-hidden': { id: 'aria-hidden', title: 'aria-hidden mal usado', score: null, scoreDisplayMode: 'notApplicable' },
    'speed-index': { id: 'speed-index', title: 'Speed Index', score: 0.4, scoreDisplayMode: 'numeric', displayValue: '4.3 s' },
    'render-blocking-insight': { id: 'render-blocking-insight', title: 'Render blocking requests', score: 0.2, scoreDisplayMode: 'metricSavings', details: { overallSavingsMs: 2100 } },
  },
};

// --- Core Web Vitals de una sola corrida ---
const cwv = LH.coreWebVitals(lhr);
assert.strictEqual(cwv.length, 3);
const by = Object.fromEntries(cwv.map(r => [r.c, r]));
assert.strictEqual(by['41.1'].status, 'fail', 'LCP 4.8s (> 4s) => deficiente');
assert.match(by['41.1'].evidence, /4\.80 s/);
assert.strictEqual(by['41.2'].status, 'pass', 'CLS 0.04 (< 0.1) => bueno');
assert.strictEqual(by['41.3'].status, 'warn', 'TBT 340ms (entre 200 y 600) => mejorable');
assert.ok(by['41.1'].rec, 'un fallo siempre lleva recomendacion');
assert.strictEqual(by['41.2'].rec, '', 'lo que cumple no lleva recomendacion');
// Metrica ausente => manual, nunca un veredicto inventado.
assert.strictEqual(LH.coreWebVitals({ audits: {}, categories: {} })[0].status, 'manual');

// --- Audits fallidos: ordenados por ahorro, sin informativos ni N/A ---
const perf = LH.failingAudits(lhr, 'performance');
assert.deepStrictEqual(perf.map(a => a.id), ['render-blocking', 'unminified-css', 'uses-webp'],
  'ordenados por ahorro estimado; el audit que pasa (viewport) queda fuera');
assert.ok(!perf.some(a => a.id === 'speed-index'),
  'las metricas ya salen en 41.1-41.3: no se repiten como incidencia');
assert.ok(!perf.some(a => a.id === 'render-blocking-insight'),
  'los audits insight repiten el diagnostico clasico con otro titulo');
assert.deepStrictEqual(LH.failingAudits(lhr, 'best-practices').map(a => a.id), ['no-vulnerable-libraries'],
  'errors-in-console es informative => se descarta');
assert.deepStrictEqual(LH.failingAudits(lhr, 'accessibility').map(a => a.id), ['image-alt'],
  'aria-hidden es notApplicable => se descarta');
assert.strictEqual(LH.failingAudits(lhr, 'seo').length, 0, 'categoria sin fallos => lista vacia');
assert.strictEqual(LH.failingAudits(lhr, 'performance', 2).length, 2, 'se respeta el limite');

// --- Scores ---
assert.deepStrictEqual(LH.scores(lhr), { performance: 62, accessibility: 91, 'best-practices': 83, seo: 100 });

// --- extractRun: lo que se guarda en el JSON de resultados ---
const desktop = LH.extractRun(lhr, 'desktop');
assert.strictEqual(desktop.formFactor, 'desktop');
assert.strictEqual(desktop.label, 'Escritorio');
assert.strictEqual(desktop.scores.performance, 62);
assert.strictEqual(desktop.metrics['largest-contentful-paint'], 4800);
assert.deepStrictEqual(Object.keys(desktop.issues).sort(),
  ['accessibility', 'best-practices', 'performance', 'seo'], 'guarda las 4 categorias');
assert.strictEqual(desktop.issues.seo.length, 0);
assert.ok(JSON.parse(JSON.stringify(desktop)), 'lo que se extrae tiene que ser serializable');

// --- Movil sintetico: mismos audits, peores numeros ---
const mobile = {
  formFactor: 'mobile', label: 'Movil',
  scores: { performance: 41, accessibility: 88, 'best-practices': 83, seo: 92 },
  metrics: { 'largest-contentful-paint': 8200, 'cumulative-layout-shift': 0.31, 'total-blocking-time': 120 },
  issues: {
    performance: [
      { id: 'render-blocking', title: 'Eliminar recursos que bloquean', display: '', saving: 3400, items: 2, score: 0 },
      { id: 'uses-responsive-images', title: 'Dimensionar imagenes', display: '', saving: 450, items: 4, score: 0.2 },
    ],
    'best-practices': [{ id: 'no-vulnerable-libraries', title: 'Librerias con vulnerabilidades', display: '', saving: 0, items: 1, score: 0 }],
    seo: [{ id: 'is-crawlable', title: 'Pagina bloqueada para indexar', display: '', saving: 0, items: 1, score: 0 }],
    accessibility: [
      { id: 'image-alt', title: 'Imagenes sin alt', display: '', saving: 0, items: 5, score: 0 },
      { id: 'color-contrast', title: 'Contraste insuficiente', display: '', saving: 0, items: 3, score: 0 },
    ],
  },
};
const lh = { desktop, mobile };
const th = {
  lighthouse: { performance: 90, seo: 90, accessibility: 90, 'best-practices': 90 },
  lighthousePerfWarn: 85,
  cwv: { 'largest-contentful-paint': 2500, 'cumulative-layout-shift': 0.1, 'total-blocking-time': 200 },
};

// --- Criterio 41: manda el peor de los dos form factors ---
const gate = LH.gateRow(lh, th.lighthouse, th.lighthousePerfWarn);
assert.strictEqual(gate.c, '41');
assert.strictEqual(gate.status, 'fail');
assert.match(gate.evidence, /Escritorio: Perf 62/);
assert.match(gate.evidence, /Movil: Perf 41/, 'los dos form factors salen en la evidencia');
const soloBuenos = {
  desktop: { ...desktop, scores: { performance: 95, accessibility: 96, 'best-practices': 100, seo: 100 } },
  mobile: { ...mobile, scores: { performance: 87, accessibility: 96, 'best-practices': 100, seo: 100 } },
};
assert.strictEqual(LH.gateRow(soloBuenos, th.lighthouse, 85).status, 'warn',
  'perf 87 en movil (85-89) es advertencia, no fallo');
assert.strictEqual(LH.gateRow({}, th.lighthouse, 85).status, 'manual', 'sin datos => manual, no inventar');

// --- Core Web Vitals combinados: el peor manda, ambos valores visibles ---
const cwvc = Object.fromEntries(LH.coreWebVitalsCombined(lh, th.cwv).map(r => [r.c, r]));
assert.match(cwvc['41.1'].evidence, /Escritorio: 4\.80 s/);
assert.match(cwvc['41.1'].evidence, /Movil: 8\.20 s/);
assert.strictEqual(cwvc['41.2'].status, 'fail',
  'CLS bueno en escritorio (0.04) pero deficiente en movil (0.31) => fail');
assert.strictEqual(cwvc['41.3'].status, 'warn', 'TBT: escritorio mejorable, movil bueno => mejorable');

// --- Filas por categoria: puntuacion de cada form factor + audits ---
const cats = Object.fromEntries(LH.categoryFindingsCombined(lh).map(r => [r.c, r]));
assert.strictEqual(Object.keys(cats).length, 4, 'las 4 categorias de Lighthouse');
assert.match(cats['41.4'].evidence, /Escritorio 62\/100 · Movil 41\/100/);
assert.match(cats['41.6'].evidence, /Escritorio 100\/100 · Movil 92\/100/);
assert.strictEqual(cats['41.6'].status, 'warn', 'SEO 100 en escritorio pero con un audit fallido en movil');
assert.match(cats['41.6'].evidence, /solo Movil/, 'se dice en que form factor falla');
assert.ok(LH.categoryFindingsCombined(lh).every(r => r.status !== 'fail'),
  'las filas de categoria nunca marcan fail: son evidencia del criterio 41');
assert.strictEqual(LH.categoryFindingsCombined({})[0].status, 'manual');

// --- Incidencias fundidas ---
const todas = LH.mergeIssues(lh);
const ids = todas.map(i => i.id);
assert.strictEqual(new Set(ids).size, ids.length, 'un audit que falla en ambos es UNA incidencia');
const rb = todas.find(i => i.id === 'render-blocking');
assert.deepStrictEqual(rb.formFactors, ['Escritorio', 'Movil']);
assert.strictEqual(rb.saving, 3400, 'se conserva el peor ahorro estimado de los dos');
assert.match(rb.impacto, /ahorro ~3\.40 s/);
assert.strictEqual(todas.find(i => i.id === 'is-crawlable').sev, 'Alta', 'indexabilidad es Alta');
assert.strictEqual(todas.find(i => i.id === 'image-alt').sev, 'Alta', 'accesibilidad rota (score 0) es Alta');
assert.strictEqual(todas.find(i => i.id === 'no-vulnerable-libraries').sev, 'Alta');
assert.strictEqual(todas.find(i => i.id === 'uses-responsive-images').sev, 'Media', 'ahorro 450ms => Media');
assert.strictEqual(todas.find(i => i.id === 'uses-webp').sev, 'Baja', 'sin ahorro estimado => Baja');
assert.deepStrictEqual(todas.map(i => i.sev), [...todas.map(i => i.sev)].sort(
  (a, b) => LH.SEV_ORDER[a] - LH.SEV_ORDER[b]), 'ordenadas por severidad');
assert.strictEqual(todas.find(i => i.id === 'uses-webp').categoria, 'Rendimiento',
  'cada incidencia dice a que categoria de Lighthouse pertenece');
assert.deepStrictEqual(LH.mergeIssues(lh, 'seo').map(i => i.id), ['is-crawlable'],
  'se puede pedir una sola categoria');
assert.deepStrictEqual(LH.mergeIssues({}), [], 'sin datos, sin incidencias');

// --- Filas completas del criterio 41 ---
const rows = LH.combinedRows(lh, th);
assert.deepStrictEqual(rows.map(r => r.c), ['41', '41.1', '41.2', '41.3', '41.4', '41.5', '41.6', '41.7']);

// --- Iconos de puntuacion ---
assert.strictEqual(LH.scoreIcon(95), '✅');
assert.strictEqual(LH.scoreIcon(87), '⚠️');
assert.strictEqual(LH.scoreIcon(41), '❌');
assert.strictEqual(LH.scoreIcon(null), '🔍');

// --- Configuracion de los dos form factors ---
assert.deepStrictEqual(LH.FORM_FACTORS.map(f => f.key), ['desktop', 'mobile']);
assert.strictEqual(LH.FORM_FACTORS[0].config.settings.formFactor, 'desktop');
assert.strictEqual(LH.FORM_FACTORS[0].config.settings.screenEmulation.mobile, false);
assert.strictEqual(LH.FORM_FACTORS[1].config.settings.formFactor, 'mobile');
assert.strictEqual(LH.FORM_FACTORS[1].config.settings.screenEmulation.mobile, true);
assert.strictEqual(LH.FORM_FACTORS[1].config.settings.throttling.cpuSlowdownMultiplier, 4,
  'movil emula CPU lenta: sin eso la medicion no es comparable con PageSpeed');

console.log('lighthouse-report: todas las comprobaciones OK');
