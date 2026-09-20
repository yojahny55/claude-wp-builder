// @ts-check
// Comprobaciones de SEO tecnico e indexabilidad (categoria G2, criterios 51-58).
// Todo funciona sobre HTTP publico con el fixture `request` de Playwright: no
// necesita navegador ni SSH/WP-CLI en el servidor. Mismo formato de resultado
// que lib/audit-helpers.js: { c, name, status, evidence, rec }.
// Mismo shape que audit-helpers.R, redefinido aqui a proposito: este modulo
// es HTTP puro y no debe arrastrar @axe-core/playwright ni un navegador.
const R = (c, name, status, evidence = '', rec = '') => ({ c, name, status, evidence, rec });

const SITEMAP_CANDIDATES = ['/sitemap_index.xml', '/sitemap.xml', '/wp-sitemap.xml', '/sitemap-index.xml'];
// idioma ISO 639-1/2 + script opcional (4 letras) + region ISO 3166-1 alpha-2
// (2 letras) o UN M.49 (3 digitos). "en-UK" NO es valido: el codigo del Reino
// Unido es GB, y Google descarta el par entero cuando el codigo esta mal.
const HREFLANG_CODE = /^([a-z]{2,3}(-[A-Za-z]{4})?(-([A-Za-z]{2}|[0-9]{3}))?|x-default)$/;
const WRONG_REGION = { uk: 'gb', el: 'gr', eu: null, asia: null, latam: null };

const get = (request, url, opts = {}) =>
  request.get(url, { timeout: 20000, failOnStatusCode: false, ...opts }).catch(() => null);

