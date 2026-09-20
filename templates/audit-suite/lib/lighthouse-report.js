// @ts-check
// Extrae de un informe Lighthouse (objeto `lhr`) lo que hoy se tiraba: los
// Core Web Vitals de laboratorio y los audits que fallan en cada categoria.
// Funciones puras sobre el JSON -> comprobables sin ejecutar un navegador
// (ver lib/lighthouse-report.selfcheck.js).
//
// Cada pagina se mide DOS veces, en escritorio y en movil: son dos perfiles de
// red, CPU y viewport distintos y dan puntuaciones distintas (movil siempre
// peor). El informe reporta las cuatro categorias de cada uno y funde las
// incidencias de ambos en una sola lista por pagina.
const R = (c, name, status, evidence = '', rec = '') => ({ c, name, status, evidence, rec });

const ms = (v) => `${Math.round(v)} ms`;
const secs = (v) => `${(v / 1000).toFixed(2)} s`;

// --- Form factors -----------------------------------------------------------
// Los dos perfiles oficiales de Lighthouse. Los valores son los mismos que usa
// `lighthouse --preset=desktop` y el default movil (Moto G Power / Slow 4G),
// copiados aqui para no depender de los internos ESM del paquete lighthouse.
const DESKTOP_SCREEN = { mobile: false, width: 1350, height: 940, deviceScaleFactor: 1, disabled: false };
const MOBILE_SCREEN = { mobile: true, width: 412, height: 823, deviceScaleFactor: 1.75, disabled: false };
const DESKTOP_UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36';
const MOBILE_UA = 'Mozilla/5.0 (Linux; Android 11; moto g power (2022)) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Mobile Safari/537.36';

const FORM_FACTORS = [
  {
    key: 'desktop', label: 'Escritorio',
    config: {
      extends: 'lighthouse:default',
      settings: {
        formFactor: 'desktop',
        screenEmulation: DESKTOP_SCREEN,
        emulatedUserAgent: DESKTOP_UA,
        // desktopDense4G: sin ralentizar la CPU y con latencia de fibra.
        throttling: {
          rttMs: 40, throughputKbps: 10 * 1024, cpuSlowdownMultiplier: 1,
          requestLatencyMs: 0, downloadThroughputKbps: 0, uploadThroughputKbps: 0,
        },
      },
    },
  },
  {
    key: 'mobile', label: 'Movil',
    config: {
      extends: 'lighthouse:default',
      settings: {
        formFactor: 'mobile',
        screenEmulation: MOBILE_SCREEN,
        emulatedUserAgent: MOBILE_UA,
        // mobileSlow4G: el default de Lighthouse y el que replica PageSpeed.
        throttling: {
          rttMs: 150, throughputKbps: 1638.4, cpuSlowdownMultiplier: 4,
          requestLatencyMs: 562.5, downloadThroughputKbps: 1474.56, uploadThroughputKbps: 607.5,
        },
      },
    },
  },
];
const labelOf = (key) => (FORM_FACTORS.find(f => f.key === key) || { label: key }).label;

// --- Metricas y categorias --------------------------------------------------
// Umbrales oficiales de Google: "good" / "needs improvement" / "poor".
// INP NO se puede medir en laboratorio (necesita interaccion real de usuario);
// TBT es su proxy de lab reconocido, y asi se reporta aqui.
const CWV = [
  { id: 'largest-contentful-paint', c: '41.1', name: 'LCP (Largest Contentful Paint)',
    good: 2500, poor: 4000, fmt: secs,
    rec: 'Optimizar la imagen/bloque mas grande: precarga, WebP, sin lazy-load en el LCP, menos render-blocking' },
  { id: 'cumulative-layout-shift', c: '41.2', name: 'CLS (Cumulative Layout Shift)',
    good: 0.1, poor: 0.25, fmt: (v) => v.toFixed(3),
    rec: 'Reservar espacio: width/height en <img>, min-height en slots de anuncios/embeds, font-display swap con metricas ajustadas' },
  { id: 'total-blocking-time', c: '41.3', name: 'TBT (proxy de laboratorio de INP)',
    good: 200, poor: 600, fmt: ms,
    rec: 'Reducir JS de terceros y de plugins, dividir tareas largas, diferir lo que no sea critico' },
];

