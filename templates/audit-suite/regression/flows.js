// @ts-check
// Flujos de comprador de WooCommerce. Cada flujo es { id, title, devices, run(c) }:
//   - devuelve una cadena de evidencia (queda en el informe) o lanza para dar FAIL;
//   - llama a c.skip(motivo) cuando la funcion NO existe en el sitio: SKIP, nunca FAIL;
//   - NO hace pedidos, NO pulsa "Realizar pedido" y NO envia correo fuera de un clon.
// El contexto `c` lo arma tests/regression.spec.js (ver ahi sus campos).
const { parsePrice, currencyToken, isSorted, searchWord, judgeMailStatus } = require('./helpers');

const BOTH = ['desktop', 'mobile'];
const FATAL = /Fatal error|There has been a critical error|Parse error|Uncaught (Error|Exception)|Stack trace:/i;

// ---------- utilidades ----------
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Primer elemento visible de un selector CSS (lista separada por comas), o null. */
async function firstVisible(page, selector) {
  if (!selector) return null;
  const loc = page.locator(selector);
  const n = Math.min(await loc.count().catch(() => 0), 40);
  for (let i = 0; i < n; i++) {
    const el = loc.nth(i);
    if (await el.isVisible().catch(() => false)) return el;
  }
  return null;
}
async function anyExists(page, selector) {
  return selector ? (await page.locator(selector).count().catch(() => 0)) > 0 : false;
}
async function waitFor(fn, ms = 8000, step = 250) {
  const t = Date.now();
  while (Date.now() - t < ms) { const v = await fn().catch(() => false); if (v) return v; await sleep(step); }
  return false;
}
/** Texto del precio de los primeros `n` productos visibles (el precio rebajado si lo hay). */
const listPrices = (c, n = 8) => c.page.evaluate(({ list, price, n }) => {
  const seen = [];
  for (const card of document.querySelectorAll(list)) {
    const r = card.getBoundingClientRect();
    const p = card.querySelector(price);
    if (r.width > 0 && r.height > 0 && p) {
      const sale = p.querySelector('ins');
      seen.push((sale || p).innerText.replace(/\s+/g, ' ').trim());
    }
    if (seen.length >= n) break;
  }
  return seen;
}, { list: c.S.productList, price: c.S.price, n });

/** Productos visibles del listado (cuenta). */
const listCount = (c) => c.page.locator(c.S.productList).count();
const firstProductHref = (c) => c.page.evaluate((sel) => {
  const a = document.querySelector(sel); return a ? a.getAttribute('href') : '';
}, c.S.productLink);

/** Lleva una pagina clave; si da 404 con el slug por defecto, SKIP con la pista de config. */
async function goKey(c, key) {
  const url = c.cfg.urls[key];
  const st = await c.go(url);
  if (st === 404 || !st) c.skip(`urls.${key} (${url}) no responde (HTTP ${st}): fija regression.urls.${key} con la ruta real`);
  return st;
}

/** Descubre productos y categorias con la API Store de WooCommerce (publica por defecto). */
async function discover(c) {
  const st = c.state;
  if (st.discovered) return st;
  st.discovered = true;
  st.products = [];
  try {
    const r = await c.page.request.get('/wp-json/wc/store/v1/products?per_page=60');
    if (r.ok()) st.products = await r.json();
  } catch { /* sin API: se usan solo las rutas configuradas */ }
  const abs = (u) => { try { return new URL(u, c.base).pathname + new URL(u, c.base).search; } catch { return u; } };
  const simple = st.products.find((p) => p.type === 'simple' && p.is_purchasable && p.is_in_stock && !p.has_options);
  const variable = st.products.find((p) => p.type === 'variable' && p.is_in_stock);
  st.simple = c.cfg.urls.product ? { permalink: c.cfg.urls.product, id: simple ? simple.id : 0, name: simple ? simple.name : '', configured: true } : simple && { id: simple.id, name: simple.name, permalink: abs(simple.permalink) };
  st.variable = c.cfg.urls.variableProduct ? { permalink: c.cfg.urls.variableProduct } : variable && { id: variable.id, name: variable.name, permalink: abs(variable.permalink) };
  const cat = st.products.flatMap((p) => p.categories || []).find((x) => x.link);
  st.category = c.cfg.urls.category || (cat ? abs(cat.link) : '');
  st.term = c.cfg.urls.searchTerm || searchWord((simple || st.products[0] || {}).name);
  return st;
}

/** Deja el carrito con un producto simple, por la URL ?add-to-cart= (equivale a pulsar el boton). */
async function cartWithOne(c) {
  const st = await discover(c);
  if (st.simple && st.simple.configured && !st.simple.id) c.skip('urls.product esta configurada pero la API Store no devolvio ningun producto simple comprable: sin su id no se puede llenar el carrito');
  if (!st.simple || !st.simple.id) c.skip('no se encontro un producto simple comprable con id (la API Store de WooCommerce no responde): sin ella no se puede llenar el carrito');
  await c.go(`/?add-to-cart=${st.simple.id}`);
  const n = await c.cartCount();
  c.assert(n >= 1, `el carrito sigue vacio tras ?add-to-cart=${st.simple.id}`);
  return st.simple;
}

