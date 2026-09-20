// @ts-check
// Autocomprobacion de la logica de parseo de lib/seo-tech.js. Sin red, sin
// framework, sin navegador:  node lib/seo-tech.selfcheck.js
// Si esto pasa, el parseo de canonical/JSON-LD/noindex/hreflang/mixto funciona.
const assert = require('assert');
const S = require('./seo-tech');

const page = (head, body = '') => `<!doctype html><html><head>${head}</head><body>${body}</body></html>`;
const U = 'https://ejemplo.com/producto/';

// --- 53 canonical ---
assert.strictEqual(S.checkCanonical(page(''), U).status, 'fail', 'sin canonical => fail');
assert.strictEqual(S.checkCanonical(page(`<link rel="canonical" href="${U}">`), U).status, 'pass');
assert.strictEqual(S.checkCanonical(page('<link rel="canonical" href="https://ejemplo.com/">'), U).status, 'fail',
  'canonical a la home desde una interior => fail');
// La barra final y el esquema no deben cambiar el veredicto.
assert.strictEqual(S.checkCanonical(page('<link rel="canonical" href="https://ejemplo.com/producto">'), U).status, 'pass');
assert.strictEqual(S.checkCanonical(page(`<link rel="canonical" href="${U}"><link rel="canonical" href="${U}">`), U).status,
  'fail', 'doble canonical (tema + plugin) => fail');

// --- 54 datos estructurados: lo que decide es el CONTEO por @type ---
const ld = (o) => `<script type="application/ld+json">${JSON.stringify(o)}</script>`;
assert.strictEqual(S.checkStructuredData(page(ld({ '@type': 'Product', name: 'x' }))).status, 'pass');
assert.strictEqual(
  S.checkStructuredData(page(ld({ '@type': 'Product', name: 'a' }) + ld({ '@type': 'Product', name: 'b' }))).status,
  'fail', 'doble Product (caso tipico WooCommerce) => fail');
// @graph de RankMath: hay que aplanarlo o los duplicados pasan desapercibidos.
assert.strictEqual(
  S.checkStructuredData(page(ld({ '@graph': [{ '@type': 'Product' }, { '@type': 'Organization' }] }))).status,
  'pass', '@graph con tipos distintos => pass');
assert.strictEqual(
  S.checkStructuredData(page(ld({ '@graph': [{ '@type': 'Product' }] }) + ld({ '@type': 'Product' }))).status,
  'fail', 'Product en @graph + Product suelto => fail');
// BreadcrumbList/ListItem se repiten de forma legitima: no deben dar falso positivo.
assert.strictEqual(
  S.checkStructuredData(page(ld({ '@graph': [{ '@type': 'BreadcrumbList' }, { '@type': 'BreadcrumbList' }] }))).status,
  'pass', 'BreadcrumbList repetido no es duplicado de entidad');
assert.strictEqual(
  S.checkStructuredData(page('<script type="application/ld+json">{roto</script>')).status, 'fail', 'JSON invalido => fail');

// --- 55 HTTPS / contenido mixto ---
assert.strictEqual(S.checkHttps(page(''), 'http://ejemplo.com/').status, 'fail', 'URL final en http => fail');
assert.strictEqual(S.checkHttps(page(''), U).status, 'pass');
assert.strictEqual(S.checkHttps(page('', '<img src="http://ejemplo.com/a.jpg">'), U).status, 'fail', 'img http => mixto');
assert.strictEqual(S.checkHttps(page('<link rel="stylesheet" href="http://cdn.com/a.css">'), U).status, 'fail');
// Un enlace <a> a http NO es contenido mixto: es solo un enlace.
assert.strictEqual(S.checkHttps(page('', '<a href="http://otro.com/">otro</a>'), U).status, 'pass',
  'un <a href="http://"> no es contenido mixto');

// --- 57 noindex, en los dos sentidos ---
const noidx = '<meta name="robots" content="noindex, follow">';
assert.strictEqual(S.checkNoindex(page(noidx), {}, true, 'Checkout').status, 'pass', 'checkout con noindex => pass');
assert.strictEqual(S.checkNoindex(page(''), {}, true, 'Checkout').status, 'fail', 'checkout indexable => fail');
assert.strictEqual(S.checkNoindex(page(''), {}, false, 'Home').status, 'pass');
assert.strictEqual(S.checkNoindex(page(noidx), {}, false, 'Home').status, 'fail',
  'noindex heredado de staging en una pagina que debe posicionar => fail');
assert.strictEqual(S.checkNoindex(page(''), { 'x-robots-tag': 'noindex' }, false, 'Home').status, 'fail',
  'noindex por cabecera HTTP tambien cuenta');

// --- 58 hreflang (parte sincrona: extraccion del set) ---
const hl = S.hreflangSet(page(
  '<link rel="alternate" hreflang="es" href="https://ejemplo.com/es/">' +
  '<link rel="alternate" hreflang="en-US" href="https://ejemplo.com/en/">' +
  '<link rel="alternate" hreflang="x-default" href="https://ejemplo.com/">'));
assert.strictEqual(hl.size, 3);
assert.strictEqual(hl.get('en-us'), 'https://ejemplo.com/en/', 'los codigos se normalizan a minusculas');
assert.strictEqual(S.hreflangSet(page('<link rel="stylesheet" href="/a.css">')).size, 0,
  'rel="stylesheet" no es un alternate');

