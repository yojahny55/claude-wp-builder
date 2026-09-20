// @ts-check
// Como se ordena y como se reparte el plan de correccion del informe.
// Vive aparte de build-report.js para poder comprobarse sin generar informes.

// Solo los criterios numerados del checklist puntuan. Las filas 41.1-41.7
// (Core Web Vitals y audits de Lighthouse) y a11y-* son EVIDENCIA de los
// criterios 41 y 45: si contaran, el porcentaje dejaria de ser comparable con
// los informes historicos de 56 criterios.
const isScored = (c) => /^[0-9]+$/.test(String(c));

// Los criterios de indexabilidad encabezan el plan: si fallan, el resto del
// trabajo de SEO no rinde porque el contenido no llega a indexarse.
const INDEXABILITY = new Set(['51', '52', '53', '57']);
const SEV_ORDER = { Alta: 0, Media: 1, Baja: 2 };

function severity(r) {
  if (r.status !== 'fail') return 'Baja';
  if (INDEXABILITY.has(String(r.c))) return 'Alta';
  if (String(r.c) === 'a11y-1') return 'Alta';           // barreras criticas de accesibilidad
  if (['14', '39', '55', '56', '41.1'].includes(String(r.c))) return 'Alta';
  return 'Media';
}

// Como se aplica cada correccion. El informe se entrega SIEMPRE completo antes
// de tocar nada; esta columna es lo que permite despues separar lo que se puede
// automatizar de lo que exige a una persona. Distincion clave: un cambio en un
// archivo viaja con el commit, un ajuste de base de datos NO.
const APLICACION = {
  CODIGO: 'Codigo',       // archivo del tema: se aplica y se commitea
  AJUSTE: 'Ajuste',       // opcion de WP/plugin o config del servidor: NO viaja con el commit
  CONTENIDO: 'Contenido', // hay que escribir o decidir texto: lo hace una persona
  MANUAL: 'Manual',       // juicio humano o herramienta externa: no automatizable
};

// Criterios que dependen de una persona por naturaleza, no por falta de acceso.
const JUICIO_HUMANO = new Set(['2', '27', '30', '31', '32', '33', '36', '37']);
// Criterios que se arreglan escribiendo contenido, no configurando.
const CONTENIDO = new Set(['23', '46', '47', '48', '49', '19', '26']);
// Criterios que viven en una opcion (WordPress, plugin SEO) o en la
// configuracion del servidor. 55 y 56 son del hosting, no del tema: no se
// arreglan tocando el codigo del theme.
const AJUSTE = new Set(['51', '52', '53', '54', '55', '56', '57', '58']);

function aplicacion(r) {
  const c = String(r.c);
  if (JUICIO_HUMANO.has(c)) return APLICACION.MANUAL;
  if (AJUSTE.has(c)) return APLICACION.AJUSTE;
  if (CONTENIDO.has(c)) return APLICACION.CONTENIDO;
  // Rendimiento y accesibilidad se corrigen tocando el tema.
  if (c === '41' || c.startsWith('41.') || c.startsWith('a11y-')) return APLICACION.CODIGO;
  if (['5', '6', '7', '9', '39', '45'].includes(c)) return APLICACION.CODIGO;
  return APLICACION.CODIGO;
}

// Filas a corregir, ordenadas por severidad y, dentro de cada nivel, los fallos
// antes que los avisos.
function buildPlan(pages) {
  const todo = [];
  for (const [page, byCrit] of Object.entries(pages)) {
    for (const r of Object.values(byCrit)) {
      if (r.status === 'fail' || r.status === 'warn') {
        todo.push({ ...r, page, sev: severity(r), como: aplicacion(r) });
      }
    }
  }
  return ordenar(todo);
}

const ordenar = (todo) => todo.sort((a, b) => (SEV_ORDER[a.sev] - SEV_ORDER[b.sev])
  || (a.status === b.status ? 0 : a.status === 'fail' ? -1 : 1)
  || String(a.c).localeCompare(String(b.c), undefined, { numeric: true }));

// Filas que en el plan van agrupadas en UNA sola con las paginas afectadas, en
// vez de repetidas pagina por pagina:
//   - los criterios de sitio, que se evaluan una vez por definicion;
//   - las filas 41.4-41.7, que son el RESUMEN por categoria de Lighthouse. El
//     detalle de esa pagina ya esta en su tabla de incidencias, asi que
//     repetirlas por pagina solo alarga el plan sin decir nada nuevo.
// El criterio 41 en si NO se agrupa: sus puntuaciones son de cada pagina y es
// lo que se revisa pagina por pagina.
const esResumenLighthouse = (c) => /^41\.[4-7]$/.test(String(c));
const seAgrupa = (r) => esDeSitio(r.c, r.page) || esResumenLighthouse(r.c);

// Se queda el peor estado y su evidencia, que es la que define la correccion.
const RANK = { pass: 0, na: 0, manual: 1, warn: 2, fail: 3 };
function agruparFilasRepetidas(plan) {
  const grupos = new Map();
  const salida = [];
  for (const t of plan) {
    if (!seAgrupa(t)) { salida.push(t); continue; }
    const prev = grupos.get(String(t.c));
    if (!prev) {
      const fila = { ...t, paginas: [t.page] };
      grupos.set(String(t.c), fila);
      salida.push(fila);
      continue;
    }
    if (!prev.paginas.includes(t.page)) prev.paginas.push(t.page);
    if (RANK[t.status] > RANK[prev.status]) {
      Object.assign(prev, t, { paginas: prev.paginas });
    }
  }
  for (const fila of grupos.values()) {
    fila.page = fila.paginas.length > 1 ? `${fila.paginas.length} paginas` : fila.paginas[0];
  }
  return ordenar(salida);
}

// Criterios que se evaluan UNA vez comparando entre paginas o a nivel global.
// El informe los agrupa aparte (seccion de criterios de sitio de la plantilla)
// en vez de repetirlos en cada pagina. Lista tomada de report-template.md.
//
// El 41 NO esta aqui a proposito: Lighthouse se ejecuta en cada pagina y da una
// puntuacion distinta en cada una, asi que la fila del criterio y sus filas de
// evidencia (41.1-41.7) van en la tabla de SU pagina. Un 41 unico a nivel de
// sitio escondia justo lo que hay que revisar pagina por pagina.
const SITIO = new Set(['29', '32', '34', '36', '38', '40', '51', '52', '55', '56']);
const esDeSitio = (c, page) => String(page).startsWith('_') || SITIO.has(String(c));

module.exports = {
  isScored, severity, aplicacion, buildPlan, agruparFilasRepetidas, esDeSitio,
  esResumenLighthouse, APLICACION, SEV_ORDER, SITIO,
};