// ---------- flujos ----------
const flows = [];
const add = (id, title, devices, run) => flows.push({ id, title, devices, run });

add('home', 'Home carga sin errores', BOTH, async (c) => {
  const st = await c.go(c.cfg.urls.home);
  c.assert(st === 200, `HTTP ${st}`);
  const body = await c.page.evaluate(() => document.body.innerText.slice(0, 6000));
  c.assert(!FATAL.test(body), 'error PHP visible en la pagina');
  c.assert((await c.page.title()).trim().length > 0, 'sin <title>');
  c.assert(await anyExists(c.page, c.S.header), 'sin cabecera');
  await c.interact();
  const broken = await c.page.evaluate(() => [...document.images].filter((i) => {
    const r = i.getBoundingClientRect();
    return r.width > 20 && r.height > 20 && r.bottom > 0 && r.top < innerHeight && i.complete && i.naturalWidth === 0 && (i.currentSrc || i.src);
  }).map((i) => (i.currentSrc || i.src).slice(-60)));
  c.assert(!broken.length, `${broken.length} imagen(es) rota(s) a la vista: ${broken.slice(0, 3).join(', ')}`);
  return `HTTP 200, titulo "${(await c.page.title()).slice(0, 60)}"`;
});

add('search-live', 'Buscador: sugerencias AJAX', BOTH, async (c) => {
  const st = await discover(c);
  if (!st.term) c.skip('sin termino de busqueda (la API Store no devolvio productos): fija regression.urls.searchTerm');
  await c.go(c.cfg.urls.home);
  await c.interact();
  let input = await firstVisible(c.page, c.S.searchInput);
  if (!input) {
    const tg = await firstVisible(c.page, c.S.searchToggle);
    if (tg) { await tg.click({ timeout: 5000 }).catch(() => {}); await sleep(800); input = await firstVisible(c.page, c.S.searchInput); }
  }
  if (!input) c.skip('no hay campo de busqueda visible en la home');
  await input.click({ timeout: 4000 }).catch(() => {});
  await input.pressSequentially(st.term, { delay: 120 });
  const shown = await waitFor(async () => {
    const box = await firstVisible(c.page, c.S.searchSuggestions);
    return box && (await box.locator('a').count()) > 0;
  }, 9000);
  if (!shown) c.skip('el buscador no muestra sugerencias AJAX (solo busqueda por pagina de resultados)');
  const href = await c.page.evaluate((sel) => {
    const box = [...document.querySelectorAll(sel)].find((b) => b.getBoundingClientRect().height > 0);
    const a = box && box.querySelector('a[href]'); return a ? a.getAttribute('href') : '';
  }, c.S.searchSuggestions);
  c.assert(href, 'las sugerencias no traen enlaces');
  const code = await c.go(href);
  c.assert(code === 200, `el enlace de la sugerencia da HTTP ${code}`);
  return `"${st.term}" -> sugerencias con enlace que abre (${href.slice(0, 60)})`;
});

add('search-results', 'Buscador: pagina de resultados', BOTH, async (c) => {
  const st = await discover(c);
  if (!st.term) c.skip('sin termino de busqueda: fija regression.urls.searchTerm');
  const code = await c.go(`/?s=${encodeURIComponent(st.term)}&post_type=product`);
  c.assert(code === 200, `HTTP ${code}`);
  const n = await listCount(c);
  c.assert(n > 0, `sin productos para "${st.term}"`);
  return `${n} producto(s) para "${st.term}"`;
});

add('archive', 'Categoria: listado, filtros y paginacion', BOTH, async (c) => {
  const st = await discover(c);
  let url = st.category;
  if (!url) { await goKey(c, 'shop'); url = c.cfg.urls.shop; }
  const code = await c.go(url);
  c.assert(code === 200, `HTTP ${code} (${url})`);
  const n = await listCount(c);
  c.assert(n > 0, 'el archivo no lista productos');
  const out = [`${n} productos en ${url}`];
  // filtro: si hay widget de filtro, pulsarlo cambia la lista o la URL
  const f = await firstVisible(c.page, c.S.filterLink);
  if (f) {
    const before = await firstProductHref(c); const u0 = c.page.url();
    await f.click({ timeout: 6000 }).catch(() => {}); await sleep(2500);
    const ok = await c.page.locator(c.S.productList).count() > 0 || c.page.url() !== u0;
    c.assert(ok, 'el filtro dejo el archivo sin productos y sin cambio de URL');
    out.push(`filtro: ${c.page.url() !== u0 || (await firstProductHref(c)) !== before ? 'cambia el listado' : 'sin cambio visible'}`);
    await c.go(url);
  } else out.push('filtros: no hay (omitido)');
  // paginacion
  const next = await firstVisible(c.page, c.S.paginationNext);
  if (next) {
    const first = await firstProductHref(c);
    const href = await next.getAttribute('href');
    await Promise.all([c.page.waitForLoadState('load').catch(() => {}), next.click({ timeout: 6000 })]);
    await sleep(1200);
    c.assert((await listCount(c)) > 0, 'la pagina 2 no lista productos');
    c.assert((await firstProductHref(c)) !== first, `la pagina 2 (${href}) repite el primer producto`);
    out.push('paginacion: pagina 2 distinta');
  } else out.push('paginacion: una sola pagina (omitida)');
  return out.join('; ');
});

