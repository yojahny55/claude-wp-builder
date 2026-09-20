// @ts-check
// Agrega los JSON de results/audit/ en un informe Markdown y en uno HTML.
// Sigue la estructura de references/report-template.md del skill: el informe
// generado y el redactado a mano tienen que ser el mismo documento.
// Uso: node scripts/build-report.js  ->  results/informe.md + results/informe.html
//
// Los datos se leen UNA vez en lib/report-data.js y los dos formatos salen de
// ese mismo modelo: si cada uno agregara por su cuenta, acabarian diciendo
// cosas distintas del mismo sitio.
const fs = require('fs');
const path = require('path');
const audit = require('../audit.config');
const H = require('../lib/history');
const LH = require('../lib/lighthouse-report');
const { severity } = require('../lib/plan');
const { collect, clean, porNumero } = require('../lib/report-data');
const renderHTML = require('../lib/report-html');

const DIR = path.join(__dirname, '..', 'results', 'audit');
const HIST = path.join(__dirname, '..', 'results', 'historico');
const FECHA = H.stamp();
const ICON = { pass: '✅', fail: '❌', warn: '⚠️', manual: '🔍', na: '➖' };

if (!fs.existsSync(DIR)) { console.error('No hay resultados. Ejecuta antes: npx playwright test'); process.exit(1); }

const D = collect(DIR, audit);
const {
  pages, lighthouse, dePagina, deSitio, orderPaginas, paginasLH,
  plan, pendientes, media, totalIncidencias, global, tallyPorPagina, tallySitio, altas,
} = D;

const filaDetalle = (r) =>
  `| ${r.c} | ${clean(r.name)} | ${ICON[r.status]} | ${(r.status === 'fail' || r.status === 'warn') ? severity(r) : '—'} | ${clean(r.evidence)} | ${clean(r.rec) || '—'} |\n`;

// --- Ayudas de Lighthouse ---------------------------------------------------
const THL = audit.thresholds.lighthouse;
const WARNP = audit.thresholds.lighthousePerfWarn ?? 85;
// El umbral de aviso solo aplica a rendimiento: en las otras tres, 89 es fallo.
const icono = (key, score) => LH.scoreIcon(score, THL[key], key === 'performance' ? WARNP : THL[key]);
const celda = (key, score) => (score == null ? '—' : `${icono(key, score)} ${score}`);
const metrica = (run, id) => {
  const v = run && run.metrics ? run.metrics[id] : null;
  if (v == null) return '—';
  return LH.CWV.find(x => x.id === id).fmt(v);
};

function tablaFormFactor(ff) {
  let t = `| Pagina | Rendimiento | Accesibilidad | Buenas practicas | SEO | LCP | CLS | TBT |\n`;
  t += `|---|---|---|---|---|---|---|---|\n`;
  for (const name of paginasLH) {
    const run = lighthouse[name][ff.key];
    if (!run) { t += `| ${name} | 🔍 sin medicion | | | | | | |\n`; continue; }
    const s = run.scores;
    t += `| ${name} | ${celda('performance', s.performance)} | ${celda('accessibility', s.accessibility)} `;
    t += `| ${celda('best-practices', s['best-practices'])} | ${celda('seo', s.seo)} `;
    t += `| ${metrica(run, 'largest-contentful-paint')} | ${metrica(run, 'cumulative-layout-shift')} | ${metrica(run, 'total-blocking-time')} |\n`;
  }
  return t + `\n`;
}

// --- Cabecera --------------------------------------------------------------
let md = `# Informe de auditoria web — ${audit.siteName}\n\n`;
md += `**Fecha:** ${FECHA.replace('_', ' ')} · **Auditor:** Claude (Playwright + axe-core + Lighthouse) · `;
md += `**Alcance:** ${orderPaginas.length} paginas · **Base:** ${audit.baseURL}\n\n`;

