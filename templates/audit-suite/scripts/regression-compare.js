// @ts-check
// node scripts/regression-compare.js [antes] [despues]
// Compara results/regression/<antes>.json con <despues>.json (por defecto before / after).
// Salida 1 si algun flujo paso de PASS a FAIL o una URL del barrido dejo de cargar; los
// avisos (PASS -> SKIP, errores JS o peticiones fallidas nuevos) no cambian el codigo.
const fs = require('fs');
const path = require('path');
const { compareRuns } = require('../regression/helpers');

const [beforeLabel = 'before', afterLabel = 'after'] = process.argv.slice(2);
const dir = path.join(__dirname, '..', 'results', 'regression');
const read = (label) => {
  const f = path.join(dir, `${label}.json`);
  if (!fs.existsSync(f)) { console.error(`Falta ${f}. Ejecuta REGRESSION_LABEL=${label} npm run test:regression`); process.exit(2); }
  return JSON.parse(fs.readFileSync(f, 'utf8'));
};
const r = compareRuns(read(beforeLabel), read(afterLabel));
const list = (t, a) => { if (a.length) { console.log(`\n${t} (${a.length})`); a.forEach((x) => console.log(`  - ${x}`)); } };
list('REGRESIONES', r.regressions);
list('AVISOS', r.warnings);
list('ARREGLADOS', r.fixed);
console.log(r.regressions.length ? `\n${r.regressions.length} regresion(es): ${beforeLabel} -> ${afterLabel}` : `\nSin regresiones: ${beforeLabel} -> ${afterLabel}`);
process.exit(r.regressions.length ? 1 : 0);
