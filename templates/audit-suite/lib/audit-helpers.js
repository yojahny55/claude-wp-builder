// @ts-check
// Comprobaciones reutilizables de la auditoria. Cada funcion devuelve uno o varios
// resultados con forma { c, name, status, evidence, rec } donde:
//   status: 'pass' (OK) | 'fail' (NO) | 'warn' (parcial/aviso) | 'manual' (revisar) | 'na'
// El generador mapea: pass->OK, fail->NO, warn->ADVERTENCIA, manual->REVISION, na->N/A
// axe se carga dentro de runAxe, no aqui: asi este modulo se puede requerir
// (y auto-comprobar) sin tener las dependencias instaladas ni abrir navegador.
const R = (c, name, status, evidence = '', rec = '') => ({ c, name, status, evidence, rec });

// --- SEO / metadatos -------------------------------------------------------
async function checkTitle(page, th) {
  const title = await page.title();
  const len = title.length;
  // Google trunca el titulo por ancho en pixeles (~580px, del orden de 60
  // caracteres), no por el rango de la casa: 64-70 cumple pero se ve cortado.
  const cut = th.titleSerpCut ?? 60;
  if (len < th.titleMin || len > th.titleMax) {
    return R('46', `Titulo ${th.titleMin}-${th.titleMax} caracteres`, 'warn', `"${title}" (${len} car.)`,
      `Ajustar a ${th.titleMin}-${th.titleMax} caracteres con terminos objetivo`);
  }
  if (len > cut) {
    return R('46', `Titulo ${th.titleMin}-${th.titleMax} caracteres`, 'warn',
      `"${title}" (${len} car.: cumple el rango, pero Google lo recorta hacia los ${cut})`,
      `Poner los terminos objetivo en los primeros ${cut} caracteres y dejar la marca al final`);
  }
  return R('46', `Titulo ${th.titleMin}-${th.titleMax} caracteres`, 'pass', `"${title}" (${len} car.)`);
}

async function checkMetaDescription(page, th) {
  const desc = await page.locator('meta[name="description"]').getAttribute('content').catch(() => null);
  if (!desc) return R('49', 'Meta description unica ~160', 'fail', 'Sin meta description', 'Anadir meta description de ~150-160 car.');
  const len = desc.length;
  const status = (len >= th.metaDescMin && len <= th.metaDescMax) ? 'pass' : 'warn';
  return R('49', 'Meta description unica ~160', status, `${len} caracteres`,
    status === 'pass' ? '' : `Ajustar hacia ${th.metaDescMin}-${th.metaDescMax} caracteres`);
}

async function checkMetadata(page) {
  // ponytail: meta keywords NO puntua — Google la ignora desde 2009. Solo se
  // reporta como dato; penalizar su ausencia seria mala recomendacion de SEO.
  const kw = await page.locator('meta[name="keywords"]').count();
  const title = (await page.title()).trim();
  const desc = await page.locator('meta[name="description"]').count();
  const missing = [!title ? 'title' : null, desc === 0 ? 'description' : null].filter(Boolean).join(', ');
  const nota = kw > 0 ? ' (hay meta keywords: no puntua, Google la ignora)' : '';
  return R('23', 'Metadatos: titulo y description', missing ? 'warn' : 'pass',
    (missing ? `Falta: ${missing}` : 'title + description presentes') + nota,
    missing ? `Anadir <meta name="${missing}"> o un <title> con contenido` : '');
}

// --- Estructura / accesibilidad basica ------------------------------------
async function checkHeadings(page) {
  const levels = await page.$$eval('h1,h2,h3,h4,h5,h6', els => els.map(e => Number(e.tagName[1])));
  const h1 = levels.filter(l => l === 1).length;
  const problems = [];
  if (h1 !== 1) problems.push(`${h1} elementos <h1> (debe haber 1)`);
  let prev = 0;
  for (const l of levels) { if (prev && l > prev + 1) problems.push(`salto de H${prev} a H${l}`); prev = l; }
  const status = problems.length ? 'fail' : 'pass';
  return R('47', 'Encabezados H1/H2/H3', status,
    problems.length ? problems.join('; ') : `Jerarquia correcta (${levels.length} encabezados)`,
    problems.length ? 'Un solo H1 y sin saltar niveles' : '');
}

