// @ts-check
require('dotenv').config();
const fs = require('fs');
const os = require('os');
const path = require('path');
const { defineConfig, devices } = require('@playwright/test');
const audit = require('./audit.config');

// Autenticacion: 'none' | 'basic' | 'form' (via .env AUTH_TYPE o audit.config auth.type)
const authType = (process.env.AUTH_TYPE || (audit.auth && audit.auth.type) || 'none').toLowerCase();
const hasCreds = Boolean(process.env.SITE_USERNAME && process.env.SITE_PASSWORD);

// WebKit en Manjaro/Arch necesita un libxml2.so.2 viejo que el sistema ya no
// trae (rolling release paso a la ABI .so.16). Solucion (documentada en
// references/webkit-manjaro.md): compilar libxml2 2.9.14 aparte en
// ~/.local/webkit-compat-libs y symlinkearlo dentro de la carpeta bundled
// del browser de Playwright. IMPORTANTE: no sirve con LD_LIBRARY_PATH porque
// el wrapper minibrowser-wpe/MiniBrowser hace `export LD_LIBRARY_PATH=...` a
// secas (sobreescribe, no extiende) — el symlink es lo unico que respeta.
// Se recrea solo si falta (p.ej. tras actualizar el browser de Playwright).
// No-op en cualquier maquina sin ese prefijo compilado (Ubuntu/Debian no lo
// necesitan: ahi `npx playwright install-deps` resuelve todo solo).
const webkitCompatXml2 = path.join(os.homedir(), '.local', 'webkit-compat-libs', 'lib', 'libxml2.so.2');
if (fs.existsSync(webkitCompatXml2)) {
  const pwCacheDir = path.join(os.homedir(), '.cache', 'ms-playwright');
  const webkitDir = fs.existsSync(pwCacheDir)
    ? fs.readdirSync(pwCacheDir).find((d) => d.startsWith('webkit-'))
    : null;
  if (webkitDir) {
    const linkPath = path.join(pwCacheDir, webkitDir, 'minibrowser-wpe', 'lib', 'libxml2.so.2');
    if (!fs.existsSync(linkPath)) {
      try { fs.symlinkSync(webkitCompatXml2, linkPath); } catch { /* carpeta de solo lectura o ya existe */ }
    }
  }
}

// Cross-browser: Chromium (Chrome/Edge), Firefox y WebKit (Safari) cubren la pauta 40.
// Lighthouse (pauta 41) solo corre en Chromium y se adjunta por CDP a un navegador
// propio que lanza performance.spec.js en un puerto libre. Aqui NO se fija ningun
// puerto de depuracion remota: hacerlo rompe audit.spec.js en paralelo, porque cada
// worker lanza su propio Chromium, todos intentan bindear el mismo puerto y los que
// pierden mueren con "bind() returned an error: Only one usage of each socket
// address...", que Playwright reporta como un timeout de launch.
module.exports = defineConfig({
  testDir: './tests',
  timeout: 90_000,
  expect: { timeout: 10_000 },
  fullyParallel: true,
  retries: 1,
  // Cada worker lanza su propio navegador completo. El default de Playwright
  // (= nucleos de CPU) puede saturar una maquina con poca RAM libre: varios
  // Chromium/Firefox arrancando a la vez se pisan entre si y el lanzamiento
  // empieza a colgarse/fallar ("browserType.launch: Timeout ... exceeded").
  // Si el host tiene de sobra, sube este numero; si sigue fallando, bajalo.
  workers: 4,
  reporter: [
    ['list'],
    ['json', { outputFile: 'results/results.json' }],
    ['html', { outputFolder: 'results/html', open: 'never' }],
  ],
  // Login por formulario: inicia sesion una vez y reutiliza la sesion guardada.
  globalSetup: authType === 'form' ? require.resolve('./global-setup') : undefined,
  use: {
    baseURL: process.env.BASE_URL || audit.baseURL,
    screenshot: 'only-on-failure',
    trace: 'on-first-retry',
    ignoreHTTPSErrors: false,
    // HTTP Basic: credenciales desde .env
    httpCredentials: authType === 'basic' && hasCreds
      ? { username: process.env.SITE_USERNAME, password: process.env.SITE_PASSWORD }
      : undefined,
    // Login por formulario: sesion guardada por global-setup
    storageState: authType === 'form' ? '.auth/state.json' : undefined,
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
  ],
});
