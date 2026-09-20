// @ts-check
// node lib/plan.selfcheck.js — orden y reparto del plan de correccion.
const assert = require('assert');
const P = require('./plan');

// --- que puntua ---
assert.ok(P.isScored('53') && P.isScored(41));
assert.ok(!P.isScored('41.1') && !P.isScored('a11y-1'),
  'las filas de evidencia no puntuan: si contaran, el porcentaje dejaria de ser comparable');

// --- severidad ---
const f = (c) => ({ c, status: 'fail' });
assert.strictEqual(P.severity(f('53')), 'Alta', 'indexabilidad manda');
assert.strictEqual(P.severity(f('a11y-1')), 'Alta', 'barreras criticas de accesibilidad');
assert.strictEqual(P.severity(f('41.1')), 'Alta', 'LCP fuera de umbral');
assert.strictEqual(P.severity(f('7')), 'Media', 'el resto de fallos');
assert.strictEqual(P.severity({ c: '53', status: 'warn' }), 'Baja',
  'un aviso nunca es Alta, aunque el criterio sea de indexabilidad');

// --- reparto: quien lo aplica ---
const como = (c) => P.aplicacion({ c });
assert.strictEqual(como('57'), 'Ajuste', 'noindex vive en una opcion, no en el codigo');
assert.strictEqual(como('52'), 'Ajuste');
assert.strictEqual(como('56'), 'Ajuste',
  'los redirects son configuracion de servidor o de plugin, no codigo del tema');
assert.strictEqual(como('55'), 'Ajuste', 'forzar HTTPS es del hosting');
assert.strictEqual(como('49'), 'Contenido', 'una meta description hay que escribirla');
assert.strictEqual(como('48'), 'Contenido', 'el alt describe la imagen: lo decide una persona');
assert.strictEqual(como('27'), 'Manual', 'juicio humano: no se automatiza');
assert.strictEqual(como('36'), 'Manual');
assert.strictEqual(como('41.4'), 'Codigo', 'las audits de Lighthouse se corrigen en el tema');
assert.strictEqual(como('a11y-1'), 'Codigo');
assert.strictEqual(como('6'), 'Codigo', 'el ancho de linea es CSS');

// --- plan completo ---
const pages = {
  Home: {
    7:  { c: '7', name: 'Bloques', status: 'warn' },
    53: { c: '53', name: 'Canonical', status: 'fail' },
    49: { c: '49', name: 'Description', status: 'fail' },
    46: { c: '46', name: 'Titulo', status: 'pass' },   // no entra: no hay nada que corregir
  },
  Contacto: { 27: { c: '27', name: 'Nombre de enlace', status: 'fail' } },
};
const plan = P.buildPlan(pages);
assert.deepStrictEqual(plan.map(r => r.c), ['53', '27', '49', '7'],
  'Alta primero; dentro del mismo nivel, los fallos antes que los avisos');
assert.ok(!plan.some(r => r.status === 'pass'), 'lo que cumple no entra en el plan');
assert.deepStrictEqual(plan.map(r => r.como), ['Ajuste', 'Manual', 'Contenido', 'Codigo']);
assert.deepStrictEqual(plan.map(r => r.page), ['Home', 'Contacto', 'Home', 'Home'],
  'cada fila conserva su pagina');
assert.deepStrictEqual(P.buildPlan({}), [], 'sin hallazgos, plan vacio');

// --- pagina vs sitio ---
// El 41 se mide en CADA pagina y da un numero distinto en cada una: va en la
// tabla de su pagina, no en la seccion de criterios de sitio.
assert.ok(!P.esDeSitio('41', 'Home'), 'el 41 es de pagina: Lighthouse corre en cada una');
assert.ok(!P.esDeSitio('41.1', 'Home') && !P.esDeSitio('41.4', 'Home'),
  'sus filas de evidencia acompanan a la pagina medida');
assert.ok(P.esDeSitio('52', 'Home'), 'el sitemap se evalua una vez');
assert.ok(P.esDeSitio('7', '_404'), 'las paginas tecnicas van a la seccion de sitio');

// --- agrupado de filas repetidas ---
// Los criterios de sitio y el RESUMEN por categoria de Lighthouse (41.4-41.7)
// van en una sola fila del plan; el criterio 41 y los Core Web Vitals, no.
const repetido = {
  Home: {
    41: { c: '41', name: 'Lighthouse', status: 'warn', evidence: 'Perf 87' },
    '41.4': { c: '41.4', name: 'Rendimiento', status: 'warn', evidence: '87/100' },
    52: { c: '52', name: 'Sitemap', status: 'warn', evidence: 'faltan URLs' },
    48: { c: '48', name: 'Alt', status: 'fail', evidence: '3 imagenes' },
  },
  Contacto: {
    41: { c: '41', name: 'Lighthouse', status: 'fail', evidence: 'Perf 44' },
    '41.4': { c: '41.4', name: 'Rendimiento', status: 'warn', evidence: '44/100' },
    52: { c: '52', name: 'Sitemap', status: 'fail', evidence: 'no responde' },
    48: { c: '48', name: 'Alt', status: 'fail', evidence: '1 imagen' },
  },
  Precios: { 41: { c: '41', name: 'Lighthouse', status: 'warn', evidence: 'Perf 88' } },
};
const agrupado = P.agruparFilasRepetidas(P.buildPlan(repetido));
assert.strictEqual(agrupado.filter(r => r.c === '41').length, 3,
  'el 41 va por pagina: cada una tiene sus propias puntuaciones');
assert.strictEqual(agrupado.filter(r => r.c === '48').length, 2,
  'un criterio de pagina tiene una fila por pagina: se corrige en cada una');
const filas414 = agrupado.filter(r => r.c === '41.4');
assert.strictEqual(filas414.length, 1, 'el resumen por categoria se agrupa: el detalle esta por pagina');
assert.strictEqual(filas414[0].page, '2 paginas');
const filas52 = agrupado.filter(r => r.c === '52');
assert.strictEqual(filas52.length, 1, 'un criterio de sitio sale una sola vez');
assert.strictEqual(filas52[0].status, 'fail', 'se queda el peor estado de las paginas');
assert.strictEqual(filas52[0].evidence, 'no responde', 'y su evidencia, que es la que manda la correccion');
assert.strictEqual(P.agruparFilasRepetidas(P.buildPlan({
  Home: { 52: { c: '52', name: 'Sitemap', status: 'fail', evidence: 'no responde' } },
})).filter(r => r.c === '52')[0].page, 'Home', 'con una sola pagina se nombra la pagina');
assert.deepStrictEqual(P.agruparFilasRepetidas([]), []);

console.log('plan: todas las comprobaciones OK');