add('sorting', 'Ordenacion por precio', BOTH, async (c) => {
  const st = await discover(c);
  await c.go(st.category || c.cfg.urls.shop);
  const sel = await firstVisible(c.page, c.S.sortSelect);
  if (!sel) c.skip('no hay desplegable de ordenacion');
  const options = await sel.locator('option').evaluateAll((os) => os.map((o) => o.value));
  const asc = options.find((v) => v === 'price'); const desc = options.find((v) => v === 'price-desc');
  if (!asc || !desc) c.skip('el desplegable no ofrece orden por precio');
  const read = async (value) => {
    await Promise.all([c.page.waitForLoadState('load').catch(() => {}), sel.selectOption(value)]);
    await sleep(1800);
    return (await listPrices(c, 12)).map(parsePrice);
  };
  const up = await read(asc);
  await c.go(st.category || c.cfg.urls.shop);
  const s2 = await firstVisible(c.page, c.S.sortSelect);
  await Promise.all([c.page.waitForLoadState('load').catch(() => {}), s2.selectOption(desc)]);
  await sleep(1800);
  const down = (await listPrices(c, 12)).map(parsePrice);
  c.assert(isSorted(up, 'asc'), `orden ascendente roto: ${up.join(', ')}`);
  c.assert(isSorted(down, 'desc'), `orden descendente roto: ${down.join(', ')}`);
  return `asc ${up.slice(0, 4).join(' <= ')}; desc ${down.slice(0, 4).join(' >= ')}`;
});

add('currency', 'Cambiador de moneda: cambia y persiste', BOTH, async (c) => {
  const cur = c.cfg.currency;
  const st = await discover(c);
  const listing = st.category || c.cfg.urls.shop;
  const snap = async () => { await sleep(1800); const p = await listPrices(c, 6); return { p, tok: currencyToken(p[0]), n: parsePrice(p[0]) }; };
  if (cur.urlParam && cur.codes.length >= 2) {
    const [a, b] = cur.codes;
    const q = (code) => `${listing}${listing.includes('?') ? '&' : '?'}${cur.urlParam}=${encodeURIComponent(code)}`;
    await c.go(q(a)); const A = await snap();
    c.assert(A.p.length, `sin precios con ${a}`);
    await c.go(q(b)); const B = await snap();
    c.assert(B.p.join('|') !== A.p.join('|'), `los precios no cambian de ${a} a ${b}: ${A.p[0]} / ${B.p[0]}`);
    c.assert(B.tok !== A.tok || B.n !== A.n, `ni el simbolo ni el importe cambian (${A.p[0]} / ${B.p[0]})`);
    await c.go(listing); const kept = await snap();
    c.assert(kept.p.join('|') === B.p.join('|'), `la moneda ${b} no persiste al navegar: ${B.p[0]} -> ${kept.p[0]}`);
    if (st.simple && st.simple.permalink) {
      await c.go(st.simple.permalink); await sleep(1200);
      const pp = await c.page.locator(c.S.price).first().innerText().catch(() => '');
      c.assert(!pp || currencyToken(pp) === B.tok, `la ficha no mantiene ${b}: "${pp}"`);
    }
    await c.go(q(a));
    return `${a} ${A.p[0]} -> ${b} ${B.p[0]}; persiste al navegar`;
  }
  await c.go(listing);
  const sw = await firstVisible(c.page, cur.switcher);
  if (!sw) c.skip('no hay cambiador de moneda (sin plugin multimoneda activo o sin selector); fija regression.currency si existe');
  const A = await snap();
  c.assert(A.p.length, 'sin precios en el listado');
  const tag = await sw.evaluate((e) => e.tagName);
  if (tag === 'SELECT') {
    const values = await sw.locator('option').evaluateAll((os) => os.map((o) => o.value));
    const cur0 = await sw.inputValue();
    const other = values.find((v) => v && v !== cur0);
    c.assert(other, 'el selector de moneda solo ofrece una opcion');
    await Promise.all([c.page.waitForLoadState('load').catch(() => {}), sw.selectOption(other)]);
  } else {
    const opt = await firstVisible(c.page, `${cur.switcher.split(',').map((s) => s.trim() + ' a, ' + s.trim() + ' li, ' + s.trim() + ' button').join(', ')}`);
    c.assert(opt, 'no hay opciones de moneda pulsables');
    const all = c.page.locator(`${cur.switcher.split(',').map((s) => s.trim() + ' a, ' + s.trim() + ' button').join(', ')}`);
    const k = await all.count(); let clicked = false;
    for (let i = 0; i < k && !clicked; i++) {
      const o = all.nth(i);
      const active = await o.evaluate((e) => /active|current|selected/.test(e.className + ' ' + (e.parentElement ? e.parentElement.className : '')) || e.getAttribute('aria-current') === 'true').catch(() => false);
      if (!active && (await o.isVisible().catch(() => false))) { await o.click({ timeout: 5000 }).catch(() => {}); clicked = true; }
    }
    c.assert(clicked, 'no se pudo pulsar una moneda distinta de la activa');
    await c.page.waitForLoadState('load').catch(() => {});
  }
  const B = await snap();
  c.assert(B.p.join('|') !== A.p.join('|'), `los precios no cambian al cambiar de moneda: ${A.p[0]} / ${B.p[0]}`);
  await c.go(listing); const kept = await snap();
  c.assert(kept.p.join('|') === B.p.join('|'), `la moneda no persiste al navegar: ${B.p[0]} -> ${kept.p[0]}`);
  return `${A.p[0]} -> ${B.p[0]}; persiste al navegar`;
});

