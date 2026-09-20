// @ts-check
const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');
const audit = require('../audit.config');
const H = require('../lib/audit-helpers');

const OUT = path.join(__dirname, '..', 'results', 'audit');
fs.mkdirSync(OUT, { recursive: true });

function save(pageName, browser, results) {
  const flat = results.flat().filter(Boolean);
  const file = path.join(OUT, `${slug(pageName)}.${browser}.json`);
  fs.writeFileSync(file, JSON.stringify({ page: pageName, browser, results: flat }, null, 2));
  return flat;
}
const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

for (const p of audit.pages) {
  test.describe(`Auditoria: ${p.name}`, () => {
    test(`${p.name} (${p.path})`, async ({ page, browserName }, testInfo) => {
      const url = new URL(p.path, audit.baseURL).toString();
      await page.goto(url, { waitUntil: 'networkidle' });
      const th = audit.thresholds;
      const sel = audit.selectors;
      const results = [];

      // --- Criterios de pagina comunes ---
      results.push(await H.checkTitle(page, th));
      results.push(await H.checkMetaDescription(page, th));
      results.push(await H.checkMetadata(page));
      results.push(await H.checkHeadings(page));
      results.push(await H.checkLang(page));
      results.push(await H.checkImagesAlt(page));
      results.push(await H.checkImageLinksAlt(page));
      results.push(await H.checkHomeShortcut(page, sel));
      results.push(await H.checkSearch(page, sel));
      results.push(await H.checkPrivacyLink(page, sel));
      results.push(await H.checkActiveNav(page, sel));
      results.push(await H.checkButtonText(page));
      results.push(await H.checkHover(page, sel));
      results.push(await H.checkActionSpacing(page, sel, th));
      results.push(await H.checkLineLength(page, sel, th, audit.viewports));
      results.push(...await H.runAxe(page));

      // Enlaces rotos (solo una vez, en chromium, por coste de red).
      // Usa page.request para compartir la sesion autenticada (cookies / basic auth).
      if (browserName === 'chromium') {
        results.push(...await H.checkBrokenLinks(page, page.request, audit.baseURL));
      }

      // --- Especifico de formularios ---
      if (p.type === 'form' && p.form) {
        results.push(await H.checkRequiredMarks(page, p.form));
        results.push(await H.checkFirstFieldFocus(page, p.form));
        results.push(...await H.checkFormValidation(page, p.form));
      }

      // --- Responsividad (recarga en varios viewports; al final) ---
      results.push(await H.checkResponsive(page, audit.viewports, url));

      const flat = save(p.name, browserName, results);

      // Adjuntar resumen al reporte de Playwright
      const summary = flat.map(r => `[${r.status.toUpperCase()}] ${r.c} ${r.name}: ${r.evidence}`).join('\n');
      await testInfo.attach('auditoria', { body: summary, contentType: 'text/plain' });

      // Fallar el test solo si hay incumplimientos 'fail' (los 'warn'/'manual' no rompen)
      const fails = flat.filter(r => r.status === 'fail');
      expect.soft(fails, `Incumplimientos en ${p.name}:\n${fails.map(f => `- ${f.c} ${f.name}: ${f.evidence}`).join('\n')}`).toEqual([]);
    });
  });
}

// La 404 se comprueba una vez
test('404 personalizada', async ({ page, browserName }) => {
  test.skip(browserName !== 'chromium', 'Se comprueba solo en chromium');
  const r = await H.checkNotFound(page, audit.baseURL, audit.notFoundPath, audit.selectors);
  fs.writeFileSync(path.join(OUT, `_404.json`), JSON.stringify({ page: '404', results: [r] }, null, 2));
  expect.soft(r.status, r.evidence).not.toBe('fail');
});