async function checkLang(page) {
  const lang = await page.locator('html').getAttribute('lang');
  const status = lang && lang.trim().length >= 2 ? 'pass' : 'fail';
  return R('44', 'Atributo lang', status, `lang="${lang || ''}"`,
    status === 'pass' ? '' : 'Definir <html lang="..."> con el idioma correcto');
}

async function checkImagesAlt(page) {
  const total = await page.locator('img').count();
  const missing = await page.locator('img:not([alt])').count();
  // alt="" es valido para decorativas; solo contamos las que NO tienen atributo alt
  const status = missing === 0 ? 'pass' : (missing <= total * 0.25 ? 'warn' : 'fail');
  return R('48', 'Alt descriptivo de imagenes', status,
    `${missing}/${total} imagenes sin atributo alt`,
    missing ? 'Anadir alt a imagenes informativas (alt="" solo en decorativas)' : '');
}

async function checkImageLinksAlt(page) {
  const links = await page.locator('a:has(img)').count();
  if (links === 0) return R('19', 'Alt en imagenes-enlace', 'na', 'No hay imagenes usadas como enlace');
  const bad = await page.$$eval('a img', imgs =>
    imgs.filter(i => {
      const a = i.closest('a');
      const alt = (i.getAttribute('alt') || '').trim();
      const aria = (a && (a.getAttribute('aria-label') || a.textContent || '').trim()) || '';
      return !alt && !aria;
    }).length);
  const status = bad === 0 ? 'pass' : 'warn';
  return R('19', 'Alt en imagenes-enlace', status,
    `${bad} enlaces-imagen sin alt ni texto`,
    bad ? 'Dar alt descriptivo del destino o aria-label al enlace' : '');
}

// --- Enlaces ---------------------------------------------------------------
// Redes sociales (y similares) bloquean peticiones sin navegador real -
// cookies, JS challenge, fingerprint - y devuelven 400/403/429 aunque el
// enlace funcione perfecto para una persona real haciendo click. Verificarlas
// con request.get() da falsos positivos sistematicos: se listan aparte como
// "sin verificar" en vez de "rotas".
const UNVERIFIABLE_HOSTS = /(^|\.)(facebook\.com|instagram\.com|linkedin\.com|twitter\.com|x\.com|tiktok\.com|wa\.me|api\.whatsapp\.com)$/i;

async function checkBrokenLinks(page, request, baseURL) {
  const hrefs = await page.$$eval('a[href]', as => Array.from(new Set(as
    .map(a => a.getAttribute('href'))
    .filter(h => h && !h.startsWith('#') && !h.startsWith('mailto:') && !h.startsWith('tel:') && !h.startsWith('javascript:')))));
  const host = new URL(baseURL).host;
  const results = { internalBroken: [], externalBroken: [], external: 0, unverifiable: [] };
  for (const href of hrefs) {
    let url; try { url = new URL(href, baseURL); } catch { continue; }
    const isInternal = url.host === host;
    if (!isInternal) results.external++;
    if (!isInternal && UNVERIFIABLE_HOSTS.test(url.host)) {
      results.unverifiable.push(url.host);
      continue;
    }
    try {
      const res = await request.get(url.toString(), { timeout: 15000, maxRedirects: 5 });
      if (res.status() >= 400) (isInternal ? results.internalBroken : results.externalBroken).push(`${url.pathname} (${res.status()})`);
    } catch (e) {
      (isInternal ? results.internalBroken : results.externalBroken).push(`${url.pathname} (sin respuesta)`);
    }
  }
  const out = [];
  out.push(R('14', 'Enlaces internos sin rotos',
    results.internalBroken.length ? 'fail' : 'pass',
    results.internalBroken.length ? results.internalBroken.join(', ') : 'Todos resuelven',
    results.internalBroken.length ? 'Corregir/eliminar los enlaces rotos' : ''));
  const uv = results.unverifiable.length ? ` (${results.unverifiable.length} sin verificar: ${[...new Set(results.unverifiable)].join(', ')} bloquean peticiones automatizadas, revisar a mano)` : '';
  out.push(results.external === 0
    ? R('15', 'Enlaces externos sin rotos', 'na', 'No se detectan enlaces externos')
    : R('15', 'Enlaces externos sin rotos', results.externalBroken.length ? 'fail' : 'pass',
        (results.externalBroken.length ? results.externalBroken.join(', ') : `${results.external} externos OK`) + uv,
        results.externalBroken.length ? 'Actualizar los enlaces externos caidos' : ''));
  out.push(results.external === 0
    ? R('28', 'Distincion interno/externo', 'na', 'Sin enlaces externos')
    : R('28', 'Distincion interno/externo', 'manual', `${results.external} externos: revisar senalizacion (icono/target)`));
  return out;
}