add('product-page', 'Ficha: galeria, zoom y variaciones', BOTH, async (c) => {
  const st = await discover(c);
  const target = st.simple || st.variable;
  if (!target) c.skip('no se encontro ningun producto (API Store sin respuesta); fija regression.urls.product');
  const code = await c.go(target.permalink);
  c.assert(code === 200, `HTTP ${code}`);
  c.assert(await anyExists(c.page, c.S.addToCart), 'la ficha no tiene boton de anadir al carrito');
  const out = [`ficha ${target.permalink}`];
  const thumbs = c.page.locator(c.S.galleryThumbs);
  if ((await thumbs.count()) > 1) {
    const main = () => c.page.locator(c.S.galleryMain).first().evaluate((i) => i.currentSrc || i.src);
    const before = await main();
    await thumbs.nth(1).click({ timeout: 5000 }).catch(() => {}); await sleep(900);
    c.assert((await main()) !== before, 'pulsar una miniatura no cambia la imagen principal');
    out.push('galeria: la miniatura cambia la imagen');
  } else out.push('galeria: una sola imagen (omitida)');
  if (!c.isMobile) {
    const img = await firstVisible(c.page, c.S.galleryMain);
    if (img) {
      await img.hover({ timeout: 4000 }).catch(() => {}); await sleep(700);
      const z = await anyExists(c.page, c.S.zoom);
      out.push(z ? 'zoom: presente' : 'zoom: el tema no lo usa (omitido)');
    }
  }
  return out.join('; ');
});

add('variation', 'Ficha variable: elegir variacion', BOTH, async (c) => {
  const st = await discover(c);
  if (!st.variable) c.skip('no hay producto variable');
  const code = await c.go(st.variable.permalink);
  c.assert(code === 200, `HTTP ${code}`);
  const selects = c.page.locator(c.S.variationSelect);
  const n = await selects.count();
  if (!n) c.skip('el producto variable no muestra selectores de variacion (usa muestras de color u otro control)');
  for (let i = 0; i < n; i++) {
    const vals = await selects.nth(i).locator('option').evaluateAll((os) => os.map((o) => o.value).filter(Boolean));
    c.assert(vals.length, `el atributo ${i + 1} no tiene opciones`);
    await selects.nth(i).selectOption(vals[0]); await sleep(600);
  }
  const ready = await waitFor(async () => (await c.page.locator(c.S.addToCart).first().getAttribute('class').catch(() => '') || '').indexOf('disabled') === -1, 6000);
  c.assert(ready, 'tras elegir las opciones el boton de anadir sigue desactivado (combinacion sin stock o JS roto)');
  const price = await c.page.locator(c.S.variationReady).first().innerText().catch(() => '');
  return `variacion elegida${price ? `, precio ${price.replace(/\s+/g, ' ').trim()}` : ''}`;
});

add('add-to-cart', 'Anadir al carrito (AJAX)', BOTH, async (c) => {
  const st = await discover(c);
  if (!st.simple) c.skip('no se encontro un producto simple comprable');
  await c.go(st.simple.permalink);
  const btn = await firstVisible(c.page, c.S.addToCart);
  c.assert(btn, 'sin boton de anadir visible');
  const before = await c.cartCount();
  await btn.click({ timeout: 8000 });
  const grew = await waitFor(async () => (await c.cartCount()) > before, 12000);
  c.assert(grew, `el carrito no crece tras pulsar (antes ${before})`);
  return `articulos ${before} -> ${await c.cartCount()}`;
});