// Una fila accionable por categoria de Lighthouse. Son EVIDENCIA del criterio
// 41 (que ya puntua con los 4 scores), no criterios nuevos: por eso nunca
// marcan 'fail' — no deben contar dos veces en la puntuacion.
const CATEGORIES = [
  { key: 'performance', c: '41.4', name: 'Rendimiento (Lighthouse)', label: 'Rendimiento' },
  { key: 'best-practices', c: '41.5', name: 'Buenas practicas (Lighthouse)', label: 'Buenas practicas' },
  { key: 'seo', c: '41.6', name: 'SEO tecnico automatico (Lighthouse)', label: 'SEO' },
  { key: 'accessibility', c: '41.7', name: 'Accesibilidad (Lighthouse)', label: 'Accesibilidad' },
];
const CATEGORY_KEYS = CATEGORIES.map(c => c.key);
// Orden de LECTURA de las tablas del informe: el mismo en el que se nombran las
// cuatro categorias ("rendimiento, accesibilidad, buenas practicas y SEO"). El
// orden de arriba es el de los numeros 41.4-41.7 y ese no se toca: cambiarlo
// renumeraria criterios ya guardados en el historico.
const CATEGORIES_DISPLAY = ['performance', 'accessibility', 'best-practices', 'seo']
  .map(k => CATEGORIES.find(c => c.key === k));
const catLabel = (key) => (CATEGORIES.find(c => c.key === key) || { label: key }).label;

// --- Lectura de un lhr ------------------------------------------------------
function coreWebVitals(lhr, th = {}) {
  return CWV.map(m => {
    const a = lhr.audits && lhr.audits[m.id];
    if (!a || a.numericValue == null) {
      return R(m.c, m.name, 'manual', 'Lighthouse no reporto la metrica', m.rec);
    }
    const v = a.numericValue;
    const good = th[m.id] ?? m.good;
    const status = v <= good ? 'pass' : (v <= m.poor ? 'warn' : 'fail');
    const verdict = status === 'pass' ? 'bueno' : (status === 'warn' ? 'mejorable' : 'deficiente');
    return R(m.c, m.name, status, `${m.fmt(v)} (${verdict}; objetivo <= ${m.fmt(good)})`, status === 'pass' ? '' : m.rec);
  });
}

// Grupos de auditRefs que NO son incidencias a resolver:
//   metrics — son las metricas (LCP, TBT, Speed Index...), que ya salen en sus
//     propias filas 41.1-41.3; listarlas otra vez como "audit fallido" las
//     cuenta dos veces y no dice que hacer.
//   hidden — los audits "insight" de Lighthouse 12, que repiten el mismo
//     hallazgo que el diagnostico clasico con otro titulo (render-blocking-
//     insight junto a render-blocking-resources, etc.).
const SKIP_GROUPS = new Set(['metrics', 'hidden']);

// Audits fallidos de una categoria, ordenados por impacto (ahorro estimado y
// luego peor puntuacion). Los informativos y los no aplicables se descartan.
function failingAudits(lhr, category, limit = 6) {
  const cat = lhr.categories && lhr.categories[category];
  if (!cat) return [];
  return cat.auditRefs
    .filter(ref => !SKIP_GROUPS.has(ref.group))
    .map(ref => lhr.audits[ref.id])
    .filter(a => a && a.score !== null && a.score < 1
      && !['informative', 'notApplicable', 'manual'].includes(a.scoreDisplayMode))
    .map(a => ({
      id: a.id,
      title: a.title,
      display: a.displayValue || '',
      saving: (a.details && a.details.overallSavingsMs) || 0,
      items: (a.details && Array.isArray(a.details.items)) ? a.details.items.length : 0,
      score: a.score,
    }))
    .sort((x, y) => (y.saving - x.saving) || (x.score - y.score))
    .slice(0, limit);
}

function scores(lhr) {
  const g = (k) => (lhr.categories && lhr.categories[k] ? Math.round(lhr.categories[k].score * 100) : null);
  return {
    performance: g('performance'), accessibility: g('accessibility'),
    'best-practices': g('best-practices'), seo: g('seo'),
  };
}