// --- 1. Resumen ejecutivo --------------------------------------------------
md += `## 1. Resumen ejecutivo\n\n`;
md += `- **Puntuacion global del sitio:** ${global.pass}/${global.pass + global.fail + global.warn} criterios aplicables cumplidos (**${global.pct}%**). `;
md += `Excluidos del denominador: ${global.na} no aplicables y ${global.manual} pendientes de verificacion.\n`;
md += `- **Incumplimientos:** ${global.fail} · **Advertencias:** ${global.warn}.\n`;
if (paginasLH.length) {
  const linea = (ffKey, label) => {
    const p = media(ffKey, 'performance'), a = media(ffKey, 'accessibility');
    const b = media(ffKey, 'best-practices'), s = media(ffKey, 'seo');
    return `  - ${label}: rendimiento ${p ?? '—'}, accesibilidad ${a ?? '—'}, buenas practicas ${b ?? '—'}, SEO ${s ?? '—'}.\n`;
  };
  md += `- **Lighthouse (media de ${paginasLH.length} pagina${paginasLH.length === 1 ? '' : 's'}, sobre 100):**\n`;
  md += linea('desktop', 'Escritorio') + linea('mobile', 'Movil');
  md += `  - ${totalIncidencias} incidencias de Lighthouse a resolver en total (detalle por pagina en §4).\n`;
}
if (altas.length) {
  md += `- **Hallazgos mas importantes (severidad Alta):**\n`;
  for (const t of altas.slice(0, 5)) md += `  - ${t.c} ${clean(t.name)} en ${t.page}: ${clean(t.evidence)}\n`;
} else {
  md += `- **Sin hallazgos de severidad Alta.**\n`;
}
md += `- **Pendientes de verificacion manual o herramienta:** ${global.manual}`;
md += `${pendientes.length ? ` en ${pendientes.length} criterio${pendientes.length === 1 ? '' : 's'} (ver seccion 7)` : ''}.\n\n`;

// Comparativa con la corrida anterior. La instantanea se guarda SIEMPRE; la
// comparativa solo aparece si ya habia una anterior.
const snapshot = H.snapshotFrom(pages);
const previas = H.listSnapshots(HIST);
let comparativa = null;
if (previas.length) {
  const prev = JSON.parse(fs.readFileSync(path.join(HIST, previas[0]), 'utf8'));
  comparativa = { fecha: prev.fecha, pct: prev.pct, pctActual: global.pct, diff: H.compare(prev.resultados, snapshot) };
  md += H.renderComparison(comparativa, comparativa.diff).replace('## Comparativa', '### 1.1 Comparativa');
} else {
  md += `> Primera auditoria registrada (${FECHA.replace('_', ' ')}). La proxima ejecucion de \`npm run audit:build\` incluira aqui la comparativa con esta.\n\n`;
}

// --- 2. Puntuacion por pagina ----------------------------------------------
md += `## 2. Puntuacion por pagina\n\n`;
md += `| Pagina | Cumple | No cumple | Parcial | Manual | N/A | % cumplido |\n|---|---|---|---|---|---|---|\n`;
for (const name of orderPaginas) {
  const t = tallyPorPagina[name];
  md += `| ${name} | ${t.pass} | ${t.fail} | ${t.warn} | ${t.manual} | ${t.na} | ${t.pct}% |\n`;
}
md += `| **Criterios de sitio** | ${tallySitio.pass} | ${tallySitio.fail} | ${tallySitio.warn} | ${tallySitio.manual} | ${tallySitio.na} | ${tallySitio.pct}% |\n`;
md += `| **Total sitio** | ${global.pass} | ${global.fail} | ${global.warn} | ${global.manual} | ${global.na} | **${global.pct}%** |\n\n`;
md += `> El % se calcula sobre los criterios **aplicables** (excluye ➖ No aplica y 🔍 pendientes).\n\n`;