// --- 58 hreflang (parte async: reciprocidad, canonical y codigos) ---
// Stub de `request`: sirve HTML fijo por URL, sin red.
const fakeRequest = (byUrl) => ({
  get: async (url) => ({ status: () => (byUrl[url] === undefined ? 404 : 200), text: async () => byUrl[url] || '', url: () => url }),
});
const alt = (code, href) => `<link rel="alternate" hreflang="${code}" href="${href}">`;
const ES = 'https://ejemplo.com/es/', EN = 'https://ejemplo.com/en/';
const pair = (self) => alt('es', ES) + alt('en', EN) + alt('x-default', ES) +
  `<link rel="canonical" href="${self}">`;
const hreflang = (extra, self = ES, others = { [EN]: page(pair(EN)) }) =>
  S.checkHreflang(fakeRequest(others), page(pair(self) + extra), self, new Map());

(async () => {
  assert.strictEqual((await hreflang('')).status, 'pass', 'set completo, reciproco, con x-default y canonical propio');

  assert.strictEqual(
    (await S.checkHreflang(fakeRequest({}), page(alt('es', ES) + alt('en-UK', EN) + alt('x-default', ES)), ES, new Map())).status,
    'fail', 'en-UK no es un codigo de pais valido (es GB)');

  const noXdef = await S.checkHreflang(
    fakeRequest({ [EN]: page(alt('es', ES) + alt('en', EN)) }),
    page(alt('es', ES) + alt('en', EN)), ES, new Map());
  assert.strictEqual(noXdef.status, 'warn', 'falta x-default => warn, no fail: no invalida el cluster');

  const crossCanon = await S.checkHreflang(
    fakeRequest({ [EN]: page(pair(EN)) }),
    page(alt('es', ES) + alt('en', EN) + alt('x-default', ES) + '<link rel="canonical" href="https://ejemplo.com/otra/">'),
    ES, new Map());
  assert.strictEqual(crossCanon.status, 'fail', 'canonical fuera del set => se anula el cluster entero');
  assert.ok(crossCanon.evidence.includes('no aparece en el set'));

  const dup = await S.checkHreflang(
    fakeRequest({ [EN]: page(pair(EN)) }),
    page(alt('es', ES) + alt('en', EN) + alt('en', 'https://ejemplo.com/en-gb/') + alt('x-default', ES) + `<link rel="canonical" href="${ES}">`),
    ES, new Map());
  assert.strictEqual(dup.status, 'fail', 'mismo codigo con dos destinos distintos => fail');

  assert.strictEqual(
    (await S.checkHreflang(fakeRequest({}), page(''), ES, new Map())).status, 'na',
    'sitio de un solo idioma => N/A, no fallo');

  console.log('seo-tech: comprobaciones async de hreflang OK');
})().catch(e => { console.error(e); process.exit(1); });

// --- 46/49 unicidad entre paginas ---
const pg = (name, title, desc) => ({ name, title, description: desc });
const uniqOk = S.checkUniqueness([pg('Home', 'Inicio', 'Bienvenido'), pg('Contacto', 'Contacto', 'Escribenos')]);
assert.deepStrictEqual(uniqOk.map(r => r.status), ['pass', 'pass']);
const uniqDup = S.checkUniqueness([pg('Home', 'Inicio', 'Igual'), pg('Blog', 'Inicio', 'Igual')]);
assert.deepStrictEqual(uniqDup.map(r => r.status), ['fail', 'fail'], 'title y description repetidos => fail en 46 y 49');
assert.ok(uniqDup[0].evidence.includes('Home') && uniqDup[0].evidence.includes('Blog'),
  'la evidencia nombra las paginas que colisionan');
assert.strictEqual(S.checkUniqueness([pg('Home', 'Inicio', 'X'), pg('INICIO copia', 'inicio', 'Y')])[0].status, 'fail',
  'la comparacion ignora mayusculas: "Inicio" e "inicio" son el mismo titulo');
assert.strictEqual(S.checkUniqueness([pg('Home', 'Inicio', ''), pg('Blog', 'Blog', 'Y')])[1].status, 'fail',
  'description ausente => fail, no pass por no colisionar');

// --- extractores usados por la unicidad ---
assert.strictEqual(S.titleOf('<head><title>  Hola   mundo </title></head>'), 'Hola mundo',
  'el titulo se normaliza en espacios');
assert.strictEqual(S.metaContent(page('<meta name="Description" content="Texto">'), 'description'), 'Texto',
  'el atributo name no distingue mayusculas');

// --- 57.1 exposicion de staging ---
const st = (url, extra = '', robots = '') => S.checkStagingExposure(url, page(extra), {}, robots);
assert.strictEqual(st('https://www.ejemplo.com/').status, 'pass', 'un host de produccion no dispara el aviso');
assert.strictEqual(st('https://staging.ejemplo.com/').status, 'warn',
  'staging publico e indexable => warn');
assert.strictEqual(st('https://staging.ejemplo.com/', noidx).status, 'pass', 'staging con noindex esta protegido');
assert.strictEqual(st('https://dev.ejemplo.com/', '', 'User-agent: *\nDisallow: /').status, 'pass',
  'staging con Disallow: / esta protegido');
assert.strictEqual(st('https://desarrollo-web.ejemplo.com/').status, 'pass',
  '"desarrollo" no es "dev": el patron no debe disparar por subcadena');

console.log('seo-tech: todas las comprobaciones OK');
