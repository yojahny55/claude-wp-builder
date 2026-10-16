// @ts-check
// node scripts/regression-compare.js [antes] [despues] [--allow-skips]
// Compara results/regression/<antes>.json con <despues>.json (por defecto before / after).
// Salida 1 si algun flujo paso de PASS a FAIL, a SKIP o desaparecio, o una URL del barrido dejo
// de cargar o de descubrirse; --allow-skips rebaja SKIP/ausente a aviso (ejecuciones de distinto
// alcance). Errores JS o peticiones fallidas nuevos son siempre avisos.
const fs = require('fs');
const path = require('path');
const { compareRuns } = require('../regression/helpers');

const args = process.argv.slice(2);
const allowSkips = args.includes('--allow-skips');
const [beforeLabel = 'before', afterLabel = 'after'] = args.filter((a) => !a.startsWith('--'));
const dir = path.join(__dirname, '..', 'results', 'regression');
const read = (label) => {
  const f = path.join(dir, `${label}.json`);
  if (!fs.existsSync(f)) { console.error(`Falta ${f}. Ejecuta REGRESSION_LABEL=${label} npm run test:regression`); process.exit(2); }
  return JSON.parse(fs.readFileSync(f, 'utf8'));
};
let r;
try { r = compareRuns(read(beforeLabel), read(afterLabel), { allowSkips }); } catch (e) { console.error(`Resultados ilegibles: ${e.message}`); process.exit(2); }
const list = (t, a) => { if (a.length) { console.log(`\n${t} (${a.length})`); a.forEach((x) => console.log(`  - ${x}`)); } };
list('REGRESIONES', r.regressions);
list('AVISOS', r.warnings);
list('ARREGLADOS', r.fixed);
console.log(r.regressions.length ? `\n${r.regressions.length} regresion(es): ${beforeLabel} -> ${afterLabel}` : `\nSin regresiones: ${beforeLabel} -> ${afterLabel}`);
process.exit(r.regressions.length ? 1 : 0);