add('quick-view', 'Vista rapida abre y cierra', ['desktop'], async (c) => {
  const st = await discover(c);
  await c.go(st.category || c.cfg.urls.shop);
  const qv = await firstVisible(c.page, c.S.quickView);
  if (!qv) c.skip(c.isMobile ? 'vista rapida oculta en movil' : 'el tema no tiene vista rapida (o no es visible sin pasar el raton)');
  await qv.click({ timeout: 6000, force: true });
  const open = await waitFor(() => firstVisible(c.page, c.S.quickViewModal), 8000);
  c.assert(open, 'la vista rapida no se abre');
  const close = await firstVisible(c.page, c.S.quickViewClose);
  if (close) await close.click({ timeout: 4000 }).catch(() => {}); else await c.page.keyboard.press('Escape');
  const gone = await waitFor(async () => !(await firstVisible(c.page, c.S.quickViewModal)), 6000);
  c.assert(gone, 'la vista rapida no se cierra');
  return 'abre y cierra';
});

add('wishlist', 'Lista de deseos: anadir y quitar', BOTH, async (c) => {
  const st = await discover(c);
  const target = st.simple || st.variable;
  if (!target) c.skip('no se encontro ningun producto');
  await c.go(target.permalink);
  const btn = await firstVisible(c.page, c.S.wishlistButton);
  if (!btn) c.skip('no hay boton de lista de deseos en la ficha');
  const sig = () => btn.evaluate((e) => [e.className, e.getAttribute('aria-pressed') || '', e.getAttribute('title') || '', e.textContent.trim()].join('|'));
  const s0 = await sig();
  await btn.click({ timeout: 6000 }); await sleep(2000);
  const s1 = await sig();
  c.assert(s1 !== s0, 'pulsar el corazon no cambia su estado (anadir)');
  await btn.click({ timeout: 6000 }).catch(() => {}); await sleep(2000);
  const s2 = await sig();
  c.assert(s2 !== s1, 'pulsar de nuevo no cambia su estado (quitar)');
  return 'anadir y quitar cambian el estado del boton';
});

add('cart', 'Carrito: cantidad, eliminar y cupon', BOTH, async (c) => {
  await cartWithOne(c);
  await goKey(c, 'cart');
  const out = [];
  const qty = await firstVisible(c.page, c.S.cartQty);
  c.assert(qty, 'el carrito no muestra campo de cantidad');
  await qty.fill('2');
  const upd = await firstVisible(c.page, c.S.cartUpdate);
  if (upd) { await upd.click({ timeout: 6000 }).catch(() => {}); } else { await qty.blur(); }
  const two = await waitFor(async () => (await c.cartCount()) >= 2, 10000);
  c.assert(two, 'cambiar la cantidad a 2 no actualiza el carrito');
  out.push('cantidad 2');
  // cupon: solo se comprueba el campo y el rechazo de un codigo inexistente
  let field = await firstVisible(c.page, c.S.couponInput);
  if (!field) { const tg = await firstVisible(c.page, c.S.couponToggle); if (tg) { await tg.click({ timeout: 4000 }).catch(() => {}); await sleep(500); field = await firstVisible(c.page, c.S.couponInput); } }
  if (field) {
    await field.fill('regression-no-such-code');
    const apply = await firstVisible(c.page, c.S.couponSubmit);
    if (apply) await apply.click({ timeout: 5000 }).catch(() => {}); else await field.press('Enter');
    const err = await waitFor(() => firstVisible(c.page, c.S.noticeError), 8000);
    c.assert(err, 'un cupon inexistente no muestra error');
    out.push('cupon inexistente rechazado');
  } else out.push('cupon: sin campo (cupones desactivados, omitido)');
  await goKey(c, 'cart');
  const rm = await firstVisible(c.page, c.S.cartRemove);
  c.assert(rm, 'sin enlace para eliminar la linea');
  await rm.click({ timeout: 6000 });
  const empty = await waitFor(async () => (await c.cartCount()) === 0, 10000);
  c.assert(empty, 'eliminar la linea no vacia el carrito');
  out.push('linea eliminada');
  return out.join('; ');
});

