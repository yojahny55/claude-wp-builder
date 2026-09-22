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
'use strict';

const path = require('path');

const exe = {
  chromium: process.env.WP_AUDIT_CHROMIUM,
  firefox: process.env.WP_AUDIT_FIREFOX,
  webkit: process.env.WP_AUDIT_WEBKIT,
};

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
      args[i] = opts;
      return original.apply(this, args);
    };
    patched.__wpAuditPatched = true;
    proto[method] = patched;
  }
} catch {
  // npm, npx and anything else started under this NODE_OPTIONS that has no suite in its cwd.
}

module.exports = { exe, dir: path.dirname(__filename) };