// --- 3. Resumen de Lighthouse ----------------------------------------------
md += `## 3. Resumen de Lighthouse por pagina\n\n`;
if (!paginasLH.length) {
  md += `Sin mediciones de Lighthouse. Ejecuta \`npm run test:perf\` y vuelve a generar el informe.\n\n`;
} else {
  md += `Cada pagina se mide dos veces, con los dos perfiles oficiales de Lighthouse: **escritorio** `;
  md += `(sin ralentizar la CPU, latencia de fibra) y **movil** (CPU 4x mas lenta, red Slow 4G, viewport 412 px). `;
  md += `Las cuatro categorias van sobre 100 y el umbral de la pauta 41 es **> 90** `;
  md += `(rendimiento entre ${WARNP} y ${THL.performance - 1} es advertencia, no fallo).\n\n`;
  md += `### 3.1 Escritorio\n\n${tablaFormFactor(LH.FORM_FACTORS[0])}`;
  md += `### 3.2 Movil\n\n${tablaFormFactor(LH.FORM_FACTORS[1])}`;
  md += `> LCP y TBT en segundos/milisegundos, CLS sin unidad. Objetivos: LCP <= 2,50 s · CLS <= 0,100 · TBT <= 200 ms. `;
  md += `INP no se puede medir en laboratorio: TBT es su proxy reconocido.\n\n`;
  md += `> Las puntuaciones de laboratorio varian +-5 puntos entre ejecuciones. Una diferencia menor no es una mejora ni una regresion.\n\n`;
}

// --- 4. Detalle por pagina --------------------------------------------------
md += `## 4. Detalle por pagina\n\n`;
orderPaginas.forEach((name, i) => {
  md += `### 4.${i + 1} ${name}\n\n**% cumplido:** ${tallyPorPagina[name].pct}%\n\n`;
  md += `| # | Criterio | Estado | Severidad | Evidencia | Recomendacion |\n|---|---|---|---|---|---|\n`;
  for (const r of [...dePagina[name]].sort(porNumero)) md += filaDetalle(r);
  md += `\n`;
  md += bloqueLighthouse(name, `4.${i + 1}`);
});

// Puntuaciones e incidencias de Lighthouse de una pagina. Las incidencias son
// los audits que Lighthouse marca como fallidos, agrupados por categoria y
// fundidos entre escritorio y movil: el mismo audit fallando en los dos es UNA
// incidencia, anotada con en cual de los dos aparece.
function bloqueLighthouse(name, num) {
  const lh = lighthouse[name];
  if (!lh) return '';
  const runs = LH.FORM_FACTORS.map(f => ({ ff: f, run: lh[f.key] })).filter(x => x.run);
  let out = `#### ${num}.1 Lighthouse\n\n`;
  out += `| Categoria | ${runs.map(x => x.ff.label).join(' | ')} |\n|---|${runs.map(() => '---').join('|')}|\n`;
  for (const cat of LH.CATEGORIES) {
    out += `| ${cat.label} | ${runs.map(x => celda(cat.key, x.run.scores[cat.key])).join(' | ')} |\n`;
  }
  for (const m of LH.CWV) {
    out += `| ${m.name} | ${runs.map(x => metrica(x.run, m.id)).join(' | ')} |\n`;
  }
  out += `\n`;

  const incidencias = LH.mergeIssues(lh);
  out += `#### ${num}.2 Incidencias de Lighthouse a resolver\n\n`;
  if (!incidencias.length) {
    out += `Ninguna: los audits de las cuatro categorias pasan en escritorio y en movil.\n\n`;
    return out;
  }
  const porCat = LH.CATEGORIES.filter(c => incidencias.some(i => i.category === c.key));
  const conteo = porCat.map(c => `${incidencias.filter(i => i.category === c.key).length} de ${c.label.toLowerCase()}`);
  out += `${incidencias.length} incidencias: ${conteo.join(', ')}.\n\n`;
  out += `| Categoria | Severidad | Incidencia | Impacto | Donde falla |\n|---|---|---|---|---|\n`;
  for (const i of incidencias) {
    const donde = i.formFactors.length === runs.length ? 'Escritorio y movil' : i.formFactors.join(', ');
    out += `| ${i.categoria} | ${i.sev} | ${clean(i.title)} | ${clean(i.impacto)} | ${donde} |\n`;
  }
  out += `\n> Los elementos concretos de cada incidencia estan en el HTML de Lighthouse: \`results/lighthouse/\`.\n\n`;
  return out;
}

