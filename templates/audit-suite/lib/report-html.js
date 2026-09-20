// @ts-check
// Renderiza el modelo de lib/report-data.js como un informe HTML de una sola
// pieza: sin CSS ni JS externos, sin fuentes remotas y sin peticiones de red.
// Se abre con doble clic, se envia por correo tal cual y se imprime a PDF desde
// el navegador. Mismo contenido y mismo orden que el Markdown.
const LH = require('./lighthouse-report');
const { severity } = require('./plan');

const esc = (x) => String(x ?? '')
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;');

const ESTADO = {
  pass: { icon: '✅', label: 'Cumple' },
  fail: { icon: '❌', label: 'No cumple' },
  warn: { icon: '⚠️', label: 'Parcial' },
  manual: { icon: '🔍', label: 'Verificacion manual' },
  na: { icon: '➖', label: 'No aplica' },
};

const chipEstado = (s) => `<span class="chip e-${s}" title="${esc(ESTADO[s].label)}">${ESTADO[s].icon} ${esc(ESTADO[s].label)}</span>`;
const chipSev = (sev) => `<span class="chip s-${String(sev).toLowerCase()}">${esc(sev)}</span>`;
const slug = (s) => String(s).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const pct = (n) => `${n}%`;

// Barra de porcentaje: el numero solo no deja comparar paginas de un vistazo.
const barra = (n) => `<span class="bar"><span class="bar-fill ${n >= 90 ? 'ok' : n >= 70 ? 'mid' : 'bad'}" style="width:${Math.max(0, Math.min(100, n))}%"></span></span>`;