// Todo lo que el informe necesita de UNA corrida, ya serializable a JSON: se
// guarda en results/audit/lh-<pagina>.json y build-report.js lo lee sin volver
// a abrir el `lhr` entero (que pesa varios MB).
function extractRun(lhr, formFactor) {
  const metrics = {};
  for (const m of CWV) {
    const a = lhr.audits && lhr.audits[m.id];
    metrics[m.id] = (a && a.numericValue != null) ? a.numericValue : null;
  }
  const issues = {};
  for (const key of CATEGORY_KEYS) issues[key] = failingAudits(lhr, key, Infinity);
  return { formFactor, label: labelOf(formFactor), scores: scores(lhr), metrics, issues };
}

// --- Combinado de escritorio + movil ----------------------------------------
const RANK = { pass: 0, na: 0, manual: 1, warn: 2, fail: 3 };
const worst = (a, b) => (RANK[a] >= RANK[b] ? a : b);
const runsOf = (lh) => FORM_FACTORS.map(f => lh && lh[f.key]).filter(Boolean);

// Criterio 41: las 4 categorias > 90 en AMBOS form factors. Manda el peor: un
// sitio que solo aprueba en escritorio no aprueba la pauta.
function gateRow(lh, th, warnPerf = 85) {
  const runs = runsOf(lh);
  const name = 'GTmetrix/Lighthouse: las 4 categorias > 90 (escritorio y movil)';
  if (!runs.length) return R('41', name, 'manual', 'Sin datos de Lighthouse', 'Ejecutar npm run test:perf');
  const partes = [];
  let status = 'pass';
  for (const run of runs) {
    const s = run.scores;
    partes.push(`${run.label}: Perf ${s.performance}, A11y ${s.accessibility}, BP ${s['best-practices']}, SEO ${s.seo}`);
    const belowOther = ['accessibility', 'best-practices', 'seo'].filter(k => s[k] < th[k]);
    let st = 'pass';
    if (s.performance < warnPerf || belowOther.length) st = 'fail';
    else if (s.performance < th.performance) st = 'warn';
    status = worst(status, st);
  }
  return R('41', name, status, partes.join(' · '),
    status === 'pass' ? '' : 'Optimizar hasta superar 90 en las cuatro categorias, en escritorio y en movil');
}

// Core Web Vitals con el valor de los dos form factors en la misma fila. El
// estado es el peor de los dos: un LCP bueno en escritorio no salva el de movil.
function coreWebVitalsCombined(lh, th = {}) {
  const runs = runsOf(lh);
  if (!runs.length) return CWV.map(m => R(m.c, m.name, 'manual', 'Sin datos de Lighthouse', m.rec));
  return CWV.map(m => {
    const good = th[m.id] ?? m.good;
    const partes = [];
    let status = null;
    for (const run of runs) {
      const v = run.metrics ? run.metrics[m.id] : null;
      if (v == null) {
        partes.push(`${run.label}: sin dato`);
        status = worst(status || 'pass', 'manual');
        continue;
      }
      const st = v <= good ? 'pass' : (v <= m.poor ? 'warn' : 'fail');
      const verdict = st === 'pass' ? 'bueno' : (st === 'warn' ? 'mejorable' : 'deficiente');
      partes.push(`${run.label}: ${m.fmt(v)} (${verdict})`);
      status = status == null ? st : worst(status, st);
    }
    return R(m.c, m.name, status || 'manual', `${partes.join(' · ')}; objetivo <= ${m.fmt(good)}`,
      status === 'pass' ? '' : m.rec);
  });
}

// Una fila por categoria de Lighthouse, con la puntuacion de cada form factor
// y los audits a corregir. Nunca marca 'fail': es evidencia del criterio 41.
function categoryFindingsCombined(lh, limit = 6) {
  const runs = runsOf(lh);
  return CATEGORIES.map(({ key, c, name }) => {
    if (!runs.length) return R(c, name, 'manual', 'Sin datos de Lighthouse');
    const puntos = runs.map(r => `${r.label} ${r.scores[key]}/100`).join(' · ');
    const fails = mergeIssues(lh, key);
    if (!fails.length) return R(c, name, 'pass', `${puntos} — sin audits fallidos`);
    const evidence = fails.slice(0, limit)
      .map(f => `${f.title} (${f.impacto}${f.formFactors.length < runs.length ? `, solo ${f.formFactors.join('/')}` : ''})`)
      .join('; ');
    const resto = fails.length > limit ? ` (+${fails.length - limit} mas)` : '';
    return R(c, name, 'warn', `${puntos} — ${fails.length} audit(s) a corregir: ${evidence}${resto}`,
      'Detalle completo y elementos concretos en el HTML de Lighthouse (results/lighthouse/)');
  });
}