add('checkout', 'Checkout: renderiza y valida (sin pedido)', BOTH, async (c) => {
  await cartWithOne(c);
  // red de seguridad: este flujo jamas debe completar un pedido
  await c.page.route(/wc-ajax=checkout|wc\/store\/v1\/checkout/, (r) => (r.request().method() === 'POST' ? r.abort() : r.continue()));
  await goKey(c, 'checkout');
  c.assert(await waitFor(() => firstVisible(c.page, c.S.checkoutForm), 12000), 'el formulario de checkout no se muestra');
  const fields = c.page.locator(c.S.checkoutRequired);
  const n = await fields.count();
  c.assert(n > 0, 'el checkout no tiene campos obligatorios');
  const target = await (async () => { for (let i = 0; i < n; i++) { const f = fields.nth(i); if (await f.isVisible().catch(() => false)) return f; } return null; })();
  c.assert(target, 'ningun campo obligatorio visible');
  await target.fill('');
  await target.focus(); await target.blur(); await sleep(900);
  const invalid = await c.page.evaluate(() => !!document.querySelector('.woocommerce-invalid, .validate-required.woocommerce-invalid, .has-error, .wc-block-components-validation-error, input[aria-invalid="true"]'));
  c.assert(invalid, 'dejar vacio un campo obligatorio no lo marca como invalido');
  c.assert(!/order-received/.test(c.page.url()), 'se llego a una pagina de pedido recibido');
  await c.page.unroute(/wc-ajax=checkout|wc\/store\/v1\/checkout/);
  return `${n} campos obligatorios; el vacio se marca invalido; no se pulsa "realizar pedido"`;
});

add('account', 'Mi cuenta: login y registro', BOTH, async (c) => {
  await goKey(c, 'account');
  const form = await firstVisible(c.page, c.S.loginForm);
  c.assert(form, 'la pagina de cuenta no muestra el formulario de acceso');
  const out = ['formulario de acceso'];
  out.push((await anyExists(c.page, c.S.registerForm)) ? 'formulario de registro presente' : 'registro: desactivado (omitido)');
  const u = await firstVisible(c.page, c.S.loginUser); const p = await firstVisible(c.page, c.S.loginPass);
  c.assert(u && p, 'faltan los campos de usuario o contrasena');
  await u.fill('regression-no-such-user'); await p.fill('regression-wrong-password');
  const sub = await firstVisible(c.page, c.S.loginSubmit);
  c.assert(sub, 'sin boton de acceso');
  await Promise.all([c.page.waitForLoadState('load').catch(() => {}), sub.click({ timeout: 6000 })]);
  const err = await waitFor(() => firstVisible(c.page, c.S.noticeError), 8000);
  c.assert(err, 'unas credenciales falsas no muestran error');
  out.push('credenciales falsas rechazadas con mensaje');
  const user = process.env.REGRESSION_CUSTOMER_USER; const pass = process.env.REGRESSION_CUSTOMER_PASS;
  if (user && pass) {
    await goKey(c, 'account');
    await (await firstVisible(c.page, c.S.loginUser)).fill(user); await (await firstVisible(c.page, c.S.loginPass)).fill(pass);
    await Promise.all([c.page.waitForLoadState('load').catch(() => {}), (await firstVisible(c.page, c.S.loginSubmit)).click()]);
    c.assert(!(await anyExists(c.page, c.S.loginForm)), 'el acceso con la cuenta de prueba no entra');
    out.push('acceso con la cuenta de prueba (REGRESSION_CUSTOMER_*)');
  }
  return out.join('; ');
});

add('contact-form', 'Contacto: validacion y envio', BOTH, async (c) => {
  if (!c.cfg.urls.contact) c.skip('regression.urls.contact vacio: no hay pagina de contacto configurada');
  const code = await c.go(c.cfg.urls.contact);
  c.assert(code === 200, `HTTP ${code}`);
  const form = c.page.locator(c.S.contactForm).first();
  if (!(await form.count())) c.skip('la pagina de contacto no tiene formulario reconocido');
  await form.scrollIntoViewIfNeeded().catch(() => {});
  // Fuera de un clon, enviar vacio solo es seguro si el servidor lo rechaza: sin campos
  // obligatorios un formulario de tema o plugin lo daria por bueno y mandaria correo real.
  if (!c.canWrite && !(await form.locator('[required], [aria-required="true"]').count())) c.skip('el formulario no tiene campos obligatorios: enviarlo vacio fuera de un clon aislado mandaria correo real (allowWrites)');
  const submit = form.locator(c.S.contactSubmit).first();
  await submit.click({ timeout: 6000 });
  await sleep(2500);
  const bad = await c.page.evaluate(() => document.querySelectorAll('.wpcf7-not-valid-tip, .wpforms-error, .validation_error, :invalid, [aria-invalid="true"]').length);
  c.assert(bad > 0, 'enviar vacio no muestra ningun aviso de validacion');
  const out = [`${bad} aviso(s) con el formulario vacio`];
  if (!c.canWrite) { out.push('envio omitido: fuera de un clon aislado enviaria correo real (allowWrites)'); return out.join('; '); }
  const inputs = await form.locator('input:not([type=hidden]):not([type=submit]):not([type=checkbox]):not([type=radio]), textarea').all();
  for (const i of inputs) {
    if (!(await i.isVisible().catch(() => false))) continue;
    const type = (await i.getAttribute('type')) || 'text'; const name = (await i.getAttribute('name')) || '';
    const isArea = (await i.evaluate((e) => e.tagName)) === 'TEXTAREA';
    await i.fill(type === 'email' || /mail/i.test(name) ? `regression-${c.stamp}@example.com` : /tel/i.test(type + name) ? '600000000' : isArea ? 'Prueba automatica de regresion' : 'Regresion');
  }
  for (const k of await form.locator('input[type=checkbox]').all()) if (await k.isVisible().catch(() => false)) await k.check().catch(() => {});
  const isCf7 = (await form.getAttribute('class').catch(() => '') || '').includes('wpcf7');
  if (isCf7) {
    const [resp] = await Promise.all([
      c.page.waitForResponse((r) => /feedback/.test(r.url()) && r.request().method() === 'POST', { timeout: 30000 }),
      submit.click(),
    ]);
    const body = await resp.json().catch(() => ({}));
    c.assert(resp.status() === 200, `la API de CF7 responde HTTP ${resp.status()}`);
    const j = judgeMailStatus(body.status, c.clone);
    c.assert(j.ok, j.note);
    out.push(`CF7: ${j.note}`);
  } else {
    await submit.click(); await sleep(3000);
    const msg = await c.page.evaluate(() => document.body.innerText.length);
    c.assert(msg > 0, 'sin respuesta tras enviar');
    out.push('formulario no-CF7: enviado, sin respuesta estructurada que comprobar');
  }
  return out.join('; ');
});

