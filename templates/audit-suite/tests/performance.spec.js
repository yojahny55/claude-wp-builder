// @ts-check
// Rendimiento (pauta 41) con Lighthouse como proxy de GTmetrix.
// Cada pagina se mide DOS veces: escritorio y movil. Son dos perfiles de red,
// CPU y viewport distintos, y el informe reporta las 4 categorias de cada uno.
//
// Lighthouse se adjunta por CDP a un Chromium propio que lanza este test en un
// puerto libre, no al navegador de la suite. Motivo: el puerto de depuracion
// remota tiene que fijarse en `launchOptions` del config, y ahi solo caben dos
// opciones malas — ponerlo siempre (los workers de audit.spec.js compiten por
// el 9222, solo uno lo consigue y el resto muere con "bind() returned an error:
// Only one usage of each socket address", que Playwright reporta como un
// timeout de launch) o intentar detectar la corrida por `process.argv`, que no
// funciona porque los workers son procesos hijos con otro argv. Con un
// navegador propio por test no hay puerto fijo, ni colision, ni deteccion.
const { test, expect, chromium } = require('@playwright/test');
const fs = require('fs');
const net = require('net');
const path = require('path');
const audit = require('../audit.config');
const LH = require('../lib/lighthouse-report');

const OUT = path.join(__dirname, '..', 'results', 'audit');
const LH_DIR = path.join(__dirname, '..', 'results', 'lighthouse');
fs.mkdirSync(OUT, { recursive: true });
const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

// Puerto libre que da el sistema: dos tests en paralelo nunca piden el mismo.
const freePort = () => new Promise((resolve, reject) => {
  const srv = net.createServer();
  srv.on('error', reject);
  srv.listen(0, '127.0.0.1', () => {
    const { port } = srv.address();
    srv.close(() => resolve(port));
  });
});

// Lighthouse navega en su propia pestana, fuera del contexto de Playwright: no
// hereda ni las credenciales HTTP Basic ni la sesion guardada por global-setup.
// Se le pasan como cabeceras. Nunca se imprimen ni se guardan en el informe.
function authHeaders(url) {
  const type = (process.env.AUTH_TYPE || (audit.auth && audit.auth.type) || 'none').toLowerCase();
  if (type === 'basic' && process.env.SITE_USERNAME && process.env.SITE_PASSWORD) {
    const cred = Buffer.from(`${process.env.SITE_USERNAME}:${process.env.SITE_PASSWORD}`).toString('base64');
    return { Authorization: `Basic ${cred}` };
  }
  if (type === 'form') {
    const state = path.join(__dirname, '..', '.auth', 'state.json');
    if (!fs.existsSync(state)) return {};
    const host = new URL(url).hostname;
    const cookies = JSON.parse(fs.readFileSync(state, 'utf8')).cookies || [];
    const propias = cookies.filter(c => host === c.domain || host.endsWith(c.domain.replace(/^\./, '')));
    if (!propias.length) return {};
    return { Cookie: propias.map(c => `${c.name}=${c.value}`).join('; ') };
  }
  return {};
}

// Dos corridas por pagina duplican el tiempo: el timeout del config no alcanza.
test.describe.configure({ timeout: 300_000 });

for (const p of audit.pages) {
  test(`Lighthouse (escritorio + movil): ${p.name}`, async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Lighthouse solo corre en Chromium');
    test.setTimeout(300_000);
    const { playAudit } = require('playwright-lighthouse');
    const url = new URL(p.path, audit.baseURL).toString();
    const file = path.join(OUT, `lh-${slug(p.name)}.json`);
    const th = audit.thresholds;
    const extraHeaders = authHeaders(url);
    // Los titulos de los audits llegan traducidos: son el texto de las
    // incidencias del informe, que esta en espanol.
    const opts = { locale: th.lighthouseLocale || 'es' };
    if (Object.keys(extraHeaders).length) opts.extraHeaders = extraHeaders;

    const port = await freePort();
    const browser = await chromium.launch({ args: [`--remote-debugging-port=${port}`] });

    // Una corrida por form factor. Si una falla, se guarda el error y se sigue
    // con la otra: media medicion es mejor que ninguna.
    const lh = {};
    const errores = [];
    try {
      for (const ff of LH.FORM_FACTORS) {
        try {
          const report = await playAudit({
            url,
            port,
            // No romper aqui: el veredicto de la pauta 41 se calcula abajo.
            thresholds: { performance: 0, accessibility: 0, 'best-practices': 0, seo: 0 },
            config: ff.config,
            opts: { ...opts },
            reports: {
              formats: { json: true, html: true },
              name: `lh-${slug(p.name)}-${ff.key}`,
              directory: LH_DIR,
            },
            disableLogs: true,
          });
          lh[ff.key] = LH.extractRun(report.lhr, ff.key);
        } catch (e) {
          errores.push(`${ff.label}: ${e.message}`);
        }
      }
    } finally {
      await browser.close();
    }

    if (!Object.keys(lh).length) {
      fs.writeFileSync(file, JSON.stringify({
        page: p.name, url, lighthouse: {},
        results: [{
          c: '41', name: 'GTmetrix/Lighthouse', status: 'manual',
          evidence: `No se pudo ejecutar Lighthouse — ${errores.join(' · ')}`,
          rec: 'Ejecutar Lighthouse manualmente sobre esta URL y anotar las 4 puntuaciones',
        }],
      }, null, 2));
      expect.soft(errores.join(' · '), 'Lighthouse no llego a medir esta pagina').toBe('');
      return;
    }

    // El JSON de Lighthouse ya trae los Core Web Vitals y el detalle de cada
    // audit fallido: se extraen como filas accionables (41.1-41.7) y como lista
    // de incidencias por categoria, en vez de quedarse solo con los numeros.
    const results = LH.combinedRows(lh, th, { topAudits: th.lighthouseTopAudits ?? 6 });
    const incidencias = LH.mergeIssues(lh);

    fs.writeFileSync(file, JSON.stringify({
      page: p.name, url, lighthouse: lh, incidencias, errores, results,
    }, null, 2));

    const gate = results.find(r => String(r.c) === '41');
    expect.soft(gate.status, gate.evidence).not.toBe('fail');
  });
}
