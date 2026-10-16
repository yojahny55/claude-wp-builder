// @ts-check
// Suite de regresion de flujos de comprador (WooCommerce). Config PROPIA, distinta de
// playwright.config.js (que es la de la auditoria): dos proyectos, escritorio y movil,
// un solo worker y sin reintentos globales. Los flujos comparten el estado del comercio
// (carrito, sesion), asi que paralelizar los vuelve no deterministas; el unico reintento
// que existe es el del admin tras una actualizacion, y vive dentro del flujo.
//
// Entrada: npm run test:regression   (REGRESSION_LABEL=before|after para etiquetar)
require('dotenv').config();
const { defineConfig, devices } = require('@playwright/test');
const audit = require('./audit.config');
const { deepMerge } = require('./regression/helpers');
const defaults = require('./regression/defaults');

const cfg = deepMerge(defaults, audit.regression || {});
const executablePath = cfg.executablePath || process.env.CHROMIUM_PATH || undefined;
const launchOptions = executablePath ? { executablePath } : {};

module.exports = defineConfig({
  testDir: './tests',
  testMatch: /regression\.spec\.js$/,
  timeout: 120_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  outputDir: 'results/regression/artifacts',
  reporter: [['list'], ['./regression/reporter.js']],
  use: {
    baseURL: process.env.BASE_URL || audit.baseURL,
    ignoreHTTPSErrors: true,
    screenshot: 'only-on-failure',
    launchOptions,
  },
  projects: [
    {
      name: 'regression-desktop',
      use: { ...devices['Desktop Chrome'], viewport: cfg.viewports.desktop, deviceScaleFactor: 1 },
    },
    {
      name: 'regression-mobile',
      use: {
        ...devices['Pixel 7'], viewport: cfg.viewports.mobile, isMobile: true, hasTouch: true,
      },
    },
  ],
});