// --- 5. Criterios de sitio --------------------------------------------------
md += `## 5. Criterios de sitio (evaluados una vez)\n\n`;
if (!deSitio.length) {
  md += `Sin criterios de sitio en estos resultados.\n\n`;
} else {
  md += `| # | Criterio | Estado | Severidad | Evidencia | Recomendacion |\n|---|---|---|---|---|---|\n`;
  for (const r of [...deSitio].sort(porNumero)) md += filaDetalle(r);
  md += `\n`;
}

// --- 6. Plan de correccion priorizado ---------------------------------------
md += `## 6. Plan de correccion priorizado\n\n`;
if (!plan.length) {
  md += `Sin incumplimientos ni advertencias.\n\n`;
} else {
  md += `${plan.filter(t => t.status === 'fail').length} incumplimientos y ${plan.filter(t => t.status === 'warn').length} advertencias, de mayor a menor impacto.\n\n`;
  md += `| Prioridad | # | Pagina | Problema | Que hacer | Como se aplica |\n|---|---|---|---|---|---|\n`;
  for (const t of plan) {
    md += `| ${t.sev}${t.status === 'warn' ? ' (aviso)' : ''} | ${t.c} | ${t.page} | ${clean(t.name)}: ${clean(t.evidence)} | ${clean(t.rec) || '—'} | ${t.como} |\n`;
  }
  const porTipo = (tipo) => plan.filter(t => t.como === tipo).length;
  md += `\n**Reparto:** ${porTipo('Codigo')} en codigo del tema · ${porTipo('Ajuste')} en ajustes de WordPress/plugin · `;
  md += `${porTipo('Contenido')} de contenido · ${porTipo('Manual')} de juicio humano o herramienta externa.\n\n`;
  md += `> **Codigo**: archivo del tema; se corrige y viaja con el commit.\n`;
  md += `> **Ajuste**: opcion de WordPress, del plugin SEO o configuracion del servidor; con el sitio en local se aplica con WP-CLI, pero **no viaja con el commit** — hay que repetirlo en el entorno destino.\n`;
  md += `> **Contenido**: hay que escribir o decidir un texto (titulos, descripciones, alt).\n`;
  md += `> **Manual**: juicio humano o herramienta externa; no se automatiza.\n\n`;
  md += `> El criterio 41 va por pagina, con las puntuaciones de esa pagina. Las filas 41.4-41.7 resumen las incidencias de Lighthouse y salen agrupadas: la lista completa por pagina, categoria y form factor esta en §4.\n\n`;
  md += `> Este informe se entrega completo ANTES de aplicar nada. La columna de la derecha es el reparto de trabajo posterior, no un permiso para corregir.\n\n`;
}

// --- 7. Verificaciones pendientes -------------------------------------------
md += `## 7. Verificaciones pendientes (herramientas)\n\n`;
if (!pendientes.length) {
  md += `Ninguna: todos los criterios evaluados por la suite tienen veredicto.\n\n`;
} else {
  md += `Criterios que la suite **no puede decidir sola**: no son fallos ni cumplimientos, son los que `;
  md += `necesitan que una persona los mire o que se pase una herramienta externa. No cuentan en el porcentaje.\n\n`;
  md += `| # | Criterio | Paginas | Que falta |\n|---|---|---|---|\n`;
  for (const r of [...pendientes].sort(porNumero)) {
    const evs = [...r.evidencias].filter(Boolean);
    const falta = !evs.length ? 'Sin evidencia suficiente'
      : (evs.length === 1 ? evs[0] : `${evs[0]} (varia por pagina; el dato de cada una, en §4)`);
    const donde = r.paginas.length <= 3 ? r.paginas.join(', ') : `${r.paginas.length} paginas`;
    md += `| ${r.c} | ${clean(r.name)} | ${donde} | ${falta} |\n`;
  }
  md += `\n`;
}
md += `Fuera del alcance de la suite: el numero literal de GTmetrix (Lighthouse es un proxy), el validador W3C, `;
md += `las pruebas en dispositivos reales y el Rich Results Test de Google para el criterio 54. `;
md += `Los criterios de juicio humano (2, 27, 30, 31, 32, 33, 36, 37) requieren revision de una persona.\n\n`;

