// @ts-check
// Setup global: si el sitio usa login por FORMULARIO (AUTH_TYPE=form), inicia sesion
// una vez y guarda la sesion en .auth/state.json para reutilizarla en todos los tests.
// Para HTTP Basic (AUTH_TYPE=basic) no hace falta setup: se maneja con httpCredentials.
require('dotenv').config();
const { chromium } = require('@playwright/test');
const fs = require('fs');
const path = require('path');
const audit = require('./audit.config');

module.exports = async () => {
  const type = (process.env.AUTH_TYPE || (audit.auth && audit.auth.type) || 'none').toLowerCase();
  if (type !== 'form') return;

  const user = process.env.SITE_USERNAME;
  const pass = process.env.SITE_PASSWORD;
  if (!user || !pass) {
    throw new Error(
      '\n[AUTH] El sitio requiere iniciar sesion (AUTH_TYPE=form) pero faltan credenciales.\n' +
      '       Edita el archivo .env y define SITE_USERNAME y SITE_PASSWORD, luego vuelve a ejecutar.\n');
  }

  const cfg = audit.auth || {};
  const sel = cfg.selectors || {};
  const base = process.env.BASE_URL || audit.baseURL;
  const loginURL = new URL(cfg.loginPath || '/login', base).toString();

  const browser = await chromium.launch();
  const page = await browser.newPage();
  try {
    await page.goto(loginURL, { waitUntil: 'networkidle' });
    await page.fill(sel.username, user);
    await page.fill(sel.password, pass);
    await Promise.all([
      page.waitForLoadState('networkidle'),
      page.click(sel.submit),
    ]);

    if (cfg.successSelector) {
      const ok = await page.locator(cfg.successSelector).count().catch(() => 0);
      if (!ok) {
        throw new Error(
          '[AUTH] Login fallido: no aparece el indicador de sesion iniciada.\n' +
          '       Revisa SITE_USERNAME/SITE_PASSWORD en .env y los selectores de audit.config.js (auth).');
      }
    }

    const dir = path.join(__dirname, '.auth');
    fs.mkdirSync(dir, { recursive: true });
    await page.context().storageState({ path: path.join(dir, 'state.json') });
    console.log('[AUTH] Sesion iniciada y guardada en .auth/state.json');
  } finally {
    await browser.close();
  }
};
