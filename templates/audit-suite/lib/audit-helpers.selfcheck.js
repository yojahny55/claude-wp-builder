// @ts-check
// node lib/audit-helpers.selfcheck.js — comprobaciones de la logica pura del
// modulo. Las funciones que necesitan navegador no se prueban aqui; esto cubre
// lo que decide un estado sin mirar la pagina.
const assert = require('assert');
const H = require('./audit-helpers');

// --- criterio 6: umbrales de ancho de linea, por pantalla ---
const th = { lineWarnChars: 85, lineMaxChars: 100 };
const una = (widths) => [{ vp: 'escritorio', widths }];
const estado = (widths) => H.lineVerdict(una(widths), th).status;

assert.strictEqual(estado([60, 70, 85]), 'pass', '85 justo en el limite todavia cumple');
assert.strictEqual(estado([86]), 'warn', 'un caracter por encima del aviso ya avisa');
assert.strictEqual(estado([100]), 'warn', '100 es el ultimo valor que solo avisa');
assert.strictEqual(estado([101]), 'fail', 'por encima de 100 incumple');
assert.strictEqual(estado([60, 70, 120]), 'fail',
  'un solo bloque pasado manda: el peor estado gana, no el promedio');
assert.strictEqual(estado([]), 'manual',
  'sin bloques medibles es revision manual, no aprobado por defecto');

// La evidencia tiene que permitir localizar el bloque: cuantos y cual es el peor.
const malo = H.lineVerdict(una([60, 130, 104]), th);
assert.ok(malo.evidence.includes('2/3'), 'cuenta los bloques afectados');
assert.ok(malo.evidence.includes('130'), 'nombra la linea mas larga encontrada');
assert.ok(malo.rec.includes('65ch'), 'la recomendacion es accionable');
assert.strictEqual(H.lineVerdict(una([70]), th).rec, '',
  'lo que cumple no lleva recomendacion');

// --- lo importante: DONDE desborda ---
const tres = [
  { vp: 'movil (390px)', widths: [38, 40] },
  { vp: 'tablet (768px)', widths: [62] },
  { vp: 'escritorio (1440px)', widths: [109] },
];
const soloEscritorio = H.lineVerdict(tres, th);
assert.strictEqual(soloEscritorio.status, 'fail');
assert.ok(soloEscritorio.evidence.includes('Se pasa de 100 car. en: escritorio (1440px)'),
  'nombra la pantalla donde desborda, que es lo que hay que arreglar');
assert.ok(!soloEscritorio.evidence.startsWith('Se pasa de 100 car. en: movil'),
  'no acusa a las pantallas que estan bien');
assert.ok(/movil \(390px\) 40, tablet \(768px\) 62, escritorio \(1440px\) 109/.test(soloEscritorio.evidence),
  'da la linea mas larga de CADA pantalla (40, no 38: es el mayor de los bloques)');

// Un tema que no reduce la tipografia falla en movil y no en escritorio.
const alReves = H.lineVerdict([
  { vp: 'movil (390px)', widths: [118] },
  { vp: 'escritorio (1440px)', widths: [70] },
], th);
assert.ok(alReves.evidence.includes('en: movil (390px)') && !alReves.evidence.includes('en: escritorio'),
  'el desborde en movil se reporta igual de bien que el de escritorio');

// Pantallas mezcladas: manda la peor, pero se distingue cual avisa y cual falla.
const mixto = H.lineVerdict([
  { vp: 'movil (390px)', widths: [90] },      // aviso
  { vp: 'escritorio (1440px)', widths: [130] }, // incumple
], th);
assert.strictEqual(mixto.status, 'fail', 'el fallo manda sobre el aviso');
assert.ok(mixto.evidence.includes('en: escritorio (1440px)') && !mixto.evidence.includes('en: movil (390px) ('),
  'el detalle del fallo apunta solo a la pantalla que incumple');

// Una pantalla sin texto medible no debe ocultar lo que miden las otras.
const conHueco = H.lineVerdict([
  { vp: 'movil (390px)', widths: [] },
  { vp: 'escritorio (1440px)', widths: [130] },
], th);
assert.strictEqual(conHueco.status, 'fail');
assert.ok(!conHueco.evidence.includes('movil'), 'la pantalla sin medidas se omite, no cuenta como aprobada');

// El nombre del criterio sigue al umbral configurado, no a un numero fijo.
assert.ok(H.lineVerdict(una([50]), { lineWarnChars: 70, lineMaxChars: 80 }).name.includes('80'));
assert.strictEqual(H.lineVerdict(una([75]), { lineWarnChars: 70, lineMaxChars: 80 }).status, 'warn',
  'los umbrales son configurables de verdad');

console.log('audit-helpers: todas las comprobaciones OK');