// --- 51. robots.txt --------------------------------------------------------
async function checkRobots(request, baseURL, scopePaths) {
  const url = new URL('/robots.txt', baseURL).toString();
  const res = await get(request, url);
  if (!res || res.status() !== 200) {
    return { result: R('51', 'robots.txt sin bloqueos criticos', 'fail',
      `GET /robots.txt -> ${res ? res.status() : 'sin respuesta'}`,
      'Publicar /robots.txt con las reglas del sitio y la linea Sitemap:'), body: '' };
  }
  const body = await res.text();

  // Solo interesan las reglas que afectan a los crawlers de busqueda: el
  // grupo `User-agent: *` y los de Google. Un Disallow dirigido a un bot
  // concreto (p. ej. un scraper de IA) no es un fallo de indexabilidad.
  const relevant = [];
  let applies = false;
  for (const raw of body.split(/\r?\n/)) {
    const line = raw.replace(/#.*/, '').trim();
    if (!line) continue;
    const [k, ...rest] = line.split(':');
    const key = k.trim().toLowerCase();
    const val = rest.join(':').trim();
    if (key === 'user-agent') applies = val === '*' || /googlebot/i.test(val);
    else if (key === 'disallow' && applies && val) relevant.push(val);
  }

  const problems = [];
  if (relevant.includes('/')) problems.push('Disallow: / bloquea el sitio ENTERO');
  // Bloquear CSS/JS impide a Google renderizar la pagina como la ve el usuario.
  const blocksAssets = relevant.filter(d => /\.(css|js)|wp-content|wp-includes|\/themes?\/|\/assets?\//i.test(d));
  if (blocksAssets.length) problems.push(`bloquea recursos de render: ${blocksAssets.join(', ')}`);
  // Contraste contra las paginas del alcance: lo mas grave y lo mas concreto.
  const blockedScope = (scopePaths || []).filter(p => relevant.some(d => d !== '/' && p.startsWith(d)));
  if (blockedScope.length) problems.push(`bloquea paginas del alcance: ${blockedScope.join(', ')}`);
  const hasSitemap = /^\s*sitemap\s*:/im.test(body);
  if (!hasSitemap) problems.push('no declara Sitemap:');

  const critical = relevant.includes('/') || blockedScope.length > 0 || blocksAssets.length > 0;
  const status = problems.length ? (critical ? 'fail' : 'warn') : 'pass';
  return {
    result: R('51', 'robots.txt sin bloqueos criticos', status,
      problems.length ? problems.join('; ') : `${relevant.length} reglas Disallow, ninguna critica; declara Sitemap`,
      problems.length ? 'Revisar las reglas Disallow y declarar el sitemap' : ''),
    body,
  };
}

// --- 52. sitemap.xml -------------------------------------------------------
function extractLocs(xml) {
  return [...xml.matchAll(/<loc>\s*([^<\s]+)\s*<\/loc>/gi)].map(m => m[1]);
}

async function checkSitemap(request, baseURL, scopePaths, robotsBody, sampleSize = 5) {
  // La linea Sitemap: de robots.txt manda sobre las rutas por convencion.
  const declared = [...(robotsBody || '').matchAll(/^\s*sitemap\s*:\s*(\S+)/gim)].map(m => m[1]);
  const candidates = [...declared, ...SITEMAP_CANDIDATES.map(p => new URL(p, baseURL).toString())];

  let found = null, xml = '';
  for (const c of candidates) {
    const res = await get(request, c);
    if (!res || res.status() !== 200) continue;
    const t = await res.text().catch(() => '');
    if (/<(urlset|sitemapindex)/i.test(t)) { found = c; xml = t; break; }
  }
  if (!found) {
    return R('52', 'sitemap.xml accesible y coherente', 'fail',
      `Ningun sitemap en: ${candidates.slice(0, 4).join(', ')}`,
      'Publicar un sitemap XML y declararlo en robots.txt');
  }

  // Si es un indice, bajar un nivel para conseguir URLs reales.
  let urls = extractLocs(xml);
  if (/<sitemapindex/i.test(xml)) {
    const children = urls.slice(0, 3);
    urls = [];
    for (const child of children) {
      const res = await get(request, child);
      if (res && res.status() === 200) urls.push(...extractLocs(await res.text().catch(() => '')));
    }
  }
  if (!urls.length) {
    return R('52', 'sitemap.xml accesible y coherente', 'fail', `${found} no contiene URLs`,
      'Regenerar el sitemap: esta vacio');
  }

  const problems = [];
  // Muestreo: cada URL del sitemap debe devolver 200 directo, sin redirect ni 404.
  const sample = urls.slice(0, sampleSize);
  const bad = [];
  for (const u of sample) {
    const res = await get(request, u, { maxRedirects: 0 });
    const st = res ? res.status() : 0;
    if (st !== 200) bad.push(`${new URL(u).pathname} (${st || 'sin respuesta'})`);
  }
  if (bad.length) problems.push(`URLs que no responden 200: ${bad.join(', ')}`);

  const missing = (scopePaths || []).filter(p =>
    !urls.some(u => { try { return new URL(u).pathname.replace(/\/$/, '') === p.replace(/\/$/, ''); } catch { return false; } }));
  if (missing.length) problems.push(`paginas del alcance ausentes: ${missing.join(', ')}`);
  if (!/^\s*sitemap\s*:/im.test(robotsBody || '')) problems.push('no esta declarado en robots.txt');

  const status = problems.length ? (bad.length ? 'fail' : 'warn') : 'pass';
  return R('52', 'sitemap.xml accesible y coherente', status,
    `${found} — ${urls.length} URLs` + (problems.length ? `; ${problems.join('; ')}` : `; muestra de ${sample.length} OK`),
    problems.length ? 'Corregir las URLs del sitemap y declararlo en robots.txt' : '');
}

// --- Extraccion del <head> (comun a 53, 54, 57, 58) ------------------------
function headOf(html) {
  const m = html.match(/<head[\s\S]*?<\/head>/i);
  return m ? m[0] : html.slice(0, 200000);
}

function attrsOf(tag) {
  const out = {};
  for (const m of tag.matchAll(/([a-zA-Z-]+)\s*=\s*("([^"]*)"|'([^']*)')/g)) {
    out[m[1].toLowerCase()] = m[3] !== undefined ? m[3] : m[4];
  }
  return out;
}

function linkTags(html, rel) {
  return [...headOf(html).matchAll(/<link\b[^>]*>/gi)]
    .map(m => attrsOf(m[0]))
    .filter(a => (a.rel || '').toLowerCase().split(/\s+/).includes(rel));
}

// --- 53. canonical ---------------------------------------------------------
function checkCanonical(html, finalUrl) {
  const tags = linkTags(html, 'canonical');
  if (!tags.length) {
    return R('53', 'Canonical presente y coherente', 'fail', 'Sin <link rel="canonical">',
      'Anadir canonical absoluto autorreferente en cada pagina');
  }
  if (tags.length > 1) {
    return R('53', 'Canonical presente y coherente', 'fail',
      `${tags.length} canonicals: ${tags.map(t => t.href).join(', ')}`,
      'Dejar un solo canonical (suele ser tema + plugin SEO generando ambos)');
  }
  const href = (tags[0].href || '').trim();
  if (!href) return R('53', 'Canonical presente y coherente', 'fail', 'canonical vacio', 'Rellenar el href del canonical');
  if (!/^https?:\/\//i.test(href)) {
    return R('53', 'Canonical presente y coherente', 'warn', `canonical relativo: "${href}"`,
      'Usar URL absoluta en el canonical');
  }
  const norm = (u) => { try { const x = new URL(u); return (x.origin + x.pathname).replace(/\/$/, '').toLowerCase(); } catch { return u; } };
  const self = norm(href) === norm(finalUrl);
  return R('53', 'Canonical presente y coherente', self ? 'pass' : 'fail',
    `canonical="${href}"` + (self ? ' (autorreferente)' : ` pero la URL real es ${finalUrl}`),
    self ? '' : 'El canonical debe apuntar a la propia URL salvo consolidacion deliberada');
}

// --- 54. datos estructurados ----------------------------------------------
// El fallo tipico en WooCommerce es doble bloque Product (tema + plugin SEO):
// por eso lo que decide es el CONTEO por @type, no la mera presencia.
function checkStructuredData(html) {
  const blocks = [...html.matchAll(/<script\b[^>]*type\s*=\s*["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi)]
    .map(m => m[1]);
  if (!blocks.length) {
    return R('54', 'Datos estructurados sin duplicar', 'warn', 'Sin bloques application/ld+json',
      'Anadir el schema que corresponda al tipo de pagina (Article, Product, Organization, BreadcrumbList)');
  }
  const types = [];
  let invalid = 0;
  for (const b of blocks) {
    let data;
    try { data = JSON.parse(b.trim()); } catch { invalid++; continue; }
    // Aplanar @graph y arrays: RankMath emite todo dentro de un solo @graph.
    const nodes = [];
    const walk = (n) => {
      if (Array.isArray(n)) return n.forEach(walk);
      if (!n || typeof n !== 'object') return;
      if (n['@graph']) return walk(n['@graph']);
      if (n['@type']) nodes.push(n);
    };
    walk(data);
    for (const n of nodes) for (const t of [].concat(n['@type'])) types.push(String(t));
  }
  const counts = types.reduce((a, t) => (a[t] = (a[t] || 0) + 1, a), {});
  // WebPage/BreadcrumbList/ListItem se repiten legitimamente; las entidades no.
  const SINGLETON = /^(Product|Article|BlogPosting|NewsArticle|Organization|LocalBusiness|WebSite|FAQPage|Recipe|Event)$/;
  const dupes = Object.entries(counts).filter(([t, n]) => n > 1 && SINGLETON.test(t));
  const problems = [];
  if (invalid) problems.push(`${invalid} bloque(s) con JSON invalido`);
  if (dupes.length) problems.push(`duplicados: ${dupes.map(([t, n]) => `${t} x${n}`).join(', ')}`);
  const status = problems.length ? 'fail' : 'pass';
  return R('54', 'Datos estructurados sin duplicar', status,
    `${blocks.length} bloque(s), tipos: ${Object.entries(counts).map(([t, n]) => n > 1 ? `${t} x${n}` : t).join(', ') || 'ninguno'}` +
      (problems.length ? ` — ${problems.join('; ')}` : ''),
    dupes.length ? 'Desactivar el schema del tema o el del plugin SEO, no ambos' :
      (invalid ? 'Corregir el JSON-LD invalido' : ''));
}

// --- 55. HTTPS y contenido mixto -------------------------------------------
function checkHttps(html, finalUrl) {
  if (!finalUrl.startsWith('https://')) {
    return R('55', 'HTTPS forzado y sin contenido mixto', 'fail',
      `La URL final sigue en HTTP: ${finalUrl}`, 'Forzar la redireccion HTTP -> HTTPS a nivel de servidor');
  }
  // Solo subrecursos: un <a href="http://..."> es un enlace, no contenido mixto.
  const mixed = new Set();
  for (const m of html.matchAll(/<(?:img|script|iframe|video|audio|source|embed)\b[^>]*\bsrc\s*=\s*["'](http:\/\/[^"']+)["']/gi)) mixed.add(m[1]);
  for (const m of html.matchAll(/<link\b[^>]*\bhref\s*=\s*["'](http:\/\/[^"']+)["'][^>]*>/gi)) {
    const a = attrsOf(m[0]);
    if (/stylesheet|preload|icon/i.test(a.rel || '')) mixed.add(m[1]);
  }
  for (const m of html.matchAll(/url\(\s*["']?(http:\/\/[^"')]+)["']?\s*\)/gi)) mixed.add(m[1]);
  const list = [...mixed];
  return R('55', 'HTTPS forzado y sin contenido mixto', list.length ? 'fail' : 'pass',
    list.length ? `${list.length} recurso(s) por http://: ${list.slice(0, 3).join(', ')}${list.length > 3 ? ' …' : ''}`
                : 'HTTPS y todos los subrecursos por https',
    list.length ? 'Servir esos recursos por https (o protocolo relativo)' : '');
}

// --- 56. cadenas de redirect ----------------------------------------------
async function followChain(request, startUrl, max = 8) {
  const hops = [];
  let cur = startUrl;
  for (let i = 0; i < max; i++) {
    const res = await get(request, cur, { maxRedirects: 0 });
    if (!res) { hops.push({ url: cur, status: 0 }); break; }
    const st = res.status();
    if (st < 300 || st >= 400) { hops.push({ url: cur, status: st }); break; }
    const loc = res.headers()['location'];
    hops.push({ url: cur, status: st, to: loc });
    if (!loc) break;
    try { cur = new URL(loc, cur).toString(); } catch { break; }
  }
  return hops;
}

async function checkRedirects(request, baseURL) {
  const u = new URL(baseURL);
  const bare = u.host.replace(/^www\./, '');
  // Las 4 variantes canonicas: solo una debe ser el destino final, y cada una
  // de las otras tres debe llegar ahi en UN salto 301.
  const variants = [
    `http://${bare}/`, `http://www.${bare}/`,
    `https://${bare}/`, `https://www.${bare}/`,
  ];
  const lines = [], problems = [], finals = new Set();
  for (const v of variants) {
    const hops = await followChain(request, v);
    const chain = hops.map(h => `${h.status}`).join('->');
    const finalUrl = hops[hops.length - 1].url;
    const redirectHops = hops.filter(h => h.status >= 300 && h.status < 400);
    finals.add(finalUrl.replace(/\/$/, ''));
    lines.push(`${v} [${chain}] -> ${finalUrl}`);
    if (redirectHops.length > 1) problems.push(`${v}: cadena de ${redirectHops.length} saltos`);
    if (redirectHops.some(h => h.status !== 301)) {
      problems.push(`${v}: usa ${redirectHops.map(h => h.status).filter(s => s !== 301).join('/')} en vez de 301`);
    }
    if (hops[hops.length - 1].status >= 400 || hops[hops.length - 1].status === 0) {
      problems.push(`${v}: termina en ${hops[hops.length - 1].status || 'sin respuesta'}`);
    }
  }
  // Las 4 variantes deben converger en UNA sola URL final: si no, el sitio
  // es accesible por dos hosts distintos y Google ve contenido duplicado.
  if (finals.size > 1) problems.push(`las variantes terminan en ${finals.size} URLs distintas: ${[...finals].join(', ')}`);
  const status = problems.length ? 'fail' : 'pass';
  return R('56', 'Redirects 301 sin cadenas', status,
    lines.join(' | ') + (problems.length ? ` — ${problems.join('; ')}` : ''),
    problems.length ? 'Normalizar www/no-www y http/https en un unico salto 301' : '');
}

// --- 57. noindex -----------------------------------------------------------
function robotsDirectives(html, headers) {
  const metas = [...headOf(html).matchAll(/<meta\b[^>]*>/gi)]
    .map(m => attrsOf(m[0]))
    .filter(a => /^(robots|googlebot)$/i.test(a.name || ''));
  const fromMeta = metas.map(a => a.content || '').join(', ');
  const fromHeader = headers['x-robots-tag'] || '';
  return { fromMeta, fromHeader, all: `${fromMeta} ${fromHeader}`.toLowerCase() };
}

function checkNoindex(html, headers, shouldBeNoindex, pageName) {
  const d = robotsDirectives(html, headers);
  const isNoindex = /\bnoindex\b/.test(d.all);
  const where = [d.fromMeta && `meta robots="${d.fromMeta}"`, d.fromHeader && `X-Robots-Tag: ${d.fromHeader}`]
    .filter(Boolean).join('; ') || 'sin directivas (indexable por defecto)';

  if (shouldBeNoindex) {
    return R('57', 'Noindex correcto', isNoindex ? 'pass' : 'fail',
      `${pageName} deberia estar excluida — ${where}`,
      isNoindex ? '' : 'Anadir noindex a esta pagina transaccional/sin valor de busqueda');
  }
  // Comprobacion inversa: la mas grave de toda la categoria — un noindex
  // heredado de staging deja la pagina fuera del indice sin avisar.
  return R('57', 'Noindex correcto', isNoindex ? 'fail' : 'pass',
    `${pageName} debe indexarse — ${where}`,
    isNoindex ? 'QUITAR el noindex: esta pagina deberia posicionar (suele venir heredado de staging)' : '');
}

// --- 58. hreflang ----------------------------------------------------------
function hreflangSet(html) {
  const map = new Map();
  for (const a of linkTags(html, 'alternate')) {
    if (a.hreflang && a.href) map.set(a.hreflang.toLowerCase(), a.href);
  }
  return map;
}

async function checkHreflang(request, html, finalUrl, cache) {
  const own = hreflangSet(html);
  if (own.size === 0) {
    return R('58', 'hreflang correcto', 'na',
      'La pagina no declara hreflang (sitio de un solo idioma, o falta configurar el plugin multi-idioma)');
  }
  const problems = [];
  const norm = (u) => { try { const x = new URL(u); return (x.origin + x.pathname).replace(/\/$/, '').toLowerCase(); } catch { return String(u).toLowerCase(); } };

  const bad = [...own.keys()].filter(k => !HREFLANG_CODE.test(k));
  if (bad.length) problems.push(`codigos invalidos: ${bad.join(', ')}`);

  // Region existente pero mal escrita: pasa el patron y aun asi Google la ignora.
  for (const code of own.keys()) {
    const region = code.split('-').pop();
    if (region !== code && Object.prototype.hasOwnProperty.call(WRONG_REGION, region)) {
      const fix = WRONG_REGION[region];
      problems.push(`"${code}": "${region}" no es un codigo de pais valido${fix ? ` (usa "${code.replace(region, fix)}")` : ''}`);
    }
  }

  const selfRef = [...own.values()].some(h => norm(h) === norm(finalUrl));
  if (!selfRef) problems.push('falta la auto-referencia (la pagina no se incluye en su propio set)');

  // El canonical tiene que estar DENTRO del set: si apunta fuera (tipico
  // canonical cruzado hacia la version por defecto), Google descarta el
  // cluster de hreflang entero, no solo ese par.
  const canon = (linkTags(html, 'canonical')[0] || {}).href;
  if (canon && ![...own.values()].some(h => norm(h) === norm(canon))) {
    problems.push(`el canonical (${canon}) no aparece en el set de hreflang: anula todo el cluster`);
  }

  // Avisos: degradan a warn, no a fail. No invalidan el cluster por si solos.
  const notes = [];
  if (!own.has('x-default')) notes.push('sin x-default (recomendado cuando hay selector de idioma)');

  // Mismo codigo declarado dos veces con destinos distintos: Google no sabe
  // cual elegir. El Map de arriba lo esconde, hay que mirar las etiquetas.
  const seen = new Map();
  for (const a of linkTags(html, 'alternate')) {
    if (!a.hreflang || !a.href) continue;
    const k = a.hreflang.toLowerCase();
    if (seen.has(k) && norm(seen.get(k)) !== norm(a.href)) {
      problems.push(`"${k}" declarado dos veces con destinos distintos: ${seen.get(k)} y ${a.href}`);
    }
    seen.set(k, a.href);
  }

  // Reciprocidad: cada alternativa debe declarar el mismo set de vuelta.
  for (const [code, href] of own) {
    if (norm(href) === norm(finalUrl)) continue;
    let other = cache.get(norm(href));
    if (other === undefined) {
      const res = await get(request, href);
      other = (res && res.status() === 200) ? hreflangSet(await res.text().catch(() => '')) : null;
      cache.set(norm(href), other);
    }
    if (!other) { problems.push(`${code}: ${href} no responde 200`); continue; }
    const back = [...other.values()].some(h => norm(h) === norm(finalUrl));
    if (!back) problems.push(`${code}: ${href} no devuelve el enlace (sin reciprocidad)`);
  }

  const status = problems.length ? 'fail' : (notes.length ? 'warn' : 'pass');
  const detail = [...problems, ...notes];
  return R('58', 'hreflang correcto', status,
    `set de ${own.size}: ${[...own.keys()].join(', ')}` + (detail.length ? ` — ${detail.join('; ')}` : ' — completo, reciproco y autorreferente'),
    problems.length ? 'Cada version debe listar TODAS las versiones incluida ella misma, de forma reciproca, y el canonical debe estar dentro del set' : (notes.length ? 'Anadir x-default apuntando a la version de respaldo' : ''));
}

// --- 46/49. unicidad de title y description (comprobacion de SITIO) --------
// "Unico" no se puede verificar mirando una sola pagina: hace falta comparar
// todas las del alcance. Por eso vive aqui y no en el helper por pagina.
function metaContent(html, name) {
  const m = [...headOf(html).matchAll(/<meta\b[^>]*>/gi)]
    .map(t => attrsOf(t[0]))
    .find(a => (a.name || '').toLowerCase() === name);
  return m ? (m.content || '').trim() : '';
}

function titleOf(html) {
  const m = headOf(html).match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  return m ? m[1].replace(/\s+/g, ' ').trim() : '';
}

function dupesOf(pages, key) {
  const byValue = new Map();
  for (const p of pages) {
    const v = (p[key] || '').trim().toLowerCase();
    if (!v) continue;
    byValue.set(v, [...(byValue.get(v) || []), p.name]);
  }
  return [...byValue.entries()].filter(([, names]) => names.length > 1);
}

function checkUniqueness(pages) {
  const out = [];
  for (const [c, key, name, rec] of [
    ['46', 'title', 'Titulo de pagina unico', 'Diferenciar el <title> de cada pagina: duplicados compiten entre si en Google'],
    ['49', 'description', 'Meta description unica', 'Redactar una description propia por pagina'],
  ]) {
    const missing = pages.filter(p => !(p[key] || '').trim()).map(p => p.name);
    const dupes = dupesOf(pages, key);
    if (dupes.length) {
      out.push(R(c, name, 'fail',
        dupes.map(([v, names]) => `"${v.slice(0, 60)}" en ${names.join(' + ')}`).join('; '), rec));
    } else if (missing.length) {
      out.push(R(c, name, 'fail', `sin ${key}: ${missing.join(', ')}`, rec));
    } else {
      out.push(R(c, name, 'pass', `${pages.length} paginas, ${key} distinto en todas`));
    }
  }
  return out;
}

// --- 57.1. staging expuesto (evidencia, no criterio puntuable) -------------
// La matriz de indexabilidad pide "verificar que staging no este ya indexado".
// Es detectable por HTTP: si el host parece un entorno de pruebas y responde
// publico + indexable, Google puede estar sirviendo el staging como si fuera
// el sitio real, con contenido duplicado sobre produccion.
const STAGING_HOST = /(^|[.-])(staging|stage|dev|test|pre|preprod|pruebas|demo)([.-]|$)/i;

function checkStagingExposure(finalUrl, html, headers, robotsBody = '') {
  let host = '';
  try { host = new URL(finalUrl).hostname; } catch { host = String(finalUrl); }
  if (!STAGING_HOST.test(host)) {
    return R('57.1', 'Exposicion de staging', 'pass', `${host} no parece un entorno de pruebas`);
  }
  const noindex = /\bnoindex\b/.test(robotsDirectives(html, headers).all);
  const blocked = /^\s*disallow:\s*\/\s*$/im.test(robotsBody);
  if (noindex || blocked) {
    return R('57.1', 'Exposicion de staging', 'pass',
      `${host} es un entorno de pruebas y esta protegido (${noindex ? 'noindex' : ''}${noindex && blocked ? ' + ' : ''}${blocked ? 'Disallow: /' : ''})`);
  }
  return R('57.1', 'Exposicion de staging', 'warn',
    `${host} parece un entorno de pruebas, responde publicamente y es indexable`,
    'Bloquearlo antes de que Google lo indexe: noindex + Disallow: / + clave de acceso. Si ya esta indexado, retirarlo por Search Console');
}

module.exports = {
  checkRobots, checkSitemap, checkCanonical, checkStructuredData,
  checkHttps, checkRedirects, checkNoindex, checkHreflang, followChain,
  checkUniqueness, checkStagingExposure, titleOf, metaContent,
  hreflangSet, robotsDirectives, headOf, linkTags, attrsOf,
};