// --- Incidencias -------------------------------------------------------------
// Severidad de un audit de Lighthouse. Accesibilidad rota y los audits de
// indexabilidad y de HTTPS son Alta; en rendimiento manda el ahorro estimado.
const SEO_ALTA = new Set(['is-crawlable', 'http-status-code', 'canonical', 'robots-txt', 'crawlable-anchors', 'hreflang']);
const BP_ALTA = new Set(['is-on-https', 'no-vulnerable-libraries', 'csp-xss', 'geolocation-on-start', 'notification-on-start']);

function issueSeverity(category, it) {
  if (category === 'accessibility') return it.score === 0 ? 'Alta' : 'Media';
  if (category === 'seo') return SEO_ALTA.has(it.id) ? 'Alta' : 'Media';
  if (category === 'best-practices') return BP_ALTA.has(it.id) ? 'Alta' : 'Media';
  if (it.saving >= 1000) return 'Alta';
  if (it.saving >= 300) return 'Media';
  return 'Baja';
}

const impactoDe = (it) => it.saving
  ? `ahorro ~${it.saving >= 1000 ? secs(it.saving) : ms(it.saving)}`
  : (it.display || (it.items ? `${it.items} elemento(s)` : 'sin ahorro estimado'));

// Incidencias de una categoria (o de todas) fundiendo escritorio y movil: un
// mismo audit fallando en los dos es UNA incidencia, no dos, y se anota en
// cuales falla. Ordenadas por severidad y luego por ahorro estimado.
const SEV_ORDER = { Alta: 0, Media: 1, Baja: 2 };
function mergeIssues(lh, category = null) {
  const cats = category ? [category] : CATEGORY_KEYS;
  const byId = new Map();
  for (const run of runsOf(lh)) {
    for (const key of cats) {
      for (const it of (run.issues && run.issues[key]) || []) {
        const k = `${key}|${it.id}`;
        const prev = byId.get(k);
        if (prev) {
          if (!prev.formFactors.includes(run.label)) prev.formFactors.push(run.label);
          if (it.saving > prev.saving) { prev.saving = it.saving; prev.display = it.display; }
          if (it.items > prev.items) prev.items = it.items;
          prev.score = Math.min(prev.score, it.score);
        } else {
          byId.set(k, {
            category: key, categoria: catLabel(key), id: it.id, title: it.title,
            display: it.display, saving: it.saving, items: it.items, score: it.score,
            formFactors: [run.label],
          });
        }
      }
    }
  }
  const out = [...byId.values()].map(it => ({ ...it, impacto: impactoDe(it), sev: issueSeverity(it.category, it) }));
  return out.sort((a, b) => (SEV_ORDER[a.sev] - SEV_ORDER[b.sev])
    || (b.saving - a.saving)
    || (CATEGORY_KEYS.indexOf(a.category) - CATEGORY_KEYS.indexOf(b.category))
    || a.id.localeCompare(b.id));
}

// Las filas de criterio (41 y 41.1-41.7) que salen de una pagina medida en los
// dos form factors. Es lo que consumen la suite y el informe.
function combinedRows(lh, th, opts = {}) {
  return [
    gateRow(lh, th.lighthouse, th.lighthousePerfWarn ?? 85),
    ...coreWebVitalsCombined(lh, th.cwv),
    ...categoryFindingsCombined(lh, opts.topAudits ?? 6),
  ];
}

// Icono de una puntuacion de categoria segun el umbral de la pauta 41.
const scoreIcon = (score, min = 90, warn = 85) =>
  score == null ? '🔍' : (score >= min ? '✅' : (score >= warn ? '⚠️' : '❌'));

module.exports = {
  coreWebVitals, failingAudits, scores, extractRun,
  gateRow, coreWebVitalsCombined, categoryFindingsCombined, combinedRows,
  mergeIssues, issueSeverity, scoreIcon, labelOf, catLabel,
  CWV, CATEGORIES, CATEGORIES_DISPLAY, CATEGORY_KEYS, FORM_FACTORS, SEV_ORDER, SKIP_GROUPS, R,
};
