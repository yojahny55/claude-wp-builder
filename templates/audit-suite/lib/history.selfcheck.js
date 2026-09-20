// @ts-check
// node lib/history.selfcheck.js — comprobaciones del historico y la comparativa.
const assert = require('assert');
const H = require('./history');

// --- marca temporal ---
assert.strictEqual(H.stamp(new Date(2026, 0, 5, 9, 7)), '2026-01-05_0907',
  'la marca lleva ceros a la izquierda y es ordenable alfabeticamente');
assert.ok(H.stamp(new Date(2026, 0, 5, 9, 7)) < H.stamp(new Date(2026, 0, 5, 10, 0)),
  'ordenar como texto equivale a ordenar por fecha');

// --- aplanado ---
const pages = {
  Home: { 46: { c: 46, name: 'Titulo', status: 'pass' }, 53: { c: '53', name: 'Canonical', status: 'fail' } },
  Contacto: { 46: { c: 46, name: 'Titulo', status: 'warn' } },
};
const snap = H.snapshotFrom(pages);
assert.strictEqual(snap.length, 3);
assert.deepStrictEqual(snap.map(r => `${r.page}/${r.c}`), ['Contacto/46', 'Home/46', 'Home/53'],
  'orden estable por pagina y criterio, con el numero comparado como numero');
assert.strictEqual(typeof snap[0].c, 'string', 'el criterio se normaliza a texto para poder comparar entre corridas');

// --- comparacion ---
const antes = [
  { page: 'Home', c: '53', name: 'Canonical', status: 'fail' },
  { page: 'Home', c: '46', name: 'Titulo', status: 'warn' },
  { page: 'Home', c: '41', name: 'Rendimiento', status: 'pass' },
  { page: 'Vieja', c: '46', name: 'Titulo', status: 'pass' },
];
const ahora = [
  { page: 'Home', c: '53', name: 'Canonical', status: 'warn' },   // fail -> warn: mejora
  { page: 'Home', c: '46', name: 'Titulo', status: 'pass' },      // warn -> pass: mejora
  { page: 'Home', c: '41', name: 'Rendimiento', status: 'fail' }, // pass -> fail: regresion
  { page: 'Home', c: '58', name: 'hreflang', status: 'pass' },    // no estaba antes
];
const d = H.compare(antes, ahora);
assert.deepStrictEqual(d.mejoras.map(r => r.c).sort(), ['46', '53'],
  'fail -> warn cuenta como mejora, no solo fail -> pass');
assert.deepStrictEqual(d.regresiones.map(r => r.c), ['41']);
assert.deepStrictEqual(d.nuevos.map(r => r.c), ['58']);
assert.deepStrictEqual(d.desaparecidos.map(r => r.page), ['Vieja'],
  'lo que se dejo de comprobar se reporta, no se ignora');
assert.strictEqual(d.mejoras[0].antes !== undefined, true, 'la mejora conserva el estado anterior');

// pass y na tienen el mismo rank: pasar de N/A a CUMPLE no es "mejora"
const sinCambio = H.compare(
  [{ page: 'Home', c: '58', name: 'hreflang', status: 'na' }],
  [{ page: 'Home', c: '58', name: 'hreflang', status: 'pass' }]);
assert.deepStrictEqual([sinCambio.mejoras.length, sinCambio.regresiones.length], [0, 0]);

// --- render ---
const md = H.renderComparison({ fecha: '2026-01-01_1000', pct: 70, pctActual: 80 }, d);
assert.ok(md.includes('**+10 puntos**'), 'la subida se muestra con signo');
assert.ok(md.indexOf('Empeoraron') < md.indexOf('Mejoraron'),
  'las regresiones van primero: son lo que hay que mirar');
assert.ok(H.renderComparison({ fecha: 'x', pct: 80, pctActual: 70 }, d).includes('**-10 puntos**'));
assert.ok(H.renderComparison({ fecha: 'x', pct: 80, pctActual: 80 },
  { mejoras: [], regresiones: [], nuevos: [], desaparecidos: [] }).includes('Ningun criterio cambio de estado'));

console.log('history: todas las comprobaciones OK');
