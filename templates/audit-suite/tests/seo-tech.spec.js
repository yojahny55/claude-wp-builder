// @ts-check
// Categoria G2 — SEO tecnico e indexabilidad (criterios 51-58).
// Corre sobre HTTP publico con el fixture `request`: sin navegador, sin SSH ni
// WP-CLI. Hereda la sesion autenticada del config (basic auth / storageState),
// asi que tambien funciona contra staging con clave.
const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');
const audit = require('../audit.config');
const G2 = require('../lib/seo-tech');

const OUT = path.join(__dirname, '..', 'results', 'audit');
fs.mkdirSync(OUT, { recursive: true });
const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const write = (name, results) =>
  fs.writeFileSync(path.join(OUT, `g2-${slug(name)}.json`), JSON.stringify({ page: name, results }, null, 2));

// Reciprocidad de hreflang: cachea las paginas ya descargadas para no pedir la
// misma version de idioma una vez por cada pagina del alcance.
const hreflangCache = new Map();

// --- Criterios de SITIO (51, 52, 56): se evaluan una sola vez -------------
test('G2 sitio: robots.txt, sitemap.xml y redirects', async ({ request, browserName }) => {
  test.skip(browserName !== 'chromium', 'Comprobacion de red: basta una vez');
  const scopePaths = audit.pages.map(p => p.path);

  const { result: robots, body: robotsBody } = await G2.checkRobots(request, audit.baseURL, scopePaths);
  const sitemap = await G2.checkSitemap(request, audit.baseURL, scopePaths, robotsBody, audit.seo?.sitemapSample ?? 5);
  const redirects = await G2.checkRedirects(request, audit.baseURL);

  // Unicidad de title/description: hay que ver todas las paginas a la vez, no
  // se puede decidir pagina a pagina. Peticiones HTTP planas, sin navegador.
  const fetched = [];
  for (const p of audit.pages) {
    const res = await request.get(new URL(p.path, audit.baseURL).toString(), { timeout: 20000, failOnStatusCode: false });
    if (res.status() >= 400) continue;
    const html = await res.text();
    fetched.push({ name: p.name, html, headers: res.headers(), url: res.url(), title: G2.titleOf(html), description: G2.metaContent(html, 'description') });
  }

  const home = fetched[0];
  const results = [robots, sitemap, redirects, ...G2.checkUniqueness(fetched)];
  if (home) results.push(G2.checkStagingExposure(home.url, home.html, home.headers, robotsBody));
  write('_sitio-g2', results);

  const fails = results.filter(r => r.status === 'fail');
  expect.soft(fails, `SEO tecnico de sitio:\n${fails.map(f => `- ${f.c} ${f.name}: ${f.evidence}`).join('\n')}`).toEqual([]);
});

// --- Criterios de PAGINA (53, 54, 55, 57, 58) ----------------------------
for (const p of audit.pages) {
  test(`G2 pagina: ${p.name}`, async ({ request, browserName }, testInfo) => {
    test.skip(browserName !== 'chromium', 'Comprobacion de red: basta una vez');
    const url = new URL(p.path, audit.baseURL).toString();
    const res = await request.get(url, { timeout: 20000, failOnStatusCode: false });
    expect(res.status(), `${url} devolvio ${res.status()}`).toBeLessThan(400);

    const html = await res.text();
    const finalUrl = res.url();          // tras seguir los redirects
    const headers = res.headers();

    const results = [
      G2.checkCanonical(html, finalUrl),
      G2.checkStructuredData(html),
      G2.checkHttps(html, finalUrl),
      // p.noindex === true marca las paginas que NO deben indexarse (carrito,
      // checkout, mi cuenta, busqueda interna). El resto recibe la
      // comprobacion inversa: que no lleven noindex por error.
      G2.checkNoindex(html, headers, p.noindex === true, p.name),
      await G2.checkHreflang(request, html, finalUrl, hreflangCache),
    ];
    write(p.name, results);

    await testInfo.attach('seo-tecnico', {
      body: results.map(r => `[${r.status.toUpperCase()}] ${r.c} ${r.name}: ${r.evidence}`).join('\n'),
      contentType: 'text/plain',
    });

    const fails = results.filter(r => r.status === 'fail');
    expect.soft(fails, `SEO tecnico en ${p.name}:\n${fails.map(f => `- ${f.c} ${f.name}: ${f.evidence}`).join('\n')}`).toEqual([]);
  });
}
