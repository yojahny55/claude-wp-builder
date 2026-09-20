// @ts-check
// Modelo de datos del informe: lee results/audit/ una sola vez y devuelve todo
// lo que necesitan los renderizadores (Markdown y HTML). Vive aparte para que
// las dos salidas digan exactamente lo mismo: si esto se duplicara, un cambio
// en una acabaria no estando en la otra.
const fs = require('fs');
const path = require('path');
const LH = require('./lighthouse-report');
const { isScored, buildPlan, agruparFilasRepetidas, esDeSitio } = require('./plan');

const RANK = { pass: 0, na: 0, manual: 1, warn: 2, fail: 3 };

function tally(items) {
  const t = { pass: 0, fail: 0, warn: 0, manual: 0, na: 0 };
  for (const r of items) { if (!isScored(r.c)) continue; t[r.status]++; }
  const evaluables = t.pass + t.fail + t.warn;
  const pct = evaluables ? Math.round((t.pass / evaluables) * 100) : 0;
  return { ...t, pct };
}

// El pipe parte las tablas Markdown y el salto de linea parte cualquier fila.
const clean = (x) => (x || '').replace(/\|/g, '/').replace(/\n/g, ' ');
const porNumero = (a, b) => String(a.c).localeCompare(String(b.c), undefined, { numeric: true });

function collect(dir, audit) {
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.json'));
  const pages = {};      // pagina -> { criterio -> result }
  const lighthouse = {}; // pagina -> { desktop, mobile } tal como lo guarda performance.spec.js

  for (const f of files) {
    const data = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
    const name = data.page;
    pages[name] = pages[name] || {};
    // Las filas 41 y 41.x se recalculan desde la medicion guardada en vez de
    // leerse tal cual: asi un cambio de umbral o de redaccion se aplica al
    // informe sin tener que volver a medir el sitio entero.
    const medido = data.lighthouse && Object.keys(data.lighthouse).length;
    const results = medido
      ? LH.combinedRows(data.lighthouse, audit.thresholds,
        { topAudits: audit.thresholds.lighthouseTopAudits ?? 6 })
      : data.results;
    // Mezclando navegadores nos quedamos con el peor estado de cada criterio.
    for (const r of results) {
      const cur = pages[name][r.c];
      if (!cur || RANK[r.status] > RANK[cur.status]) pages[name][r.c] = r;
    }
    if (medido) lighthouse[name] = data.lighthouse;
  }

  // Reparto pagina / sitio segun la clasificacion del skill: los criterios de
  // sitio se evaluan una vez y van en su propia seccion, no repetidos por pagina.
  const dePagina = {};
  const deSitio = [];
  for (const [name, byCrit] of Object.entries(pages)) {
    for (const r of Object.values(byCrit)) {
      if (esDeSitio(r.c, name)) {
        const prev = deSitio.find(x => String(x.c) === String(r.c));
        if (!prev) deSitio.push({ ...r, page: name });
        else if (RANK[r.status] > RANK[prev.status]) Object.assign(prev, r, { page: name });
      } else {
        (dePagina[name] = dePagina[name] || []).push(r);
      }
    }
  }

  const orderPaginas = Object.keys(dePagina);
  const todas = [...Object.values(dePagina).flat(), ...deSitio];

  // Los criterios de sitio y el resumen por categoria de Lighthouse (41.4-41.7)
  // van en una sola fila con las paginas afectadas; el criterio 41 y los Core
  // Web Vitals van por pagina, que es como se miden.
  const plan = agruparFilasRepetidas(buildPlan(pages));

  // Criterios que la suite no puede decidir sola. Se agrupan por criterio con
  // las paginas donde quedaron pendientes: el mismo criterio repetido una vez
  // por pagina, sin decir cual, no le sirve a nadie.
  const pendientes = [];
  for (const [page, byCrit] of Object.entries(pages)) {
    for (const r of Object.values(byCrit)) {
      if (r.status !== 'manual') continue;
      const prev = pendientes.find(x => String(x.c) === String(r.c));
      if (prev) { prev.paginas.push(page); prev.evidencias.add(clean(r.evidence)); }
      else pendientes.push({ ...r, paginas: [page], evidencias: new Set([clean(r.evidence)]) });
    }
  }

  // Paginas con medicion de Lighthouse, en el orden del informe.
  const paginasLH = [...orderPaginas.filter(n => lighthouse[n]),
                     ...Object.keys(lighthouse).filter(n => !orderPaginas.includes(n))];

  // Media de una categoria en un form factor: la foto del sitio de un vistazo.
  const media = (ffKey, catKey) => {
    const vals = paginasLH
      .map(n => lighthouse[n][ffKey] && lighthouse[n][ffKey].scores[catKey])
      .filter(v => v != null);
    return vals.length ? Math.round(vals.reduce((a, b) => a + b, 0) / vals.length) : null;
  };
  const totalIncidencias = paginasLH.reduce((n, name) => n + LH.mergeIssues(lighthouse[name]).length, 0);

  return {
    pages, lighthouse, dePagina, deSitio, orderPaginas, todas, paginasLH,
    plan, pendientes, media, totalIncidencias,
    global: tally(todas),
    tallyPorPagina: Object.fromEntries(orderPaginas.map(n => [n, tally(dePagina[n])])),
    tallySitio: tally(deSitio),
    altas: plan.filter(t => t.sev === 'Alta'),
  };
}

module.exports = { collect, tally, clean, porNumero, RANK };