add('newsletter', 'Newsletter: alta', BOTH, async (c) => {
  await c.go(c.cfg.urls.home);
  const form = c.page.locator(c.S.newsletterForm).filter({ has: c.page.locator(c.S.newsletterEmail) }).first();
  if (!(await form.count())) c.skip('no hay formulario de newsletter en la home');
  if (!c.canWrite) c.skip('dar de alta un suscriptor fuera de un clon aislado ensucia la lista real (allowWrites)');
  await form.scrollIntoViewIfNeeded().catch(() => {});
  const email = `regression-${c.stamp}-${c.project}@example.com`;
  await form.locator(c.S.newsletterEmail).first().fill(email);
  const [resp] = await Promise.all([
    c.page.waitForResponse((r) => r.request().method() === 'POST' && /admin-ajax|wp-json|subscribe|newsletter/i.test(r.url()), { timeout: 15000 }).catch(() => null),
    form.locator(c.S.newsletterSubmit).first().click({ timeout: 6000 }),
  ]);
  await sleep(1200);
  const msg = await form.evaluate((f) => (f.parentElement || f).innerText.replace(/\s+/g, ' ').trim().slice(0, 120));
  c.assert(!resp || resp.status() < 400, `la alta responde HTTP ${resp && resp.status()}`);
  return `${email} -> "${msg}" (quedara un suscriptor de prueba: borrarlo del clon)`;
});

add('mobile-menu', 'Menu movil abre y cierra', ['mobile'], async (c) => {
  await c.go(c.cfg.urls.home);
  await c.interact();
  const tg = await firstVisible(c.page, c.S.menuToggle);
  if (!tg) c.skip('no hay boton de menu visible en movil (menu siempre abierto)');
  const open = async () => c.page.evaluate((sel) => [...document.querySelectorAll(sel)].some((e) => {
    const r = e.getBoundingClientRect(); const s = getComputedStyle(e);
    return r.width > 150 && r.height > 50 && s.visibility !== 'hidden' && s.display !== 'none' && r.right > 0 && r.left < innerWidth;
  }), c.S.menuPanel);
  const was = await open();
  await tg.click({ timeout: 6000 }); await sleep(900);
  c.assert(await open(), 'el menu no se abre');
  const close = await firstVisible(c.page, c.S.menuClose);
  if (close) await close.click({ timeout: 4000 }).catch(() => {}); else await tg.click({ timeout: 4000 }).catch(() => {});
  await sleep(900);
  const after = await open();
  c.assert(!after || was, 'el menu no se cierra');
  return 'abre y cierra';
});

add('sticky-header', 'Cabecera fija sin salto de maquetacion', BOTH, async (c) => {
  await c.go(c.cfg.urls.home);
  await c.page.evaluate(() => scrollTo(0, 0)); await sleep(500);
  const top = () => c.page.evaluate((sel) => {
    const m = document.querySelector(sel); if (!m) return null;
    return Math.round(m.getBoundingClientRect().top + scrollY);
  }, c.S.main);
  const t0 = await top();
  if (t0 === null) c.skip('no se localiza el contenedor principal (regression.selectors.main)');
  const seen = [];
  for (const y of [120, 400, 900, 400, 0]) {
    await c.page.evaluate((yy) => scrollTo(0, yy), y); await sleep(450);
    seen.push(await top());
  }
  const jump = Math.max(...seen.map((v) => Math.abs(v - t0)));
  c.assert(jump <= 2, `el contenido se desplaza ${jump}px al hacer scroll (la cabecera pasa a fija sin reservar su alto): ${seen.join(', ')}`);
  return `posicion del contenido estable (${t0}px) durante el scroll`;
});