// --- Navegacion / estructura del sitio ------------------------------------
async function checkHomeShortcut(page, sel) {
  const n = await page.locator(sel.logoLink).count().catch(() => 0);
  const status = n > 0 ? 'pass' : 'fail';
  return R('21', 'Acceso a home en todas las paginas', status,
    status === 'pass' ? 'Logo/enlace a la home presente' : 'No se encontro enlace a la home',
    status === 'pass' ? '' : 'Enlazar el logo a la home');
}

async function checkSearch(page, sel) {
  const n = await page.locator(sel.search).count().catch(() => 0);
  return n > 0
    ? R('20', 'Funcion de busqueda visible', 'pass', 'Buscador presente')
    : R('20', 'Funcion de busqueda visible', 'manual',
        'Sin buscador. Si es sitio pequeno tipo marketing, marcar N/A; si no, es NO',
        'Valorar anadir un buscador');
}

async function checkPrivacyLink(page, sel) {
  const n = await page.locator(sel.privacyLink).count().catch(() => 0);
  const status = n > 0 ? 'pass' : 'fail';
  return R('38', 'Politica de privacidad enlazada', status,
    status === 'pass' ? 'Enlace a politica presente' : 'No se encontro enlace a politica de privacidad',
    status === 'pass' ? '' : 'Publicar y enlazar la politica (footer + junto a formularios)');
}

async function checkActiveNav(page, sel) {
  const n = await page.locator(sel.navActive).count().catch(() => 0);
  const status = n > 0 ? 'pass' : 'warn';
  return R('8', 'Menu/enlace seleccionado resaltado', status,
    status === 'pass' ? 'Elemento de menu activo detectado' : 'Sin indicador de elemento activo',
    status === 'pass' ? '' : 'Resaltar el item del menu de la pagina actual');
}

async function checkButtonText(page) {
  const generic = ['ok', 'aceptar', 'click here', 'clic aqui', 'submit', 'enviar', 'boton'];
  const labels = await page.$$eval('button, a.button, .btn, [role="button"], input[type="submit"]',
    els => els.map(e => (e.value || e.textContent || '').trim()).filter(Boolean));
  const bad = labels.filter(l => generic.includes(l.toLowerCase()));
  const status = bad.length === 0 ? 'pass' : 'warn';
  return R('26', 'Texto adecuado en botones', status,
    bad.length ? `Genericos: ${[...new Set(bad)].join(', ')}` : `${labels.length} botones con texto descriptivo`,
    bad.length ? 'Usar textos que describan la accion' : '');
}

// --- Interaccion visual ----------------------------------------------------
async function checkHover(page, sel) {
  // :visible descarta elementos ocultos (menus off-canvas, buscador colapsado,
  // etc.) que matchean el selector pero nunca son interactuables: sin esto,
  // .first() puede quedarse con el primero en el DOM aunque este oculto y
  // el .hover() posterior cuelga 90s esperando a que se vuelva visible/estable.
  const el = page.locator(`${sel.actionElements}:visible`).first();
  if (await el.count() === 0) return R('5', 'Cambio visible al hover', 'manual', 'Sin elementos de accion visibles para medir');
  const before = await el.evaluate(e => { const s = getComputedStyle(e); return [s.color, s.backgroundColor, s.textDecorationLine, s.cursor].join('|'); });
  await el.hover();
  await page.waitForTimeout(150);
  const after = await el.evaluate(e => { const s = getComputedStyle(e); return [s.color, s.backgroundColor, s.textDecorationLine, s.cursor].join('|'); });
  const cursor = after.split('|')[3];
  const changed = before !== after;
  const status = (changed && cursor === 'pointer') ? 'pass' : (cursor === 'pointer' ? 'warn' : 'fail');
  return R('5', 'Cambio visible al hover', status,
    `cursor=${cursor}; ${changed ? 'estilo cambia' : 'sin cambio de estilo'}`,
    status === 'pass' ? '' : 'Anadir estado :hover visible y cursor:pointer');
}