// --- Leyenda ----------------------------------------------------------------
md += `## Leyenda\n\n`;
md += `- **Estado:** ✅ Cumple · ❌ No cumple · ⚠️ Parcial/Advertencia · 🔍 Requiere verificacion manual · ➖ No aplica\n`;
md += `- **Severidad** (solo si ❌ o ⚠️): Alta / Media / Baja.\n`;
md += `- El criterio **41** se mide en cada pagina y aparece en la tabla de cada una, con las puntuaciones de esa pagina en escritorio y en movil.\n`;
md += `- Las filas 41.1-41.3 son Core Web Vitals de laboratorio; 41.4-41.7, el resumen de cada categoria de Lighthouse en escritorio y movil; a11y-*, el desglose de axe-core por impacto. Son **evidencia** de los criterios 41 y 45 y no cuentan en el porcentaje, que sigue siendo sobre los criterios numerados del checklist.\n`;
md += `- En las tablas de Lighthouse el icono acompana la puntuacion sobre 100: ✅ >= ${THL.performance} · ⚠️ ${WARNP}-${THL.performance - 1} (solo rendimiento) · ❌ por debajo.\n`;

const RESULTS = path.join(__dirname, '..', 'results');
const out = path.join(RESULTS, 'informe.md');
fs.writeFileSync(out, md);
console.log('Informe Markdown:', out);

// --- HTML -------------------------------------------------------------------
// Mismo contenido, formato presentable: un unico archivo sin dependencias
// externas, que se abre con doble clic y se puede enviar tal cual.
const html = renderHTML({
  data: D, audit, fecha: FECHA, comparativa,
  thresholds: { min: THL, warnPerf: WARNP },
});
const outHtml = path.join(RESULTS, 'informe.html');
fs.writeFileSync(outHtml, html);
console.log('Informe HTML:    ', outHtml);

// Historico: una instantanea y un informe por ejecucion, ambos fechados. El
// informe.md de arriba es siempre el ultimo; estos no se pisan nunca.
const snapFile = H.save(HIST, {
  fecha: FECHA, siteName: audit.siteName, baseURL: audit.baseURL,
  pct: global.pct, totales: global, resultados: snapshot,
  lighthouse: Object.fromEntries(paginasLH.map(n => [n, Object.fromEntries(
    LH.FORM_FACTORS.filter(f => lighthouse[n][f.key]).map(f => [f.key, lighthouse[n][f.key].scores]))])),
});
fs.writeFileSync(path.join(HIST, `informe-${FECHA}.md`), md);
fs.writeFileSync(path.join(HIST, `informe-${FECHA}.html`), html);
console.log('Historico:', snapFile);

// Copia tambien a la raiz del proyecto (un nivel arriba de esta carpeta
// web-portal-audit-playwright/) para que sea facil de encontrar sin entrar
// a la subcarpeta de la plantilla.
fs.copyFileSync(out, path.join(__dirname, '..', '..', 'resultados-auditoria.md'));
fs.copyFileSync(outHtml, path.join(__dirname, '..', '..', 'resultados-auditoria.html'));
console.log('Copia en la raiz del proyecto: resultados-auditoria.md y .html');
