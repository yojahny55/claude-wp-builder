// @ts-check
// Suite de regresion de flujos de comprador (WooCommerce): catalogo -> carrito -> checkout,
// cuenta, formularios, menu, admin y un barrido final. Sirve para demostrar que una
// actualizacion o un cambio de rendimiento no rompio nada: se ejecuta ANTES y DESPUES.
//
//   npm run test:regression                       (escritorio + movil)
//   REGRESSION_LABEL=before npm run test:regression
//   REGRESSION_LABEL=after  npm run test:regression
//   npm run regression:compare -- before after    (sale con 1 si algo paso de PASS a FAIL)
//
// Que NO hace: no hace pedidos (no pulsa "Realizar pedido"), no envia correo ni da de alta
// suscriptores fuera de un clon aislado. Ejecutala contra el CLON, nunca contra produccion.
// Los flujos de cada proyecto (regression-desktop / regression-mobile) corren en orden.
require('dotenv').config();
const { test: base, expect } = require('@playwright/test');
const audit = require('../audit.config');
const defaults = require('../regression/defaults');
const { deepMerge, isCloneHost } = require('../regression/helpers');
const { flows } = require('../regression/flows');

const cfg = deepMerge(defaults, audit.regression || {});
const baseURL = process.env.BASE_URL || audit.baseURL;
const clone = cfg.clone === 'auto' ? isCloneHost(new URL(baseURL).hostname) : Boolean(cfg.clone);
const canWrite = clone || cfg.allowWrites === true;
const blockers = cfg.blockRequests.map((r) => new RegExp(r));
const stateByProject = {};
const stamp = Date.now();

// `page` con vigilancia: errores JS, errores de consola, respuestas >= 400 y peticiones
// fallidas del propio sitio, para el informe y el barrido.
const test = base.extend({
  events: async ({}, use) => { await use([]); },
  page: async ({ page, context, events }, use) => {
    await context.route((u) => blockers.some((b) => b.test(u.href)), (r) => r.abort());
    const own = (u) => { try { return new URL(u).origin === new URL(baseURL).origin; } catch { return false; } };
    const push = (type, text) => events.push({ type, text: String(text).slice(0, 300) });
    page.on('pageerror', (e) => push('pageerror', e.message));
    page.on('console', (m) => {
      if (m.type() !== 'error') return;
      const u = (m.location() && m.location().url) || '';
      if (blockers.some((b) => b.test(u)) || /^Failed to load resource: net::ERR_(FAILED|BLOCKED)/.test(m.text())) return;
      push('console', `${m.text()} @${u.slice(0, 100)}`);
    });
    page.on('response', (r) => { if (r.status() >= 400 && own(r.url())) push('http', `${r.status()} ${r.url()}`); });
    page.on('requestfailed', (r) => {
      const f = (r.failure() && r.failure().errorText) || '';
      if (own(r.url()) && !/ERR_ABORTED/.test(f)) push('reqfailed', `${r.url()} ${f}`);
    });
    await use(page);
  },
});

for (const flow of flows) {
  test(`[${flow.id}] ${flow.title} @regression`, async ({ page, events }, testInfo) => {
    const project = testInfo.project.name;
    const device = project.endsWith('mobile') ? 'mobile' : 'desktop';
    const annotate = (type, description) => testInfo.annotations.push({ type, description });
    const skip = (reason) => { test.skip(true, reason); throw new Error(`skip: ${reason}`); };

    if (!flow.devices.includes(device)) skip(device === 'mobile' ? 'flujo solo de escritorio (necesita raton)' : 'flujo solo de movil');
    if (cfg.skipFlows.includes(flow.id)) skip('omitido por regression.skipFlows');

    const state = (stateByProject[project] ||= {});
    const c = {
      page, cfg, S: cfg.selectors, project, isMobile: device === 'mobile', state, clone, canWrite,
      base: baseURL, stamp, events, annotate, skip,
      assert: (cond, msg) => { if (!cond) throw new Error(msg); },
      go: async (url, timeout = 60000) => {
        const r = await page.goto(url, { waitUntil: 'load', timeout });
        for (const sel of cfg.selectors.dismiss ? [cfg.selectors.dismiss] : []) {
          const el = page.locator(sel).first();
          if (await el.isVisible().catch(() => false)) await el.click({ timeout: 2000 }).catch(() => {});
        }
        return r ? r.status() : 0;
      },
      interact: async () => {
        if (device === 'desktop') { await page.mouse.move(200, 200); await page.mouse.move(260, 240); }
        await page.evaluate(() => window.scrollBy(0, 400));
      },
      cartCount: async () => {
        try {
          const r = await page.request.get('/wp-json/wc/store/v1/cart');
          return r.ok() ? (await r.json()).items_count : -1;
        } catch { return -1; }
      },
    };

    if (flow.id === 'home') annotate('meta', JSON.stringify({ baseURL, clone }));
    const ev0 = events.length;
    const evidence = await flow.run(c);
    if (evidence) annotate('evidence', evidence);
    // los errores JS no tumban un flujo (el barrido los compara antes/despues), pero se anotan
    const js = events.slice(ev0).filter((e) => e.type === 'pageerror');
    if (js.length && flow.id !== 'sweep') annotate('evidence', `${js.length} error(es) JS: ${js[0].text}`);
    expect(true).toBe(true);
  });
}