function render({ data, audit, fecha, comparativa, thresholds }) {
  const D = data;
  const THL = thresholds.min;
  const WARNP = thresholds.warnPerf;
  const nivel = (key, score) => score == null ? 'na'
    : (score >= THL[key] ? 'ok' : (key === 'performance' && score >= WARNP ? 'mid' : 'bad'));
  const score = (key, s) => s == null ? '<span class="score na">—</span>'
    : `<span class="score ${nivel(key, s)}">${s}</span>`;
  const metrica = (run, id) => {
    const v = run && run.metrics ? run.metrics[id] : null;
    if (v == null) return '—';
    const m = LH.CWV.find(x => x.id === id);
    const st = v <= (audit.thresholds.cwv[id] ?? m.good) ? 'ok' : (v <= m.poor ? 'mid' : 'bad');
    return `<span class="metric ${st}">${esc(m.fmt(v))}</span>`;
  };

  const filaDetalle = (r) => `<tr data-estado="${r.status}">
      <td class="num">${esc(r.c)}</td>
      <td>${esc(r.name)}</td>
      <td>${chipEstado(r.status)}</td>
      <td>${(r.status === 'fail' || r.status === 'warn') ? chipSev(severity(r)) : '<span class="muted">—</span>'}</td>
      <td class="ev">${esc(r.evidence)}</td>
      <td class="ev">${r.rec ? esc(r.rec) : '<span class="muted">—</span>'}</td>
    </tr>`;

  const tablaDetalle = (filas) => `<div class="scroll"><table class="detalle">
      <thead><tr><th>#</th><th>Criterio</th><th>Estado</th><th>Severidad</th><th>Evidencia</th><th>Recomendacion</th></tr></thead>
      <tbody>${filas.map(filaDetalle).join('')}</tbody></table></div>`;

  // --- Cabecera y resumen ---------------------------------------------------
  const evaluables = D.global.pass + D.global.fail + D.global.warn;
  let h = '';

  h += `<header class="top">
    <div class="wrap">
      <p class="kicker">Informe de auditoria web · 56 criterios</p>
      <h1>${esc(audit.siteName)}</h1>
      <p class="meta">${esc(fecha.replace('_', ' '))} · ${D.orderPaginas.length} paginas ·
        <a href="${esc(audit.baseURL)}">${esc(audit.baseURL)}</a></p>
      <p class="meta">Auditor: Claude (Playwright + axe-core + Lighthouse)</p>
      <div class="kpis">
        <div class="kpi big"><b>${D.global.pct}%</b><span>cumplimiento<br>${D.global.pass} de ${evaluables} criterios aplicables</span></div>
        <div class="kpi"><b class="bad">${D.global.fail}</b><span>incumplimientos</span></div>
        <div class="kpi"><b class="mid">${D.global.warn}</b><span>advertencias</span></div>
        <div class="kpi"><b class="info">${D.global.manual}</b><span>pendientes de verificar</span></div>
      </div>
    </div>
  </header>`;

  // Indice: el informe es largo y se consulta por partes.
  const secciones = [
    ['s1', '1. Resumen ejecutivo'], ['s2', '2. Puntuacion por pagina'],
    ['s3', '3. Resumen de Lighthouse'], ['s4', '4. Detalle por pagina'],
    ['s5', '5. Criterios de sitio'], ['s6', '6. Plan de correccion'],
    ['s7', '7. Verificaciones pendientes'], ['leyenda', 'Leyenda'],
  ];
  h += `<nav class="toc"><div class="wrap">${secciones.map(([id, t]) => `<a href="#${id}">${esc(t)}</a>`).join('')}</div></nav>`;

  h += `<main class="wrap">`;

  // --- 1. Resumen ejecutivo -------------------------------------------------
  h += `<section id="s1"><h2>1. Resumen ejecutivo</h2>`;
  h += `<p><b>Puntuacion global del sitio:</b> ${D.global.pass}/${evaluables} criterios aplicables cumplidos
    (<b>${D.global.pct}%</b>). Excluidos del denominador: ${D.global.na} no aplicables y ${D.global.manual} pendientes de verificacion.</p>`;

  if (D.paginasLH.length) {
    const fila = (ffKey, label) => `<tr><th>${esc(label)}</th>${
      LH.CATEGORIES_DISPLAY.map(c => `<td>${score(c.key, D.media(ffKey, c.key))}</td>`).join('')}</tr>`;
    h += `<h3>Lighthouse, media de ${D.paginasLH.length} pagina${D.paginasLH.length === 1 ? '' : 's'}</h3>
      <div class="scroll"><table class="compact">
        <thead><tr><th>Perfil</th>${LH.CATEGORIES_DISPLAY.map(c => `<th>${esc(c.label)}</th>`).join('')}</tr></thead>
        <tbody>${fila('desktop', 'Escritorio')}${fila('mobile', 'Movil')}</tbody></table></div>
      <p class="muted">${D.totalIncidencias} incidencias de Lighthouse a resolver en total; el detalle de cada pagina esta en la seccion 4.</p>`;
  }

  if (D.altas.length) {
    h += `<h3>Hallazgos mas importantes (severidad Alta)</h3><ul class="hallazgos">`;
    for (const t of D.altas.slice(0, 5)) {
      h += `<li><b>${esc(t.c)} ${esc(t.name)}</b> en ${esc(t.page)}<br><span class="ev">${esc(t.evidence)}</span></li>`;
    }
    h += `</ul>`;
  } else {
    h += `<p class="ok-box">Sin hallazgos de severidad Alta.</p>`;
  }

  // 1.1 Comparativa
  if (comparativa) {
    const delta = comparativa.pctActual - comparativa.pct;
    const filas = (arr, cambio) => arr.map(r => `<tr><td class="num">${esc(r.c)}</td><td>${esc(r.page)}</td>
      <td>${esc(r.name || '')}</td><td>${cambio(r)}</td></tr>`).join('');
    h += `<h3 id="s1-1">1.1 Comparativa con la auditoria anterior</h3>
      <p>Anterior: <b>${esc(comparativa.fecha)}</b> (${comparativa.pct}%) · Actual: <b>${comparativa.pctActual}%</b> ·
      <b class="${delta > 0 ? 'ok' : delta < 0 ? 'bad' : 'muted'}">${delta > 0 ? `+${delta} puntos` : delta < 0 ? `${delta} puntos` : 'sin cambio'}</b></p>`;
    const LABEL = { pass: 'CUMPLE', fail: 'NO CUMPLE', warn: 'ADVERTENCIA', manual: 'REVISION MANUAL', na: 'N/A' };
    const bloque = (titulo, arr, cambio) => arr.length ? `<h4>${esc(titulo)} (${arr.length})</h4>
      <div class="scroll"><table class="compact"><thead><tr><th>#</th><th>Pagina</th><th>Criterio</th><th>Cambio</th></tr></thead>
      <tbody>${filas(arr, cambio)}</tbody></table></div>` : '';
    h += bloque('Empeoraron', comparativa.diff.regresiones, (r) => `${LABEL[r.antes]} → <b class="bad">${LABEL[r.status]}</b>`);
    h += bloque('Mejoraron', comparativa.diff.mejoras, (r) => `${LABEL[r.antes]} → <b class="ok">${LABEL[r.status]}</b>`);
    h += bloque('Comprobaciones nuevas', comparativa.diff.nuevos, (r) => LABEL[r.status]);
    if (!comparativa.diff.regresiones.length && !comparativa.diff.mejoras.length) {
      h += `<p class="muted">Ningun criterio cambio de estado.</p>`;
    }
  } else {
    h += `<p class="nota">Primera auditoria registrada (${esc(fecha.replace('_', ' '))}). La proxima ejecucion incluira aqui la comparativa con esta.</p>`;
  }
  h += `</section>`;

  // --- 2. Puntuacion por pagina --------------------------------------------
  h += `<section id="s2"><h2>2. Puntuacion por pagina</h2><div class="scroll"><table class="compact">
    <thead><tr><th>Pagina</th><th>Cumple</th><th>No cumple</th><th>Parcial</th><th>Manual</th><th>N/A</th><th>% cumplido</th></tr></thead><tbody>`;
  for (const name of D.orderPaginas) {
    const t = D.tallyPorPagina[name];
    h += `<tr><td><a href="#p-${slug(name)}">${esc(name)}</a></td><td>${t.pass}</td><td>${t.fail}</td>
      <td>${t.warn}</td><td>${t.manual}</td><td>${t.na}</td><td class="pctcell">${barra(t.pct)} ${pct(t.pct)}</td></tr>`;
  }
  const tS = D.tallySitio;
  h += `<tr class="sum"><td>Criterios de sitio</td><td>${tS.pass}</td><td>${tS.fail}</td><td>${tS.warn}</td>
      <td>${tS.manual}</td><td>${tS.na}</td><td class="pctcell">${barra(tS.pct)} ${pct(tS.pct)}</td></tr>
    <tr class="sum total"><td>Total sitio</td><td>${D.global.pass}</td><td>${D.global.fail}</td><td>${D.global.warn}</td>
      <td>${D.global.manual}</td><td>${D.global.na}</td><td class="pctcell">${barra(D.global.pct)} <b>${pct(D.global.pct)}</b></td></tr>
    </tbody></table></div>
    <p class="nota">El % se calcula sobre los criterios <b>aplicables</b>: excluye los ➖ no aplica y los 🔍 pendientes.</p></section>`;

  // --- 3. Resumen de Lighthouse --------------------------------------------
  h += `<section id="s3"><h2>3. Resumen de Lighthouse por pagina</h2>`;
  if (!D.paginasLH.length) {
    h += `<p class="nota">Sin mediciones de Lighthouse. Ejecuta <code>npm run test:perf</code> y vuelve a generar el informe.</p>`;
  } else {
    h += `<p>Cada pagina se mide dos veces, con los dos perfiles oficiales de Lighthouse: <b>escritorio</b>
      (sin ralentizar la CPU, latencia de fibra) y <b>movil</b> (CPU 4x mas lenta, red Slow 4G, viewport de 412 px).
      Las cuatro categorias van sobre 100 y el umbral de la pauta 41 es <b>&gt; ${THL.performance}</b>;
      en rendimiento, ${WARNP}-${THL.performance - 1} es advertencia, no fallo.</p>`;
    for (const ff of LH.FORM_FACTORS) {
      h += `<h3>${esc(ff.label)}</h3><div class="scroll"><table class="compact lh">
        <thead><tr><th>Pagina</th>${LH.CATEGORIES_DISPLAY.map(c => `<th>${esc(c.label)}</th>`).join('')}<th>LCP</th><th>CLS</th><th>TBT</th></tr></thead><tbody>`;
      for (const name of D.paginasLH) {
        const run = D.lighthouse[name][ff.key];
        if (!run) { h += `<tr><td>${esc(name)}</td><td colspan="7" class="muted">🔍 sin medicion</td></tr>`; continue; }
        h += `<tr><td><a href="#p-${slug(name)}">${esc(name)}</a></td>`;
        h += LH.CATEGORIES_DISPLAY.map(c => `<td>${score(c.key, run.scores[c.key])}</td>`).join('');
        h += `<td>${metrica(run, 'largest-contentful-paint')}</td><td>${metrica(run, 'cumulative-layout-shift')}</td>
          <td>${metrica(run, 'total-blocking-time')}</td></tr>`;
      }
      h += `</tbody></table></div>`;
    }
    h += `<p class="nota">Objetivos de los Core Web Vitals: LCP ≤ 2,50 s · CLS ≤ 0,100 · TBT ≤ 200 ms.
      INP no se puede medir en laboratorio: TBT es su proxy reconocido.<br>
      Las puntuaciones de laboratorio varian ±5 puntos entre ejecuciones: una diferencia menor no es una mejora ni una regresion.</p>`;
  }
  h += `</section>`;

  // --- 4. Detalle por pagina ------------------------------------------------
  h += `<section id="s4"><h2>4. Detalle por pagina</h2>
    <div class="filtros" role="group" aria-label="Filtrar criterios por estado">
      <span>Ver:</span>
      <button type="button" class="f on" data-filtro="todos">Todos</button>
      <button type="button" class="f" data-filtro="fail">Solo incumplimientos</button>
      <button type="button" class="f" data-filtro="problemas">Incumplimientos y advertencias</button>
    </div>`;
  D.orderPaginas.forEach((name, i) => {
    const t = D.tallyPorPagina[name];
    const lh = D.lighthouse[name];
    h += `<details class="pagina" id="p-${slug(name)}"${i === 0 ? ' open' : ''}>
      <summary><span class="pnum">4.${i + 1}</span> <b>${esc(name)}</b>
        <span class="pill">${pct(t.pct)} cumplido</span>
        ${t.fail ? `<span class="pill bad">${t.fail} incumple</span>` : ''}
        ${t.warn ? `<span class="pill mid">${t.warn} parcial</span>` : ''}</summary>`;
    h += tablaDetalle([...D.dePagina[name]].sort((a, b) => String(a.c).localeCompare(String(b.c), undefined, { numeric: true })));

    if (lh) {
      const runs = LH.FORM_FACTORS.map(f => ({ ff: f, run: lh[f.key] })).filter(x => x.run);
      h += `<h4>4.${i + 1}.1 Lighthouse</h4><div class="scroll"><table class="compact lh">
        <thead><tr><th>Categoria</th>${runs.map(x => `<th>${esc(x.ff.label)}</th>`).join('')}</tr></thead><tbody>`;
      for (const cat of LH.CATEGORIES_DISPLAY) {
        h += `<tr><th>${esc(cat.label)}</th>${runs.map(x => `<td>${score(cat.key, x.run.scores[cat.key])}</td>`).join('')}</tr>`;
      }
      for (const m of LH.CWV) {
        h += `<tr><th>${esc(m.name)}</th>${runs.map(x => `<td>${metrica(x.run, m.id)}</td>`).join('')}</tr>`;
      }
      h += `</tbody></table></div>`;

      const incidencias = LH.mergeIssues(lh);
      h += `<h4>4.${i + 1}.2 Incidencias de Lighthouse a resolver</h4>`;
      if (!incidencias.length) {
        h += `<p class="ok-box">Ninguna: los audits de las cuatro categorias pasan en escritorio y en movil.</p>`;
      } else {
        const conteo = LH.CATEGORIES_DISPLAY.filter(c => incidencias.some(x => x.category === c.key))
          .map(c => `${incidencias.filter(x => x.category === c.key).length} de ${c.label.toLowerCase()}`);
        h += `<p>${incidencias.length} incidencias: ${esc(conteo.join(', '))}.</p>`;
        h += `<div class="scroll"><table class="compact">
          <thead><tr><th>Categoria</th><th>Severidad</th><th>Incidencia</th><th>Impacto</th><th>Donde falla</th></tr></thead><tbody>`;
        for (const x of incidencias) {
          const donde = x.formFactors.length === runs.length ? 'Escritorio y movil' : x.formFactors.join(', ');
          h += `<tr><td>${esc(x.categoria)}</td><td>${chipSev(x.sev)}</td><td>${esc(x.title)}</td>
            <td class="nowrap">${esc(x.impacto)}</td><td class="nowrap">${esc(donde)}</td></tr>`;
        }
        h += `</tbody></table></div>
          <p class="nota">Los elementos concretos de cada incidencia estan en el HTML de Lighthouse: <code>results/lighthouse/</code>.</p>`;
      }
    }
    h += `</details>`;
  });
  h += `</section>`;

  // --- 5. Criterios de sitio ------------------------------------------------
  h += `<section id="s5"><h2>5. Criterios de sitio (evaluados una vez)</h2>`;
  h += D.deSitio.length
    ? `<p>Criterios que se comprueban comparando entre paginas o a nivel global.</p>`
      + tablaDetalle([...D.deSitio].sort((a, b) => String(a.c).localeCompare(String(b.c), undefined, { numeric: true })))
    : `<p class="nota">Sin criterios de sitio en estos resultados.</p>`;
  h += `</section>`;

  // --- 6. Plan de correccion ------------------------------------------------
  h += `<section id="s6"><h2>6. Plan de correccion priorizado</h2>`;
  if (!D.plan.length) {
    h += `<p class="ok-box">Sin incumplimientos ni advertencias.</p>`;
  } else {
    const fails = D.plan.filter(t => t.status === 'fail').length;
    const warns = D.plan.filter(t => t.status === 'warn').length;
    const porTipo = (tipo) => D.plan.filter(t => t.como === tipo).length;
    h += `<p>${fails} incumplimientos y ${warns} advertencias, de mayor a menor impacto.</p>`;
    h += `<div class="scroll"><table class="compact plan">
      <thead><tr><th>Prioridad</th><th>#</th><th>Pagina</th><th>Problema</th><th>Que hacer</th><th>Como se aplica</th></tr></thead><tbody>`;
    for (const t of D.plan) {
      h += `<tr><td class="nowrap">${chipSev(t.sev)}${t.status === 'warn' ? '<span class="muted"> aviso</span>' : ''}</td>
        <td class="num">${esc(t.c)}</td><td>${esc(t.page)}</td>
        <td><b>${esc(t.name)}</b><br><span class="ev" title="${esc(t.evidence)}">${esc(t.evidence)}</span></td>
        <td class="ev">${t.rec ? esc(t.rec) : '<span class="muted">—</span>'}</td>
        <td class="nowrap"><span class="tag t-${slug(t.como)}">${esc(t.como)}</span></td></tr>`;
    }
    h += `</tbody></table></div>`;
    h += `<p class="reparto"><b>Reparto:</b> ${porTipo('Codigo')} en codigo del tema ·
      ${porTipo('Ajuste')} en ajustes de WordPress o del plugin · ${porTipo('Contenido')} de contenido ·
      ${porTipo('Manual')} de juicio humano o herramienta externa.</p>
      <ul class="leyenda-plan">
        <li><span class="tag t-codigo">Codigo</span> archivo del tema; se corrige y viaja con el commit.</li>
        <li><span class="tag t-ajuste">Ajuste</span> opcion de WordPress, del plugin SEO o configuracion del servidor. Con el sitio en local se aplica con WP-CLI, pero <b>no viaja con el commit</b>: hay que repetirlo en el entorno destino.</li>
        <li><span class="tag t-contenido">Contenido</span> hay que escribir o decidir un texto: titulos, descripciones, textos alternativos.</li>
        <li><span class="tag t-manual">Manual</span> juicio humano o herramienta externa; no se automatiza.</li>
      </ul>
      <p class="nota">El criterio 41 va por pagina, con las puntuaciones de esa pagina. Las filas 41.4-41.7 resumen las
      incidencias de Lighthouse y salen agrupadas: la lista completa por pagina y categoria esta en la seccion 4.<br>
      Este informe se entrega completo antes de aplicar nada. La ultima columna es el reparto del trabajo posterior,
      no un permiso para corregir.</p>`;
  }
  h += `</section>`;

  // --- 7. Verificaciones pendientes ----------------------------------------
  h += `<section id="s7"><h2>7. Verificaciones pendientes (herramientas)</h2>`;
  if (!D.pendientes.length) {
    h += `<p class="ok-box">Ninguna: todos los criterios evaluados por la suite tienen veredicto.</p>`;
  } else {
    h += `<p>Criterios que la suite <b>no puede decidir sola</b>: no son fallos ni cumplimientos, son los que necesitan
      que una persona los mire o que se pase una herramienta externa. No cuentan en el porcentaje.</p>
      <div class="scroll"><table class="compact"><thead><tr><th>#</th><th>Criterio</th><th>Paginas</th><th>Que falta</th></tr></thead><tbody>`;
    for (const r of [...D.pendientes].sort((a, b) => String(a.c).localeCompare(String(b.c), undefined, { numeric: true }))) {
      const evs = [...r.evidencias].filter(Boolean);
      const falta = !evs.length ? 'Sin evidencia suficiente'
        : (evs.length === 1 ? evs[0] : `${evs[0]} (varia por pagina; el dato de cada una, en la seccion 4)`);
      const donde = r.paginas.length <= 3 ? r.paginas.join(', ') : `${r.paginas.length} paginas`;
      h += `<tr><td class="num">${esc(r.c)}</td><td>${esc(r.name)}</td><td class="nowrap">${esc(donde)}</td><td class="ev">${esc(falta)}</td></tr>`;
    }
    h += `</tbody></table></div>`;
  }
  h += `<p class="nota">Fuera del alcance de la suite: el numero literal de GTmetrix (Lighthouse es un proxy), el
    validador del W3C, las pruebas en dispositivos reales y el Rich Results Test de Google para el criterio 54.
    Los criterios de juicio humano (2, 27, 30, 31, 32, 33, 36, 37) requieren revision de una persona.</p></section>`;

  // --- Leyenda --------------------------------------------------------------
  h += `<section id="leyenda"><h2>Leyenda</h2><ul class="leyenda">
    <li>${Object.entries(ESTADO).map(([k, v]) => `<span class="chip e-${k}">${v.icon} ${esc(v.label)}</span>`).join(' ')}</li>
    <li><b>Severidad</b> (solo en ❌ y ⚠️): ${chipSev('Alta')} ${chipSev('Media')} ${chipSev('Baja')}</li>
    <li>El criterio <b>41</b> se mide en cada pagina y aparece en la tabla de cada una, con sus puntuaciones en escritorio y en movil.</li>
    <li>Las filas 41.1-41.3 son Core Web Vitals de laboratorio; 41.4-41.7, el resumen de cada categoria de Lighthouse;
      a11y-*, el desglose de axe-core por impacto. Son <b>evidencia</b> de los criterios 41 y 45 y no cuentan en el porcentaje.</li>
    <li>En las tablas de Lighthouse el color acompana la puntuacion sobre 100:
      <span class="score ok">${THL.performance}</span> o mas cumple ·
      <span class="score mid">${WARNP}</span> a ${THL.performance - 1} es advertencia, solo en rendimiento ·
      <span class="score bad">${WARNP - 1}</span> o menos no cumple.</li>
  </ul></section>`;

  h += `</main>
  <footer class="wrap"><p>Generado por el skill <b>web-portal-audit</b> · ${esc(fecha.replace('_', ' '))} ·
    ${esc(audit.siteName)}</p></footer>`;

  return page(audit, h);
}

