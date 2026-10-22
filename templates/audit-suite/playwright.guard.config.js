// Plugin-owned wrapper around the vendored playwright.config.js: the same config plus the
// timeout guard (guard/timeout-guard.js). It lives beside the vendored file instead of inside
// it so the vendored config stays byte-identical to its upstream.
const base = require('./playwright.config');

module.exports = {
  ...base,
  reporter: [...(base.reporter || [['list']]), [require.resolve('./guard/timeout-guard')]],
};