add('admin', 'Admin: acceso y pantallas clave', ['desktop'], async (c) => {
  const user = process.env.REGRESSION_ADMIN_USER; const pass = process.env.REGRESSION_ADMIN_PASS;
  if (!user || !pass) c.skip('sin REGRESSION_ADMIN_USER / REGRESSION_ADMIN_PASS en el entorno');
  // La primera peticion al admin tras una actualizacion puede agotar el tiempo (migraciones,
  // cache fria): se reintenta UNA vez antes de dar FAIL.
  const goAdmin = async (url) => {
    try { return await c.go(url, 75000); } catch (e) { if (!/timeout/i.test(String(e.message))) throw e; await sleep(2000); return c.go(url, 120000); }
  };
  await goAdmin(c.cfg.admin.loginPath);
  await c.page.fill('#user_login', user); await c.page.fill('#user_pass', pass);
  await Promise.all([c.page.waitForURL(/wp-admin/, { timeout: 60000 }).catch(() => {}), c.page.click('#wp-submit')]);
  c.assert(/wp-admin/.test(c.page.url()), `el acceso al admin falla (${c.page.url()})`);
  const bad = []; let ok = 0;
  for (const u of c.cfg.admin.pages) {
    const st = await goAdmin(u);
    const text = await c.page.evaluate(() => document.body.innerText.slice(0, 8000));
    if (st === 404) continue; // pantalla que ese sitio no tiene (p. ej. el listado de pedidos heredado)
    if (st >= 400 || FATAL.test(text)) bad.push(`${u} -> HTTP ${st}${FATAL.test(text) ? ' + error PHP' : ''}`); else ok++;
  }
  c.assert(!bad.length, bad.join('; '));
  return `${ok} pantallas del admin responden 200 sin errores PHP`;
});

add('sweep', 'Barrido final de URLs (errores JS y peticiones fallidas)', BOTH, async (c) => {
  const st = await discover(c);
  const urls = new Set([c.cfg.urls.home, c.cfg.urls.shop, c.cfg.urls.cart, c.cfg.urls.checkout, c.cfg.urls.account]);
  if (c.cfg.urls.contact) urls.add(c.cfg.urls.contact);
  if (st.category) urls.add(st.category);
  if (st.simple) urls.add(st.simple.permalink);
  if (st.variable) urls.add(st.variable.permalink);
  if (st.term) urls.add(`/?s=${encodeURIComponent(st.term)}&post_type=product`);
  for (const u of c.cfg.sweep.urls) urls.add(u);
  // el resto, de las paginas publicadas y de las categorias de producto
  try {
    const r = await c.page.request.get('/wp-json/wp/v2/pages?per_page=30&_fields=link');
    if (r.ok()) for (const p of await r.json()) urls.add(new URL(p.link, c.base).pathname);
    const k = await c.page.request.get('/wp-json/wc/store/v1/products/categories?per_page=10&hide_empty=true');
    if (k.ok()) for (const t of await k.json()) urls.add(new URL(t.permalink, c.base).pathname);
  } catch { /* sin API: solo las rutas conocidas */ }
  const list = [...urls].filter(Boolean).slice(0, c.cfg.sweep.max);
  let bad = 0, js = 0, failed = 0; const badUrls = [];
  for (const url of list) {
    const e0 = c.events.length; let status = 0;
    try { status = await c.go(url); await c.interact(); await sleep(c.cfg.sweep.settleMs); } catch (e) { c.events.push({ type: 'nav', text: String(e.message).split('\n')[0].slice(0, 160) }); }
    const ev = c.events.slice(e0);
    const row = {
      url, status,
      jsErrors: ev.filter((x) => x.type === 'pageerror' || x.type === 'console').map((x) => `${x.type}: ${x.text}`),
      failed: ev.filter((x) => x.type === 'http' || x.type === 'reqfailed' || x.type === 'nav').map((x) => `${x.type} ${x.text}`),
    };
    c.annotate('sweep', JSON.stringify(row));
    if (!status || status >= 400) { bad++; badUrls.push(`${url} (${status || 'sin respuesta'})`); }
    js += row.jsErrors.length; failed += row.failed.length;
  }
  c.assert(!bad, `${bad} de ${list.length} URL(s) no cargan: ${badUrls.slice(0, 4).join(', ')}`);
  return `${list.length} URL: ${js} error(es) JS y ${failed} peticion(es) fallida(s) registrados (no bloquean; se comparan antes/despues)`;
});

module.exports = { flows, discover, firstVisible };