// Filtro por estado en las tablas de detalle. Sin librerias: son ~15 lineas.
const SCRIPT = `
document.querySelectorAll('.filtros').forEach(function (grupo) {
  grupo.addEventListener('click', function (ev) {
    var btn = ev.target.closest('button[data-filtro]');
    if (!btn) return;
    var modo = btn.dataset.filtro;
    grupo.querySelectorAll('button').forEach(function (b) { b.classList.toggle('on', b === btn); });
    document.querySelectorAll('table.detalle tbody tr').forEach(function (tr) {
      var e = tr.dataset.estado;
      var ver = modo === 'todos' || (modo === 'fail' && e === 'fail')
        || (modo === 'problemas' && (e === 'fail' || e === 'warn'));
      tr.hidden = !ver;
    });
    if (modo !== 'todos') document.querySelectorAll('details.pagina').forEach(function (d) { d.open = true; });
  });
});`;

const CSS = `
:root{
  --tinta:#1b1f24; --suave:#5b6672; --linea:#e3e7ec; --fondo:#f6f7f9; --papel:#fff;
  --ok:#1a7f4b; --ok-b:#e6f4ec; --bad:#c0362c; --bad-b:#fbeae8;
  --mid:#9a6a00; --mid-b:#fdf3e0; --info:#2b5fa8; --info-b:#e9f0fb; --na:#7a828c; --na-b:#eef0f3;
}
*{box-sizing:border-box}
body{margin:0;background:var(--fondo);color:var(--tinta);
  font:15px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
  -webkit-text-size-adjust:100%}
.wrap{max-width:1180px;margin:0 auto;padding:0 24px}
a{color:var(--info)}
h1{font-size:30px;margin:.1em 0 .2em;letter-spacing:-.01em}
h2{font-size:22px;margin:0 0 16px;padding-bottom:8px;border-bottom:2px solid var(--linea)}
h3{font-size:17px;margin:26px 0 10px}
h4{font-size:15px;margin:22px 0 8px;color:var(--suave);text-transform:uppercase;letter-spacing:.04em}
p{margin:0 0 12px}
code{background:var(--na-b);padding:1px 5px;border-radius:4px;font-size:.9em}

.top{background:var(--papel);border-bottom:1px solid var(--linea);padding:34px 0 26px}
.kicker{margin:0;color:var(--suave);font-size:12px;text-transform:uppercase;letter-spacing:.1em}
.meta{margin:2px 0;color:var(--suave);font-size:13.5px}
.kpis{display:flex;flex-wrap:wrap;gap:12px;margin-top:20px}
.kpi{background:var(--fondo);border:1px solid var(--linea);border-radius:10px;padding:12px 16px;min-width:132px}
.kpi b{display:block;font-size:26px;line-height:1.1}
.kpi span{color:var(--suave);font-size:12.5px}
.kpi.big{background:var(--info-b);border-color:#cfe0f6}
.kpi.big b{font-size:34px;color:var(--info)}

.toc{position:sticky;top:0;z-index:5;background:rgba(255,255,255,.96);border-bottom:1px solid var(--linea);
  backdrop-filter:saturate(1.6) blur(6px)}
.toc .wrap{display:flex;gap:4px;overflow-x:auto;padding-top:6px;padding-bottom:6px}
.toc a{white-space:nowrap;padding:6px 10px;border-radius:7px;text-decoration:none;color:var(--suave);font-size:13px}
.toc a:hover{background:var(--na-b);color:var(--tinta)}

main{padding:28px 24px 60px}
section{background:var(--papel);border:1px solid var(--linea);border-radius:12px;padding:24px;margin:0 0 22px}
/* El indice es sticky: sin esto, al saltar a una seccion el titulo queda debajo. */
section,details.pagina,h3,h4{scroll-margin-top:64px}

.scroll{overflow-x:auto;-webkit-overflow-scrolling:touch;margin:0 0 12px}
table{border-collapse:collapse;width:100%;font-size:13.5px}
th,td{text-align:left;vertical-align:top;padding:8px 10px;border-bottom:1px solid var(--linea)}
thead th{background:var(--fondo);color:var(--suave);font-size:12px;text-transform:uppercase;
  letter-spacing:.04em;position:sticky;top:0;white-space:nowrap}
tbody tr:hover{background:#fafbfc}
td.num{font-variant-numeric:tabular-nums;white-space:nowrap;font-weight:600}
td.nowrap,th.nowrap{white-space:nowrap}
td.ev{color:var(--suave);max-width:430px;word-break:break-word}
.muted{color:var(--na)}
tr.sum td{background:var(--fondo);font-weight:600}
tr.total td{border-top:2px solid var(--linea)}
.pctcell{white-space:nowrap;font-variant-numeric:tabular-nums}
table.detalle td:nth-child(2){min-width:170px}
/* Sin anchos minimos, la evidencia larga (una cadena de redirects) se come la
   fila y deja "Que hacer" en una palabra por linea. */
table.plan td:nth-child(3){min-width:110px}
table.plan td:nth-child(4){min-width:300px}
table.plan td:nth-child(5){min-width:220px}
/* Solo el <span> de evidencia, NUNCA el <td class="ev">: un display:block sobre
   la celda la saca del layout de la tabla y deja la fila descuadrada. */
table.plan span.ev{display:block;margin-top:2px}
/* Una cadena de redirects puede ocupar 15 lineas y descuadra el plan entero.
   Se recorta en pantalla, con el texto completo en el tooltip; al imprimir va entera. */
table.plan span.ev{display:-webkit-box;-webkit-line-clamp:6;-webkit-box-orient:vertical;overflow:hidden}

.bar{display:inline-block;width:74px;height:7px;background:var(--na-b);border-radius:4px;overflow:hidden;vertical-align:middle;margin-right:6px}
.bar-fill{display:block;height:100%}
.bar-fill.ok{background:var(--ok)} .bar-fill.mid{background:var(--mid)} .bar-fill.bad{background:var(--bad)}

.chip{display:inline-block;padding:2px 8px;border-radius:999px;font-size:12px;white-space:nowrap;border:1px solid transparent}
.e-pass{background:var(--ok-b);color:var(--ok);border-color:#c6e6d5}
.e-fail{background:var(--bad-b);color:var(--bad);border-color:#f2cfcb}
.e-warn{background:var(--mid-b);color:var(--mid);border-color:#f0dcb4}
.e-manual{background:var(--info-b);color:var(--info);border-color:#cfe0f6}
.e-na{background:var(--na-b);color:var(--na);border-color:#dfe3e8}
.s-alta{background:var(--bad-b);color:var(--bad);border-color:#f2cfcb;font-weight:600}
.s-media{background:var(--mid-b);color:var(--mid);border-color:#f0dcb4}
.s-baja{background:var(--na-b);color:var(--na);border-color:#dfe3e8}

.score{display:inline-block;min-width:34px;text-align:center;padding:2px 7px;border-radius:6px;
  font-weight:600;font-variant-numeric:tabular-nums}
.score.ok{background:var(--ok-b);color:var(--ok)}
.score.mid{background:var(--mid-b);color:var(--mid)}
.score.bad{background:var(--bad-b);color:var(--bad)}
.score.na{background:var(--na-b);color:var(--na)}
.metric{font-variant-numeric:tabular-nums}
.metric.ok{color:var(--ok)} .metric.mid{color:var(--mid);font-weight:600} .metric.bad{color:var(--bad);font-weight:600}
b.ok{color:var(--ok)} b.bad{color:var(--bad)} b.mid{color:var(--mid)} b.info{color:var(--info)}

.tag{display:inline-block;padding:2px 8px;border-radius:6px;font-size:12px;border:1px solid var(--linea);background:var(--fondo)}
.t-codigo{background:var(--info-b);color:var(--info);border-color:#cfe0f6}
.t-ajuste{background:var(--mid-b);color:var(--mid);border-color:#f0dcb4}
.t-contenido{background:var(--ok-b);color:var(--ok);border-color:#c6e6d5}
.t-manual{background:var(--na-b);color:var(--na);border-color:#dfe3e8}

.nota{color:var(--suave);font-size:13px;border-left:3px solid var(--linea);padding-left:12px;margin-top:14px}
.ok-box{background:var(--ok-b);color:var(--ok);padding:10px 14px;border-radius:8px;display:inline-block}
.hallazgos{margin:0;padding-left:18px}
.hallazgos li{margin-bottom:8px}
.hallazgos .ev{color:var(--suave);font-size:13px}
.leyenda,.leyenda-plan{margin:0;padding-left:18px;font-size:13.5px}
.leyenda li,.leyenda-plan li{margin-bottom:8px}
.reparto{margin-top:14px}

.filtros{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin:0 0 16px;font-size:13px;color:var(--suave)}
.filtros .f{font:inherit;cursor:pointer;background:var(--papel);border:1px solid var(--linea);
  border-radius:7px;padding:5px 11px;color:var(--tinta)}
.filtros .f:hover{background:var(--fondo)}
.filtros .f.on{background:var(--info);border-color:var(--info);color:#fff}

details.pagina{border:1px solid var(--linea);border-radius:10px;margin-bottom:12px;background:var(--papel)}
details.pagina>summary{cursor:pointer;padding:12px 16px;display:flex;align-items:center;gap:10px;flex-wrap:wrap;
  border-radius:10px;list-style:none}
details.pagina>summary::-webkit-details-marker{display:none}
details.pagina>summary::before{content:"▸";color:var(--suave);font-size:12px}
details.pagina[open]>summary::before{content:"▾"}
details.pagina[open]>summary{border-bottom:1px solid var(--linea);border-radius:10px 10px 0 0;background:var(--fondo)}
details.pagina>*:not(summary){margin-left:16px;margin-right:16px}
details.pagina>.scroll:last-child,details.pagina>p:last-child{margin-bottom:16px}
.pnum{color:var(--suave);font-variant-numeric:tabular-nums;font-size:13px}
.pill{background:var(--na-b);color:var(--suave);border-radius:999px;padding:2px 9px;font-size:12px}
.pill.bad{background:var(--bad-b);color:var(--bad)}
.pill.mid{background:var(--mid-b);color:var(--mid)}

footer{color:var(--suave);font-size:12.5px;padding-bottom:36px}

@media (max-width:720px){
  .wrap{padding:0 14px} main{padding:18px 14px 40px} section{padding:16px}
  h1{font-size:24px} .kpi.big b{font-size:28px} td.ev{max-width:none}
}
@media print{
  body{background:#fff} .toc,.filtros{display:none}
  section{break-inside:auto;border:none;padding:0;margin-bottom:18px}
  details.pagina{border:none} details.pagina>*:not(summary){margin-left:0;margin-right:0}
  details.pagina>summary{background:none;border:none;padding-left:0}
  thead th{position:static}
  h2{break-after:avoid} tr{break-inside:avoid}
  a{color:inherit;text-decoration:none}
  table.plan span.ev{display:block;overflow:visible;-webkit-line-clamp:none}
}`;

const page = (audit, body) => `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Auditoria web — ${esc(audit.siteName)}</title>
<meta name="robots" content="noindex">
<style>${CSS}</style>
</head>
<body>
${body}
<script>${SCRIPT}</script>
</body>
</html>`;

module.exports = render;