async function checkActionSpacing(page, sel, th) {
  const boxes = await page.$$eval(sel.actionElements, els => els
    .map(e => e.getBoundingClientRect())
    .filter(r => r.width > 0 && r.height > 0)
    .map(r => ({ x: r.x, y: r.y, w: r.width, h: r.height })));
  let tooClose = 0;
  for (let i = 0; i < boxes.length; i++) for (let j = i + 1; j < boxes.length; j++) {
    const a = boxes[i], b = boxes[j];
    const overlapY = a.y < b.y + b.h && b.y < a.y + a.h;
    if (!overlapY) continue;
    const gap = Math.max(b.x - (a.x + a.w), a.x - (b.x + b.w));
    if (gap >= 0 && gap < th.actionGapPx) tooClose++;
  }
  const status = tooClose === 0 ? 'pass' : 'warn';
  return R('9', 'Espacio entre elementos de accion', status,
    tooClose ? `${tooClose} pares de acciones a < ${th.actionGapPx}px` : 'Separacion suficiente',
    tooClose ? 'Aumentar margen entre botones/enlaces de accion' : '');
}

// Clasifica los anchos medidos en cada pantalla y dice EN CUAL se desborda:
// un texto puede caber en movil y pasarse en escritorio, o al reves si el tema
// no reduce la tipografia. `medidas` = [{ vp, widths }], donde widths son los
// caracteres de la linea mas larga de cada bloque en ese viewport.
// Pura a proposito: se comprueba en audit-helpers.selfcheck.js sin navegador.
function lineVerdict(medidas, th) {
  const name = `Maximo ${th.lineMaxChars} caracteres por linea`;
  const conTexto = medidas.filter(m => m.widths.length);
  if (!conTexto.length) return R('6', name, 'manual', 'Sin bloques de texto medibles');

  const resumen = conTexto.map(m => ({
    vp: m.vp,
    bloques: m.widths.length,
    peor: Math.max(...m.widths),
    fail: m.widths.filter(w => w > th.lineMaxChars).length,
    warn: m.widths.filter(w => w > th.lineWarnChars && w <= th.lineMaxChars).length,
  }));
  const porPantalla = resumen.map(r => `${r.vp} ${r.peor}`).join(', ');
  const rec = 'Limitar el ancho con max-width en ch (p. ej. 65ch, el optimo de lectura es 45-75)';
  const lista = (rs, campo) => rs.map(r => `${r.vp} (${r[campo]}/${r.bloques} bloques, el mayor ${r.peor} car.)`).join('; ');

  const malas = resumen.filter(r => r.fail);
  if (malas.length) {
    return R('6', name, 'fail',
      `Se pasa de ${th.lineMaxChars} car. en: ${lista(malas, 'fail')}. Linea mas larga por pantalla: ${porPantalla}`, rec);
  }
  const avisos = resumen.filter(r => r.warn);
  if (avisos.length) {
    return R('6', name, 'warn',
      `Entre ${th.lineWarnChars + 1} y ${th.lineMaxChars} car. en: ${lista(avisos, 'warn')}. Linea mas larga por pantalla: ${porPantalla}`, rec);
  }
  return R('6', name, 'pass',
    `Linea mas larga por pantalla: ${porPantalla} (limite de aviso: ${th.lineWarnChars})`);
}

// Mide en cada viewport y devuelve [{ vp, widths }]. Cambia el tamano de
// ventana pero lo deja como estaba al terminar: esta comprobacion corre a
// mitad del spec y las siguientes esperan el viewport original.
// ponytail: se reajusta el viewport sin recargar (basta el reflow del CSS).
// Si un tema calcula la maquetacion solo en el load, recarga aqui.
async function checkLineLength(page, sel, th, viewports) {
  const original = page.viewportSize();
  const pantallas = (viewports && viewports.length) ? viewports : [{ name: 'actual', width: original?.width, height: original?.height }];
  const medidas = [];
  for (const vp of pantallas) {
    if (vp.width && vp.height) await page.setViewportSize({ width: vp.width, height: vp.height });
    medidas.push({ vp: vp.name, widths: await medirLineas(page, sel) });
  }
  if (original) await page.setViewportSize(original);
  return lineVerdict(medidas, th);
}

