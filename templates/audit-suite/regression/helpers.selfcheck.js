// @ts-check
// node regression/helpers.selfcheck.js — logica pura de la suite de regresion.
const assert = require('assert');
const H = require('./helpers');
const D = require('./defaults');

// deepMerge: objetos se funden, listas se sustituyen, undefined no pisa.
const m = H.deepMerge({ a: { b: 1, c: [1, 2] }, d: 'x' }, { a: { c: [9] }, e: 2 });
assert.deepStrictEqual(m, { a: { b: 1, c: [9] }, d: 'x', e: 2 });
assert.strictEqual(H.deepMerge({ a: 1 }, undefined).a, 1, 'sin bloque de usuario quedan los defaults');
assert.ok(D.selectors.addToCart && D.urls.cart, 'los defaults traen selectores y rutas');

// Deteccion de clon: nunca debe tomar un dominio publico por clon.
for (const h of ['localhost', 'shop.local', 'a.test', 'site.local.example', '127.0.0.1', '192.168.1.5']) {
  assert.ok(H.isCloneHost(h), `${h} es un clon`);
}
for (const h of ['example.com', 'www.shop.org', 'localhost.example.com', 'locale.example.com', '']) {
  assert.ok(!H.isCloneHost(h), `${h} NO es un clon`);
}

// Precios en varios formatos.
assert.strictEqual(H.parsePrice('1.234,50 €'), 1234.5);
assert.strictEqual(H.parsePrice('$1,234.50'), 1234.5);
assert.strictEqual(H.parsePrice('12,90'), 12.9);
assert.strictEqual(H.parsePrice('1.500'), 1500);
assert.ok(Number.isNaN(H.parsePrice('gratis')));
assert.strictEqual(H.currencyToken('12,90 €'), '€');
assert.strictEqual(H.currencyToken('CUP 400'), 'CUP');

// Orden: NaN se ignora, un solo valor no demuestra nada.
assert.ok(H.isSorted([1, 2, 2, 5], 'asc'));
assert.ok(!H.isSorted([1, 3, 2], 'asc'));
assert.ok(H.isSorted([5, NaN, 3], 'desc'));
assert.ok(!H.isSorted([4], 'asc'), 'un unico valor no prueba el orden');

assert.strictEqual(H.searchWord('El Un Libro grande'), 'Libro');
assert.strictEqual(H.searchWord('a b'), '');

// mail_failed solo vale en un clon aislado.
assert.ok(H.judgeMailStatus('mail_sent', false).ok);
assert.ok(H.judgeMailStatus('mail_failed', true).ok);
assert.ok(!H.judgeMailStatus('mail_failed', false).ok, 'en produccion mail_failed es un fallo real');
assert.ok(!H.judgeMailStatus('validation_failed', true).ok);

// Informe y comparacion.
const row = (id, project, status, evidence = '') => ({ id, title: id, project, status, evidence, ms: 1 });
const before = { rows: [row('a', 'regression-desktop', 'PASS'), row('b', 'regression-desktop', 'PASS'), row('c', 'regression-desktop', 'FAIL'), row('d', 'regression-desktop', 'PASS')],
  sweep: [{ project: 'regression-desktop', url: '/x', status: 200, jsErrors: [], failed: [] }] };
const after = { rows: [row('a', 'regression-desktop', 'PASS'), row('b', 'regression-desktop', 'FAIL', 'boom'), row('c', 'regression-desktop', 'PASS'), row('d', 'regression-desktop', 'SKIP', 'gone')],
  sweep: [{ project: 'regression-desktop', url: '/x', status: 500, jsErrors: ['TypeError'], failed: [] }] };
const cmp = H.compareRuns(before, after);
assert.strictEqual(cmp.regressions.length, 2, 'PASS->FAIL y URL del barrido que deja de cargar');
assert.strictEqual(cmp.fixed.length, 1);
assert.ok(cmp.warnings.some((w) => /PASS -> SKIP/.test(w)), 'una funcion que desaparece avisa');
assert.ok(cmp.warnings.some((w) => /JS nuevo/.test(w)));
assert.strictEqual(H.compareRuns(before, before).regressions.length, 0);

const md = H.renderMarkdown({ ...after, label: 'after', baseURL: 'https://example.com', clone: true, date: '2026-01-01' });
assert.ok(/\| b \(`b`\) \| FAIL \|/.test(md), 'la tabla lleva el estado por flujo');
assert.ok(/## Fallos/.test(md) && /boom/.test(md), 'los fallos llevan su evidencia');
assert.ok(/## Omitidos/.test(md) && /gone/.test(md), 'los omitidos llevan su motivo');
assert.ok(/Barrido de URLs/.test(md));
console.log('regression/helpers.selfcheck: OK');
