// @ts-check
// Autocomprobacion del informe HTML con un modelo sintetico.
// Sin red, sin navegador:  node lib/report-html.selfcheck.js
const assert = require('assert');
const render = require('./report-html');

const audit = {
  siteName: 'Sitio <de> "prueba"',
  baseURL: 'https://ejemplo.test',
  thresholds: {
    lighthouse: { performance: 90, seo: 90, accessibility: 90, 'best-practices': 90 },
    lighthousePerfWarn: 85,
    cwv: { 'largest-contentful-paint': 2500, 'cumulative-layout-shift': 0.1, 'total-blocking-time': 200 },
  },
};

const run = (ff, label, sc, met, iss) => ({ formFactor: ff, label, scores: sc, metrics: met, issues: iss });
const lh = {
  desktop: run('desktop', 'Escritorio',
    { performance: 88, accessibility: 93, 'best-practices': 100, seo: 100 },
    { 'largest-contentful-paint': 3100, 'cumulative-layout-shift': 0.05, 'total-blocking-time': 120 },
    { performance: [{ id: 'render-blocking-resources', title: 'Bloquea el renderizado', display: '', saving: 1800, items: 3, score: 0.1 }],
      'best-practices': [], seo: [], accessibility: [] }),
  mobile: run('mobile', 'Movil',
    { performance: 44, accessibility: 90, 'best-practices': 100, seo: 100 },
    { 'largest-contentful-paint': 7400, 'cumulative-layout-shift': 0.28, 'total-blocking-time': 940 },
    { performance: [{ id: 'render-blocking-resources', title: 'Bloquea el renderizado', display: '', saving: 4200, items: 3, score: 0 }],
      'best-practices': [], seo: [], accessibility: [{ id: 'image-alt', title: 'Imagenes sin alt', display: '', saving: 0, items: 2, score: 0 }] }),
};

const fila = (c, name, status, evidence = '', rec = '') => ({ c, name, status, evidence, rec });
const data = {
  orderPaginas: ['Home'],
  dePagina: { Home: [fila('48', 'Alt <descriptivo>', 'fail', '3 imagenes & 1 icono', 'Anadir alt')] },
  deSitio: [fila('52', 'Sitemap', 'fail', 'No responde', 'Publicar sitemap')],
  lighthouse: { Home: lh },
  paginasLH: ['Home'],
  plan: [{ ...fila('52', 'Sitemap', 'fail', 'No responde', 'Publicar sitemap'), page: 'Home', sev: 'Alta', como: 'Ajuste' }],
  pendientes: [{ ...fila('28', 'Interno/externo', 'manual', '24 externos'), paginas: ['Home'], evidencias: new Set(['24 externos']) }],
  global: { pass: 10, fail: 2, warn: 1, manual: 1, na: 0, pct: 77 },
  tallyPorPagina: { Home: { pass: 10, fail: 2, warn: 1, manual: 1, na: 0, pct: 77 } },
  tallySitio: { pass: 1, fail: 1, warn: 0, manual: 0, na: 0, pct: 50 },
  altas: [{ ...fila('52', 'Sitemap', 'fail', 'No responde'), page: 'Home', sev: 'Alta' }],
  media: (ff, cat) => lh[ff].scores[cat],
  totalIncidencias: 2,
};

const opciones = { data, audit, fecha: '2026-09-10_1130', comparativa: null, thresholds: { min: audit.thresholds.lighthouse, warnPerf: 85 } };
const html = render(opciones);

// --- Estructura ---
assert.ok(html.startsWith('<!doctype html>'), 'documento completo, no un fragmento');
assert.match(html, /<html lang="es">/);
for (const id of ['s1', 's2', 's3', 's4', 's5', 's6', 's7', 'leyenda']) {
  assert.ok(html.includes(`id="${id}"`), `falta la seccion ${id}`);
}
assert.ok(html.includes('id="p-home"'), 'cada pagina lleva ancla propia para enlazarla desde las tablas');

// --- Un solo archivo: nada que cargar de fuera ---
assert.ok(!/<script[^>]+src=/i.test(html), 'sin scripts externos');
assert.ok(!/<link[^>]+stylesheet/i.test(html), 'sin hojas de estilo externas');
assert.ok(!/@import|url\(/i.test(html), 'sin recursos referenciados desde el CSS');
assert.ok(!/<img|<iframe/i.test(html), 'sin imagenes ni iframes');
assert.ok(!/fetch\(|XMLHttpRequest/i.test(html), 'sin peticiones de red');

// --- Escapado: el informe muestra HTML del sitio auditado como texto ---
assert.ok(html.includes('Sitio &lt;de&gt; &quot;prueba&quot;'), 'el nombre del sitio va escapado');
assert.ok(html.includes('Alt &lt;descriptivo&gt;'), 'los criterios van escapados');
assert.ok(html.includes('3 imagenes &amp; 1 icono'), 'la evidencia va escapada');
assert.ok(!/<descriptivo>/.test(html), 'nada del sitio auditado se cuela como etiqueta');

// --- Contenido ---
assert.ok(html.includes('82%') === false && html.includes('77%'), 'usa el porcentaje del modelo');
assert.ok(html.includes('Escritorio') && html.includes('Movil'), 'los dos perfiles de Lighthouse');
assert.ok(html.includes('>88<') && html.includes('>44<'), 'las puntuaciones de cada perfil');
assert.match(html, /class="score mid">88/, 'perf 88 entre 85 y 89 => advertencia');
assert.match(html, /class="score bad">44/, 'perf 44 por debajo de 85 => fallo');
assert.match(html, /class="score ok">100/, 'perf 100 => cumple');
assert.ok(html.includes('Bloquea el renderizado'), 'las incidencias de Lighthouse salen por pagina');
assert.ok(html.includes('Escritorio y movil'), 'un audit que falla en los dos se anota como tal');
assert.ok(html.includes('Imagenes sin alt') && html.includes('>Movil<'), 'y el que falla en uno solo, tambien');

// Una celda con display:block romperia el layout de la tabla del plan.
assert.ok(!/table\.plan \.ev\{display:block/.test(html), 'el display:block va sobre el span, no sobre el td');
assert.ok(/table\.plan span\.ev\{/.test(html));

// --- Sin mediciones de Lighthouse el informe sigue saliendo ---
const vacio = render({ ...opciones, data: { ...data, lighthouse: {}, paginasLH: [], totalIncidencias: 0 } });
assert.ok(vacio.includes('Sin mediciones de Lighthouse'), 'lo dice en vez de fingir que midio');
assert.ok(vacio.startsWith('<!doctype html>'));

// --- Con comparativa ---
const conComp = render({
  ...opciones,
  comparativa: {
    fecha: '2026-09-09_1650', pct: 79, pctActual: 82,
    diff: { regresiones: [], mejoras: [{ c: '50', page: 'Home', name: '404', status: 'pass', antes: 'fail' }], nuevos: [], desaparecidos: [] },
  },
});
assert.ok(conComp.includes('1.1 Comparativa'), 'la comparativa abre el informe cuando hay una anterior');
assert.ok(conComp.includes('+3 puntos'));

console.log('report-html: todas las comprobaciones OK');
