// pw-executables.cjs: preloaded with NODE_OPTIONS=--require by bin/audit-suite.sh.
//
// The vendored suite (templates/audit-suite/) launches browsers three ways: the test
// runner's projects, performance.spec.js's own `chromium.launch()` for Lighthouse, and
// global-setup.js's login. None of them passes an `executablePath`, so each one looked for
// the build pinned to its Playwright revision and needed `playwright install`. The suite's
// files are compared against their upstream by tests/checks/audit-suite-sync.sh, so the fix
// lives here instead: every BrowserType.launch* in this process defaults `executablePath`
// to the existing executable bin/lib/browsers.mjs resolved, exported as
// WP_AUDIT_CHROMIUM / WP_AUDIT_FIREFOX / WP_AUDIT_WEBKIT. An explicit executablePath wins.
//
// Two more run settings reach the vendored files the same way, for the same reason:
//
//   WP_AUDIT_BLOCK_THIRD_PARTY=1  every launch gets the third-party block from
//                                 ./third-party.cjs, built from BASE_URL plus
//                                 WP_AUDIT_ALLOW_HOSTS. From a local clone the analytics,
//                                 embeds and widgets would otherwise be real hits on
//                                 production properties.
//   WP_AUDIT_SETTLE_MS=<ms>       `page.goto(..., { waitUntil: 'networkidle' })` and
//                                 `waitForLoadState('networkidle')` become `domcontentloaded`
//                                 plus a settle of at most that long. A page with a polling
//                                 widget or a video embed never goes idle, so every page of a
//                                 third-party-heavy site timed out and the guard read a slow
//                                 page as a host that had stopped answering. 0 keeps the
//                                 vendored waits as they are.
'use strict';

const path = require('path');
const thirdParty = require('./third-party.cjs');

const exe = {
  chromium: process.env.WP_AUDIT_CHROMIUM,
  firefox: process.env.WP_AUDIT_FIREFOX,
  webkit: process.env.WP_AUDIT_WEBKIT,
};

const block = process.env.WP_AUDIT_BLOCK_THIRD_PARTY === '1'
  ? thirdParty.allowlistFor(process.env.BASE_URL, process.env.WP_AUDIT_ALLOW_HOSTS)
  : null;
const settleRaw = Number.parseInt(process.env.WP_AUDIT_SETTLE_MS || '', 10);
const settleMs = Number.isFinite(settleRaw) && settleRaw >= 0 ? settleRaw : 0;

// Playwright's client classes are not exported, so the Page prototype is reached through the
// first objects a launch hands back: launch -> Browser -> newContext -> BrowserContext ->
// newPage -> Page. Each prototype is patched once and every later instance shares it.
function patchPage(page) {
  const proto = page && Object.getPrototypeOf(page);
  if (!proto || proto.__wpAuditSettle || typeof proto.goto !== 'function') return;
  proto.__wpAuditSettle = true;
  const goto = proto.goto;
  const waitForLoadState = proto.waitForLoadState;
  // The settle is bounded and never throws: what matters is that the DOM exists, and a page
  // still fetching its widgets after the settle is measured as it stands, not failed.
  const settle = (page_) => waitForLoadState.call(page_, 'networkidle', { timeout: settleMs }).catch(() => {});
  proto.goto = async function (url, options) {
    if (!options || options.waitUntil !== 'networkidle') return goto.call(this, url, options);
    const response = await goto.call(this, url, Object.assign({}, options, { waitUntil: 'domcontentloaded' }));
    await settle(this);
    return response;
  };
  proto.waitForLoadState = async function (state, options) {
    if (state !== 'networkidle' || (options && options.timeout !== undefined)) return waitForLoadState.call(this, state, options);
    await waitForLoadState.call(this, 'domcontentloaded', options);
    await settle(this);
  };
}
function patchContext(context) {
  const proto = context && Object.getPrototypeOf(context);
  if (!proto || proto.__wpAuditSettle || typeof proto.newPage !== 'function') return;
  proto.__wpAuditSettle = true;
  const newPage = proto.newPage;
  proto.newPage = async function (...args) {
    const page = await newPage.apply(this, args);
    patchPage(page);
    return page;
  };
  for (const page of typeof context.pages === 'function' ? context.pages() : []) patchPage(page);
}
function patchHandle(handle, method) {
  if (!handle) return;
  if (method === 'launchPersistentContext') { patchContext(handle); return; }
  const proto = Object.getPrototypeOf(handle);
  if (!proto || proto.__wpAuditSettle || typeof proto.newContext !== 'function') return;
  proto.__wpAuditSettle = true;
  const newContext = proto.newContext;
  proto.newContext = async function (...args) {
    const context = await newContext.apply(this, args);
    patchContext(context);
    return context;
  };
}

try {
  // Resolved from the suite directory, so the patched class is the very one the specs load.
  const entry = require.resolve('@playwright/test', { paths: [process.cwd()] });
  const pw = require(entry);
  const proto = Object.getPrototypeOf(pw.chromium);
  for (const method of ['launch', 'launchPersistentContext', 'launchServer']) {
    const original = proto[method];
    if (typeof original !== 'function' || original.__wpAuditPatched) continue;
    const patched = function (...args) {
      const name = typeof this.name === 'function' ? this.name() : '';
      const i = method === 'launchPersistentContext' ? 1 : 0;
      const opts = Object.assign({}, args[i] || {});
      if (!opts.executablePath && exe[name]) opts.executablePath = exe[name];
      const defaults = (this._playwright && this._playwright._defaultLaunchOptions) || {};
      args[i] = block ? thirdParty.applyToLaunch(name, thirdParty.withDefaults(defaults, opts), block) : opts;
      const result = original.apply(this, args);
      if (!settleMs || !result || typeof result.then !== 'function') return result;
      return result.then((handle) => { patchHandle(handle, method); return handle; });
    };
    patched.__wpAuditPatched = true;
    proto[method] = patched;
  }
} catch {
  // npm, npx and anything else started under this NODE_OPTIONS that has no suite in its cwd.
}

module.exports = { exe, block, settleMs, dir: path.dirname(__filename) };