async function medirLineas(page, sel) {
  // Se cuentan los caracteres REALES de cada linea renderizada con la Range
  // API: un Range por caracter da su rectangulo, y los que comparten borde
  // superior estan en la misma linea. Antes se estimaba con
  // clientWidth / (fontSize * 0.5), que se desviaba con cualquier fuente
  // estrecha o ancha y medía el contenedor, no el texto.
  return page.$$eval(sel.textBlocks, (els) => {
    const MAX_CHARS = 3000;   // tope por bloque: la linea mas larga aparece mucho antes
    const out = [];
    for (const el of els) {
      const porLinea = new Map();   // borde superior redondeado -> caracteres
      const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
      const range = document.createRange();
      let vistos = 0;
      let node;
      while ((node = walker.nextNode()) && vistos < MAX_CHARS) {
        const text = node.nodeValue || '';
        if (!text.trim()) continue;
        for (let i = 0; i < text.length && vistos < MAX_CHARS; i++) {
          if (text[i] === '\n' || text[i] === '\t') continue;
          range.setStart(node, i);
          range.setEnd(node, i + 1);
          const rect = range.getClientRects()[0];
          if (!rect || rect.width === 0) continue;   // fuera de pantalla u oculto
          // Se agrupa por linea, no por nodo: asi un <strong> a mitad de
          // parrafo no parte la linea en dos mediciones cortas.
          const linea = Math.round(rect.top);
          porLinea.set(linea, (porLinea.get(linea) || 0) + 1);
          vistos++;
        }
      }
      const mayor = Math.max(0, ...porLinea.values());
      if (mayor) out.push(mayor);
    }
    return out;
  });
}

// --- Formularios -----------------------------------------------------------
async function checkFirstFieldFocus(page, form) {
  const first = form.fields[0];
  const active = await page.evaluate(() => document.activeElement && document.activeElement.tagName);
  const matches = await page.locator(first.selector).first().evaluate(
    (el) => el === document.activeElement).catch(() => false);
  const status = matches ? 'pass' : 'warn';
  return R('10', 'Foco en el primer campo', status,
    matches ? 'El primer campo recibe el foco al cargar' : `activeElement=${active}`,
    matches ? '' : 'Poner autofocus/foco en el primer campo del formulario');
}

async function checkFormValidation(page, form) {
  // Enviar vacio/invalido y comprobar que no navega y muestra error
  const urlBefore = page.url();
  const submit = page.locator(form.submit).first();
  if (await submit.count() === 0) return [R('16', 'Validacion antes de enviar', 'manual', 'No se encontro boton de envio')];
  // Rellenar email con valor invalido si existe
  const emailField = form.fields.find(f => f.kind === 'email');
  if (emailField) await page.locator(emailField.selector).first().fill('correo-invalido').catch(() => {});
  await submit.click().catch(() => {});
  await page.waitForTimeout(500);
  const stayed = page.url() === urlBefore;
  const invalidCount = await page.locator(':invalid, [aria-invalid="true"], .error, .wpcf7-not-valid').count().catch(() => 0);
  const out = [];
  out.push(R('16', 'Validacion antes de enviar', stayed ? 'pass' : 'fail',
    stayed ? 'El envio invalido no procede' : 'El formulario se envio con datos invalidos',
    stayed ? '' : 'Validar en cliente/servidor antes de enviar'));
  out.push(R('13', 'Resaltar campos invalidos', invalidCount > 0 ? 'pass' : 'warn',
    `${invalidCount} campos marcados como invalidos`,
    invalidCount ? '' : 'Resaltar el campo con error y explicar como corregirlo'));
  // Foco al primer campo con error (pauta 35)
  const focusOnError = await page.evaluate(() => {
    const a = document.activeElement;
    return a && (a.matches(':invalid') || a.getAttribute('aria-invalid') === 'true');
  }).catch(() => false);
  out.push(R('35', 'Foco en el campo con error', focusOnError ? 'pass' : 'warn',
    focusOnError ? 'El foco va al campo con error' : 'El foco no se situa en el error',
    focusOnError ? '' : 'Mover el foco al primer campo invalido tras validar'));
  return out;
}

async function checkRequiredMarks(page, form) {
  const required = form.fields.filter(f => f.required).length;
  const marks = await page.locator('label:has-text("*"), .required, [aria-required="true"], [required]').count().catch(() => 0);
  const status = marks > 0 ? 'pass' : 'warn';
  return R('1', 'Distincion obligatorio/opcional', status,
    `${required} campos obligatorios; ${marks} marcas detectadas`,
    status === 'pass' ? 'Anadir tambien leyenda "* obligatorio"' : 'Marcar visualmente los campos obligatorios');
}

// --- Responsividad ---------------------------------------------------------
async function checkResponsive(page, viewports, url) {
  const issues = [];
  for (const vp of viewports) {
    await page.setViewportSize({ width: vp.width, height: vp.height });
    await page.goto(url, { waitUntil: 'networkidle' }).catch(() => {});
    const overflow = await page.evaluate(() =>
      document.documentElement.scrollWidth > document.documentElement.clientWidth + 2);
    if (overflow) issues.push(vp.name);
  }
  const status = issues.length === 0 ? 'pass' : 'fail';
  return R('39', 'Responsividad', status,
    issues.length ? `Desborde horizontal en: ${issues.join(', ')}` : 'Sin desbordes en los viewports probados',
    issues.length ? 'Corregir el desborde horizontal en esos anchos' : '');
}

// --- 404 -------------------------------------------------------------------
async function checkNotFound(page, baseURL, notFoundPath, sel) {
  const res = await page.goto(new URL(notFoundPath, baseURL).toString(), { waitUntil: 'domcontentloaded' }).catch(() => null);
  const status404 = res ? res.status() : 0;
  const hasLogo = await page.locator(sel.logo).count().catch(() => 0);
  const hasNav = await page.locator(sel.nav).count().catch(() => 0);
  const bodyLen = (await page.locator('body').innerText().catch(() => '')).length;
  const custom = hasLogo > 0 && hasNav > 0 && bodyLen > 150;
  const status = (status404 === 404 && custom) ? 'pass' : (custom ? 'warn' : 'fail');
  return R('50', '404 personalizada', status,
    `HTTP ${status404}; ${custom ? 'con identidad y navegacion' : 'generica o vacia'}`,
    status === 'pass' ? '' : 'Crear 404 con identidad, mensaje util y navegacion (y status 404)');
}

// --- axe-core (accesibilidad + contraste, pautas 45, 44, 47, 48, 19) -------
async function runAxe(page) {
  const { AxeBuilder } = require('@axe-core/playwright');
  const results = await new AxeBuilder({ page }).analyze();
  const byId = {};
  for (const v of results.violations) byId[v.id] = v.nodes.length;
  const contrast = byId['color-contrast'] || 0;
  const out = [];
  out.push(R('45', 'Contraste >= 4.5:1', contrast === 0 ? 'pass' : 'fail',
    contrast === 0 ? 'Sin violaciones de contraste (axe)' : `${contrast} elementos con contraste insuficiente`,
    contrast === 0 ? '' : 'Ajustar colores para alcanzar 4.5:1'));
  // El resto de violaciones se agrupa por impacto: 'critical'/'serious' son
  // barreras reales de uso (fail); 'moderate'/'minor', mejoras (warn). Antes
  // iba todo mezclado en una sola fila y se perdia la prioridad.
  const other = results.violations.filter(v => v.id !== 'color-contrast');
  const byImpact = { critical: [], serious: [], moderate: [], minor: [] };
  for (const v of other) (byImpact[v.impact] || byImpact.minor).push(`${v.id} (${v.nodes.length})`);
  const blocking = [...byImpact.critical, ...byImpact.serious];
  const minorOnes = [...byImpact.moderate, ...byImpact.minor];
  if (blocking.length) out.push(R('a11y-1', 'axe-core: barreras criticas/serias', 'fail',
    blocking.join(', '), 'Corregir primero: impiden usar la pagina con lector de pantalla o teclado'));
  if (minorOnes.length) out.push(R('a11y-2', 'axe-core: incidencias moderadas/menores', 'warn',
    minorOnes.join(', '), 'Revisar tras las criticas'));
  return out;
}

module.exports = {
  R,
  checkTitle, checkMetaDescription, checkMetadata,
  checkHeadings, checkLang, checkImagesAlt, checkImageLinksAlt,
  checkBrokenLinks,
  checkHomeShortcut, checkSearch, checkPrivacyLink, checkActiveNav, checkButtonText,
  checkHover, checkActionSpacing, checkLineLength, lineVerdict,
  checkFirstFieldFocus, checkFormValidation, checkRequiredMarks,
  checkResponsive, checkNotFound, runAxe,
};
